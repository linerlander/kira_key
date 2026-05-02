#!/bin/bash

# ===== COLORES PRO =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
GY='\033[38;5;245m'
NC='\033[0m'

CONF="/etc/kira/badvpn_ports"

mkdir -p /etc/kira
[ ! -f "$CONF" ] && echo "7100 7200 7300" > "$CONF"

# ===== FUNCIONES =====

port_active() {
    ss -tuln | grep -q ":$1 "
}

status_port() {
    if port_active "$1"; then
        echo -e "${GR}[ON]${NC}"
    else
        echo -e "${RD}[OFF]${NC}"
    fi
}

install_badvpn() {

if ! command -v badvpn-udpgw >/dev/null; then
    echo -e "${CY}Instalando BadVPN...${NC}"
    apt update -y
    apt install badvpn -y
fi

for p in $(cat $CONF); do

    if port_active "$p"; then
        continue
    fi

    screen -dmS badvpn_$p badvpn-udpgw --listen-addr 127.0.0.1:$p --max-clients 1000

done

}

stop_badvpn() {
    pkill badvpn-udpgw
}

add_port() {

read -p "➤ Nuevo puerto: " newp

if ss -tuln | grep -q ":$newp "; then
    echo -e "${RD}Puerto ocupado${NC}"
    sleep 2
    return
fi

echo "$newp" >> $CONF

echo -e "${GR}✔ Puerto agregado${NC}"
sleep 2
}

# ===== MENU =====
while true; do
clear

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "      ${WH}Administrador BadVPN UDP | KIRA${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${GY}                 ACTIVE PORTS${NC}"

echo ""

for p in $(cat $CONF); do
    printf "   127.0.0.1:%-6s %b\n" "$p" "$(status_port $p)"
done

echo ""
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} > AÑADIR 1+ PUERTO BadVPN"
echo -e " ${WH}[2]${NC} > INICIAR BadVPN"
echo -e " ${WH}[3]${NC} > DETENER BadVPN"
echo -e " ${WH}[0]${NC} > VOLVER"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion : " op

case $op in

1)
add_port
;;

2)
install_badvpn
echo -e "${GR}✔ BadVPN iniciado${NC}"
sleep 2
;;

3)
stop_badvpn
echo -e "${RD}✔ BadVPN detenido${NC}"
sleep 2
;;

0)
break
;;

*)
echo -e "${RD}Opcion invalida${NC}"
sleep 1
;;

esac
done