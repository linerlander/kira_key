#!/bin/bash

# ========= COLORES Y ESTILOS =========
W='\033[1;37m'
D='\033[38;5;240m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;183m' # Morado suave y elegante
G='\033[38;5;46m'
N='\033[0m'

SERVICE="kira-badvpn"
BIN="/usr/local/bin/badvpn-udpgw"
PORT_FILE="/etc/kira/badvpn_ports"

mkdir -p /etc/kira

# ===== ESTADO =====
status_badvpn() {
    pgrep -f badvpn-udpgw >/dev/null && echo -e "${G}● ACTIVADO${N}" || echo -e "${R}● DETENIDO${N}"
}

# ===== LEER PUERTOS =====
get_ports() {
    [ -f "$PORT_FILE" ] && cat "$PORT_FILE" || echo "7100 7200 7300"
}

# ===== GENERAR SERVICIO =====
generate_service() {
    PORTS=$(get_ports)

    CMD=""
    for p in $PORTS; do
        CMD+="--listen-addr 127.0.0.1:$p "
    done

    cat > /etc/systemd/system/${SERVICE}.service <<EOF
[Unit]
Description=KIRA BadVPN PRO
After=network.target

[Service]
ExecStart=$BIN $CMD --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart $SERVICE
}

# ===== INSTALAR =====
install_badvpn() {
    echo -e "${Y} ⚙️ Instalando BadVPN (modo PRO)...${N}"
    echo ""

    apt update -y
    apt install -y build-essential cmake git >/dev/null 2>&1

    cd /root
    rm -rf badvpn
    git clone https://github.com/ambrop72/badvpn.git >/dev/null 2>&1

    cd badvpn
    mkdir build && cd build

    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null
    make install >/dev/null 2>&1

    if [ ! -f "$BIN" ]; then
        echo -e "${R} ✘ Error al compilar BadVPN${N}"
        return
    fi

    # puertos por defecto
    echo "7100 7200 7300" > "$PORT_FILE"

    generate_service
    systemctl enable "$SERVICE" >/dev/null 2>&1

    sleep 2
    echo -e "${G} ✔ BadVPN instalado correctamente${N}"
}

# ===== AGREGAR PUERTO =====
add_port() {
    read -p " ► Nuevo puerto: " NEWPORT
    echo ""

    if ! [[ "$NEWPORT" =~ ^[0-9]+$ ]]; then
        echo -e "${R} ✘ Puerto inválido. Debe ser un número.${N}"
        return
    fi

    if ss -tuln | grep -q ":$NEWPORT "; then
        echo -e "${R} ✘ Puerto ocupado por otro servicio.${N}"
        return
    fi

    PORTS=$(get_ports)

    if echo "$PORTS" | grep -w "$NEWPORT" >/dev/null; then
        echo -e "${Y} ⚠ Ese puerto ya existe en la lista.${N}"
        return
    fi

    echo "$PORTS $NEWPORT" > "$PORT_FILE"
    generate_service

    echo -e "${G} ✔ Puerto agregado correctamente.${N}"
}

# ===== ELIMINAR PUERTO =====
del_port() {
    PORTS=$(get_ports)

    echo -e " ${W}Puertos actuales:${N} ${C}$PORTS${N}"
    echo ""
    read -p " ► Puerto a eliminar: " DEL
    echo ""

    NEW=$(echo "$PORTS" | sed "s/\b$DEL\b//g" | xargs)

    if [ -z "$NEW" ]; then
        echo -e "${R} ✘ No puedes eliminar todos los puertos. Debe quedar al menos uno.${N}"
        return
    fi

    echo "$NEW" > "$PORT_FILE"
    generate_service

    echo -e "${G} ✔ Puerto eliminado correctamente.${N}"
}

# ===== DETENER =====
stop_badvpn() {
    systemctl stop "$SERVICE"
    echo -e "${R} ✔ BadVPN detenido.${N}"
}

# ===== MENU =====
while true; do
    clear

    STATE=$(status_badvpn)
    PORTS=$(get_ports)

    # ========= BANNER ESTILIZADO =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}                🚀 BADVPN UDP PRO - KIRA             ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    # ========= INFO DE ESTADO Y PUERTOS EN CAJA =========
    echo -e "${C}┌─────────────────────────────────────────────────────┐${N}"
    printf "${C}│${N} ${W}Estado:${N}   %b %-34s                        ${C}│${N}\n""" "$STATE"
    printf "${C}│${N} ${W}Puertos:${N}  ${C}%-35s${N}       ${C}│${N}\n" "$PORTS"
    echo -e "${C}└─────────────────────────────────────────────────────┘${N}"
    echo ""

    # ========= INFORMACIÓN DE USO =========
    echo -e " ${W}📡 Uso recomendado:${N}"
    echo -e "   ${G}7100${N} ➜ 🎮 Juegos (FreeFire, PUBG)"
    echo -e "   ${G}7200${N} ➜ 📱 HTTP Injector / KPN"
    echo -e "   ${G}7300${N} ➜ 🌐 DNS / tráfico general"
    echo -e "${D}─────────────────────────────────────────────────────${N}"

    # ========= MENÚ DE OPCIONES =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    printf "${C}║${N} ${W}[1]${N} ${W}%-45s   ${C}║${N}\n" "Instalar o Reinstalar BadVPN"
    printf "${C}║${N} ${W}[2]${N} ${W}%-45s    ${C}║${N}\n" "Añadir nuevo puerto"
    printf "${C}║${N} ${W}[3]${N} ${W}%-45s   ${C}║${N}\n" "Eliminar puerto existente"
    printf "${C}║${N} ${W}[4]${N} ${W}%-45s   ${C}║${N}\n" "Reiniciar servicio"
    printf "${C}║${N} ${W}[5]${N} ${W}%-45s   ${C}║${N}\n" "Detener servicio"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    printf "${C}║${N} ${R}[0]${N} ${W}%-45s    ${C}║${N}\n" "Volver al menú principal"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    read -p " ► Selecciona una opción: " op
    echo ""

    case $op in
        1)
            install_badvpn
            read -p " Presiona Enter para continuar..."
            ;;
        2)
            add_port
            sleep 2
            ;;
        3)
            del_port
            sleep 2
            ;;
        4)
            generate_service
            echo -e "${G} ✔ Servicio reiniciado correctamente.${N}"
            sleep 2
            ;;
        5)
            stop_badvpn
            sleep 2
            ;;
        0)
            break
            ;;
        *)
            echo -e "${R} ✘ Opción inválida, intenta de nuevo.${N}"
            sleep 1
            ;;
    esac
done