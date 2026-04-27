#!/bin/bash

# ===== COLORES KIRA =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
GY='\033[38;5;245m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888

# ===== ESTADO =====
ws_status() {
    if systemctl is-active --quiet kira-ws; then
        echo -e "${GR}[ON]${NC}"
    else
        echo -e "${RD}[OFF]${NC}"
    fi
}

port_active() {
    ss -tuln | grep -q ":$1 "
}

# ===== INSTALAR WS (SIN NPM - RÁPIDO) =====
install_ws() {

echo -e "${CY}⬇️ Descargando WebSocket...${NC}"

wget -q https://github.com/erebe/wstunnel/releases/latest/download/wstunnel_linux_amd64 -O /usr/bin/wstunnel
chmod +x /usr/bin/wstunnel

if [ ! -f /usr/bin/wstunnel ]; then
    echo -e "${RD}Error descargando wstunnel${NC}"
    exit 1
fi

echo -e "${CY}⚙️ Configurando servicio...${NC}"

cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel -s 0.0.0.0:${WS_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws
systemctl restart kira-ws

sleep 1

if systemctl is-active --quiet kira-ws; then
    echo -e "${GR}✔ WebSocket activo en puerto ${WS_PORT}${NC}"
else
    echo -e "${RD}✖ Error iniciando WebSocket${NC}"
fi

sleep 2
}

# ===== CONFIGURAR NGINX =====
config_nginx() {

DOMAIN=$(cat $CONFIG 2>/dev/null)

if [ -z "$DOMAIN" ]; then
    read -p "🌐 Ingresa tu dominio: " DOMAIN
    mkdir -p /etc/kira
    echo "$DOMAIN" > "$CONFIG"
fi

echo -e "${CY}⚙️ Configurando NGINX...${NC}"

apt install nginx -y >/dev/null 2>&1

cat > /etc/nginx/sites-enabled/default <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /ws {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

systemctl restart nginx

echo -e "${GR}✔ NGINX listo (ruta /ws)${NC}"
sleep 2
}

# ===== INFO SERVIDOR =====
show_info() {

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"

STATUS=$(ws_status)

PORT_CHECK=$(port_active $WS_PORT && echo "${GR}OPEN${NC}" || echo "${RD}CLOSED${NC}")

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${WH}⚡ WEBSOCKET KIRA ⚡${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " 📡 Puerto  : ${WH}$WS_PORT${NC}"
echo -e " 🔌 Estado  : $STATUS"
echo -e " 📶 Puerto  : $PORT_CHECK"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ===== MENU =====
while true; do
clear

show_info

echo -e " ${WH}[1]${NC} ➤ INSTALAR / ACTIVAR WS"
echo -e " ${WH}[2]${NC} ➤ REINICIAR WS"
echo -e " ${WH}[3]${NC} ➤ DETENER WS"
echo -e " ${WH}[4]${NC} ➤ CAMBIAR DOMINIO"
echo -e " ${WH}[0]${NC} ➤ VOLVER"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion: " op

case $op in

1)
    install_ws
    config_nginx
;;

2)
    systemctl restart kira-ws
    echo -e "${GR}✔ Reiniciado${NC}"
    sleep 2
;;

3)
    systemctl stop kira-ws
    echo -e "${RD}✔ Detenido${NC}"
    sleep 2
;;

4)
    read -p "Nuevo dominio: " DOMAIN
    echo "$DOMAIN" > "$CONFIG"
    config_nginx
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