#!/bin/bash

# ========= PALETA DE COLORES (ESTILO NEÓN / MORADO) =========
W='\033[1;37m'
D='\033[38;5;183m'
M='\033[38;5;129m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[1;36m'
G='\033[38;5;82m'
N='\033[0m'

# Ancho interno fijo: exactamente 69 caracteres de contenido útil
BOX_WIDTH=69

draw_top()    { echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"; }
draw_mid()    { echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"; }
draw_bot()    { echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"; }

draw_title()  {
    printf "${D}║${M} %-${BOX_WIDTH}s ${D}║${N}\n" "           ⚡ MÓDULO PROXY PYTHON ( HTTP / WS )"
}

draw_step_line() {
    local text="$1"
    local raw_len=${#text}
    local pad=$(( BOX_WIDTH - raw_len ))
    printf "${D}║${N} ${C}%s${N}%*s ${D}║${N}\n" "$text" "$pad" ""
}

CONFIG="/etc/kira/domain"
PORT_FILE="/etc/kira/proxy_ports"

mkdir -p /etc/kira

DOMAIN=$(cat $CONFIG 2>/dev/null)
PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)

[ -z "$DOMAIN" ] && DOMAIN="--"
[ -z "$PORTS" ] && PORTS="80"

# ===== INSTALAR / REINICIAR PROXY =====
install_proxy() {
    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "[1/3] Preparando puertos y depurando sockets..."
    systemctl stop proxy-python 2>/dev/null

    PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)
    PORTS=$(echo $PORTS | tr ' ' '\n' | sort -u | xargs)
    [ -z "$PORTS" ] && PORTS="80"
    echo "$PORTS" > $PORT_FILE

    PY_PORTS=$(echo $PORTS | sed 's/ /,/g')

    # ===== PYTHON CONNECT REAL =====
    draw_step_line "[2/3] Generando motor de túnel optimizado en Python..."
    cat > /usr/local/bin/proxy.py << 'EOF'
import socket
import threading
import select
import time

PORTS = [$PY_PORTS]
BUFFER = 4096

def tunnel(client, remote):
    try:
        while True:
            r, _, _ = select.select([client, remote], [], [])
            if client in r:
                data = client.recv(BUFFER)
                if not data:
                    break
                remote.sendall(data)
            if remote in r:
                data = remote.recv(BUFFER)
                if not data:
                    break
                client.sendall(data)
    except Exception as e:
        pass
    finally:
        client.close()
        remote.close()

def handle_client(conn):
    try:
        data = conn.recv(BUFFER)
        if not data:
            conn.close()
            return

        print(f"[DEBUG] Tráfico entrante: {data[:60]}", flush=True)

        first_line = data.split(b'\n')[0]

        # ===== CONNECT =====
        if b"CONNECT" in first_line:
            target = first_line.split()[1]
            host, port = target.split(b":")
            port = int(port)

            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.connect((host.decode(), port))

            conn.send(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            tunnel(conn, remote)
            return

        # ===== HTTP NORMAL =====
        else:
            lines = data.split(b"\r\n")
            host = None

            for line in lines:
                if line.lower().startswith(b"host:"):
                    host = line.split(b":")[1].strip()
                    break

            if not host:
                conn.close()
                return

            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.connect((host.decode(), 80))

            remote.sendall(data)
            tunnel(conn, remote)

    except Exception as e:
        print(f"[ERROR CLIENTE] {e}", flush=True)
    finally:
        conn.close()

def start_server(port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("0.0.0.0", port))
        s.listen(200)

        print(f"[OK] Proxy activo en puerto {port}", flush=True)

        while True:
            conn, _ = s.accept()
            threading.Thread(target=handle_client, args=(conn,), daemon=True).start()

    except Exception as e:
        print(f"[ERROR SERVER] {port}: {e}", flush=True)

for p in PORTS:
    threading.Thread(target=start_server, args=(p,), daemon=False).start()

while True:
    time.sleep(60)
EOF

    sed -i "s/\[\$PY_PORTS\]/[$PY_PORTS]/g" /usr/local/bin/proxy.py
    chmod +x /usr/local/bin/proxy.py

    # ===== SYSTEMD =====
    draw_step_line "[3/3] Configurando servicio en systemd..."
    cat > /etc/systemd/system/proxy-python.service <<EOF
[Unit]
Description=KIRA Proxy Python High Performance
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/proxy.py
Restart=always
RestartSec=3

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl start proxy-python
    systemctl enable proxy-python >/dev/null 2>&1

    sleep 1
    draw_mid

    if systemctl is-active --quiet proxy-python; then
        raw_l=" Status: [ONLINE] - Proxy Python en ejecución."
        pad=$(( BOX_WIDTH - ${#raw_l} ))
        printf "${D}║${N} Status: ${G}[ONLINE]${N} - Proxy Python en ejecución.%*s ${D}║${N}\n" "$pad" ""
    else
        raw_err=" Status: [ERROR] - No se pudo iniciar el servicio."
        pad_err=$(( BOX_WIDTH - ${#raw_err} ))
        printf "${D}║${N} Status: ${R}[ERROR]${N} - No se pudo iniciar el servicio.%*s ${D}║${N}\n" "$pad_err" ""
    fi

    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

# ===== RESET =====
reset_all() {
    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "Eliminando configuraciones y servicios..."
    systemctl stop proxy-python 2>/dev/null
    systemctl disable proxy-python 2>/dev/null

    rm -f /etc/systemd/system/proxy-python.service
    rm -f /usr/local/bin/proxy.py
    rm -f $PORT_FILE

    systemctl daemon-reload
    draw_mid

    raw_res=" Status: [RESET] - Sistema limpio con éxito."
    pad_res=$(( BOX_WIDTH - ${#raw_res} ))
    printf "${D}║${N} Status: ${Y}[RESET]${N} - Sistema limpio con éxito.%*s ${D}║${N}\n" "$pad_res" ""

    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

# ===== MENU PRINCIPAL =====
while true; do
    # Actualizar variable global de puertos en cada vuelta del menú
    PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)
    [ -z "$PORTS" ] && PORTS="80"

    clear
    draw_top
    draw_title
    draw_mid

    if systemctl is-active --quiet proxy-python 2>/dev/null; then
        st_text="ACTIVO (ON)"
        st_color="${G}"
    else
        st_text="DETENIDO (OFF)"
        st_color="${R}"
    fi

    r_st=" Estado del Servicio: $st_text"
    p_st=$(( BOX_WIDTH - ${#r_st} ))
    printf "${D}║${N} ${W}Estado del Servicio:${N} ${st_color}%s${N}%*s ${D}║${N}\n" "$st_text" "$p_st" ""

    r_dom=" Dominio enlazado   : $DOMAIN"
    p_dom=$(( BOX_WIDTH - ${#r_dom} ))
    printf "${D}║${N} ${W}Dominio enlazado   :${N} ${C}%s${N}%*s ${D}║${N}\n" "$DOMAIN" "$p_dom" ""

    r_prt=" Puertos de escucha : $PORTS"
    p_prt=$(( BOX_WIDTH - ${#r_prt} ))
    printf "${D}║${N} ${W}Puertos de escucha :${N} ${Y}%s${N}%*s ${D}║${N}\n" "$PORTS" "$p_prt" ""

    draw_mid

    opt1=" [1] Iniciar / Reiniciar Proxy Python"
    opt2=" [2] Agregar Nuevo Puerto de Escucha"
    opt5=" [5] Eliminar un Puerto de Escucha"
    opt3=" [3] Reset Total / Desinstalar"
    opt4=" [4] Ver Registros en Vivo (Logs)"
    opt0=" [0] Salir del Módulo"

    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt1"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt2"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt5"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt3"
    printf "${D}║${N} ${C}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt4"
    printf "${D}║${N} ${R}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt0"

    draw_bot
    echo ""
    read -p " ➤ Opción: " op

    case $op in
        1)
            install_proxy
            ;;
        2)
            clear
            draw_top
            draw_title
            draw_mid
            
            prompt_p=" Ingresa el nuevo puerto:"
            printf "${D}║${N} %-${BOX_WIDTH}s ${D}║${N}\n" "$prompt_p"
            echo -ne "${D}║${N} ${Y}➤ ${N}"
            read P

            if ! [[ "$P" =~ ^[0-9]+$ ]]; then
                err_p=" ✘ Puerto inválido. Solo números."
                pad_ep=$(( BOX_WIDTH - ${#err_p} ))
                printf "\033[1A\033[K${D}║${N} ${R}%s${N}%*s ${D}║${N}\n" "$err_p" "$pad_ep" ""
                sleep 2
                continue
            fi

            touch $PORT_FILE
            if grep -qw "$P" $PORT_FILE 2>/dev/null; then
                exist_p=" ⚠ El puerto ya se encuentra registrado."
                pad_exp=$(( BOX_WIDTH - ${#exist_p} ))
                printf "\033[1A\033[K${D}║${N} ${Y}%s${N}%*s ${D}║${N}\n" "$exist_p" "$pad_exp" ""
                sleep 2
                continue
            fi

            echo "$P" >> $PORT_FILE
            
            # Auto-aplicar cambios reiniciando el servicio de inmediato
            install_proxy >/dev/null 2>&1
            
            draw_top
            draw_title
            draw_mid
            ok_p=" ✔ Puerto $P agregado y aplicado con éxito."
            pad_okp=$(( BOX_WIDTH - ${#ok_p} ))
            printf "${D}║${N} ${G}%s${N}%*s ${D}║${N}\n" "$ok_p" "$pad_okp" ""
            draw_bot
            sleep 2
            ;;
        5)
            clear
            draw_top
            draw_title
            draw_mid

            prompt_p=" Puertos actuales: $PORTS"
            printf "${D}║${N} %-${BOX_WIDTH}s ${D}║${N}\n" "$prompt_p"
            prompt_p2=" Ingresa el puerto que deseas eliminar:"
            printf "${D}║${N} %-${BOX_WIDTH}s ${D}║${N}\n" "$prompt_p2"
            echo -ne "${D}║${N} ${Y}➤ ${N}"
            read P

            if ! grep -qw "$P" $PORT_FILE 2>/dev/null; then
                err_p=" ✘ El puerto no existe en la lista."
                pad_ep=$(( BOX_WIDTH - ${#err_p} ))
                printf "\033[1A\033[K${D}║${N} ${R}%s${N}%*s ${D}║${N}\n" "$err_p" "$pad_ep" ""
                sleep 2
                continue
            fi

            # Eliminar el puerto del archivo filtrando las líneas
            grep -vxF "$P" $PORT_FILE > "${PORT_FILE}.tmp" && mv "${PORT_FILE}.tmp" $PORT_FILE

            # Si el archivo queda vacío, dejar por defecto el puerto 80
            if [ ! -s "$PORT_FILE" ]; then
                echo "80" > $PORT_FILE
            fi

            # Auto-aplicar cambios reiniciando el servicio de inmediato
            install_proxy >/dev/null 2>&1

            draw_top
            draw_title
            draw_mid
            ok_p=" ✔ Puerto $P eliminado y aplicado con éxito."
            pad_okp=$(( BOX_WIDTH - ${#ok_p} ))
            printf "${D}║${N} ${G}%s${N}%*s ${D}║${N}\n" "$ok_p" "$pad_okp" ""
            draw_bot
            sleep 2
            ;;
        3)
            reset_all
            ;;
        4)
            clear
            journalctl -u proxy-python -n 25 --no-pager
            echo ""
            read -p " Presiona Enter para volver..."
            ;;
        0)
            break
            ;;
        *)
            echo -e " ${R}Opción inválida.${N}"
            sleep 1
            ;;
    esac
done