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

BOX_WIDTH=69

draw_top()    { echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"; }
draw_mid()    { echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"; }
draw_bot()    { echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"; }

draw_title()  {
    printf "${D}║${M} %-${BOX_WIDTH}s ${D}║${N}\n" "       ⚡ MÓDULO WEBSOCKET NATIVO ( HTTP INJECTOR / 101 )"
}

draw_step_line() {
    local text="$1"
    local raw_len=${#text}
    local pad=$(( BOX_WIDTH - raw_len ))
    printf "${D}║${N} ${C}%s${N}%*s ${D}║${N}\n" "$text" "$pad" ""
}

CONFIG="/etc/kira/domain"
WS_PORT=80

mkdir -p /etc/kira
DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"

# ================================
# 1. INSTALAR Y CREAR MOTOR WEBSOCKET PYTHON (101)
# ================================
install_all() {
    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "[1/2] Actualizando paquetes y dependencias..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -y >/dev/null 2>&1
    apt install -y python3 python3-pip >/dev/null 2>&1

    draw_step_line "[2/2] Creando servidor WebSocket nativo (Python)..."

   cat > /usr/local/bin/ws_server.py << 'EOF'
import socket
import threading
import select
import base64
import hashlib

LOCAL_PORT = 80
TARGET_HOST = '127.0.0.1'
TARGET_PORT = 22

def handle_client(client_socket):
    target_socket = None
    try:
        request = b""
        client_socket.settimeout(3.0)
        while True:
            try:
                chunk = client_socket.recv(4096)
                if not chunk:
                    break
                request += chunk
                if b"\r\n\r\n" in request or len(request) > 8192:
                    break
            except socket.timeout:
                break
        
        client_socket.settimeout(None)
        if not request:
            client_socket.close()
            return

        request_lower = request.lower()

        if b"upgrade: websocket" in request_lower:
            ws_key = None
            for line in request.split(b"\r\n"):
                if line.lower().startswith(b"sec-websocket-key:"):
                    parts = line.split(b":", 1)
                    if len(parts) > 1:
                        ws_key = parts[1].strip()
                    break
            
            if ws_key:
                magic_guid = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
                accept_sha = hashlib.sha1(ws_key + magic_guid).digest()
                accept_key = base64.b64encode(accept_sha).decode('utf-8')
            else:
                accept_key = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Accept: {accept_key}\r\n\r\n"
            )
            client_socket.sendall(response.encode())
        else:
            response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
            client_socket.sendall(response.encode())
            client_socket.close()
            return

        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((TARGET_HOST, TARGET_PORT))

        sockets = [client_socket, target_socket]
        while True:
            r, _, _ = select.select(sockets, [], [], 300)
            if not r:
                break
            for s in r:
                data = s.recv(32768)
                if not data:
                    break
                if s is client_socket:
                    target_socket.sendall(data)
                else:
                    client_socket.sendall(data)
    except Exception:
        pass
    finally:
        try: client_socket.close()
        except: pass
        try: 
            if target_socket: target_socket.close()
        except: pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', LOCAL_PORT))
    server.listen(500)
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle_client, args=(client,), daemon=True).start()

if __name__ == '__main__':
    main()
EOF

    chmod +x /usr/local/bin/ws_server.py

    cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA Native WebSocket Python Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl stop nginx 2>/dev/null
    systemctl disable nginx 2>/dev/null
    systemctl enable kira-ws >/dev/null 2>&1
    systemctl restart kira-ws

    draw_mid
    ok_msg=" ✔ Motor WebSocket nativo activo en puerto ${WS_PORT}."
    pad_ok=$(( BOX_WIDTH - ${#ok_msg} ))
    printf "${D}║${N} ${G}%s${N}%*s ${D}║${N}\n" "$ok_msg" "$pad_ok" ""
    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

# ================================
# 2. CONFIGURAR DOMINIO (OPCIONAL REGISTRO)
# ================================
setup_domain() {
    clear
    draw_top
    draw_title
    draw_mid

    prompt_d=" Ingresa tu dominio (Ej: yomi.linerlander.space):"
    pad_d=$(( BOX_WIDTH - ${#prompt_d} ))
    printf "${D}║${N} %s%*s ${D}║${N}\n" "$prompt_d" "$pad_d" ""
    draw_mid

    lbl_in=" ➜ Dominio: "
    echo -ne "${D}║${N}${Y}${lbl_in}${N}"
    read DOMAIN
    draw_bot

    DOMAIN=$(echo "$DOMAIN" | xargs)
    [ -z "$DOMAIN" ] && return

    echo "$DOMAIN" > $CONFIG

    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "[✔] Dominio guardado correctamente."
    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

# ================================
# 3. VER ESTADO DE LOS SERVICIOS
# ================================
status_all() {
    clear
    draw_top
    draw_title
    draw_mid

    if systemctl is-active --quiet kira-ws; then
        ws_st="ACTIVO (ON)"
        ws_col="${G}"
    else
        ws_st="DETENIDO (OFF)"
        ws_col="${R}"
    fi

    r1=" Servidor WebSocket (Puerto 80) : $ws_st"
    p1=$(( BOX_WIDTH - ${#r1} ))
    printf "${D}║${N} ${W}Servidor WebSocket (Puerto 80) :${N} ${ws_col}%s${N}%*s ${D}║${N}\n" "$ws_st" "$p1" ""

    r2=" Dominio enlazado               : $DOMAIN"
    p2=$(( BOX_WIDTH - ${#r2} ))
    printf "${D}║${N} ${W}Dominio enlazado               :${N} ${C}%s${N}%*s ${D}║${N}\n" "$DOMAIN" "$p2" ""

    draw_bot
    echo ""
    read -p " Presiona Enter para volver..."
}

# ================================
# MENÚ PRINCIPAL DEL MÓDULO
# ================================
while true; do
    clear
    draw_top
    draw_title
    draw_mid

    opt1=" [1] Instalar / Reiniciar Servidor WebSocket (Puerto 80)"
    opt2=" [2] Guardar / Configurar Dominio"
    opt3=" [3] Ver Estado de los Servicios"
    opt0=" [0] Salir del Módulo"

    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt1"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt2"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt3"
    printf "${D}║${N} ${R}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt0"

    draw_bot
    echo ""
    read -p " ➤ Opción: " op

    case $op in
        1) install_all ;;
        2) setup_domain ;;
        3) status_all ;;
        0) break ;;
        *) 
           echo -e "\n ${R}Opción inválida.${N}"
           sleep 1 
           ;;
    esac
done