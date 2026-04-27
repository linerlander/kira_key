#!/bin/bash

# ===== COLORES =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/kira/domain"

# ===== DETECTAR ESTADO =====
ws_status() {
    if systemctl is-active --quiet kira-ws; then
        echo -e "${GR}[ON]${NC}"
    else
        echo -e "${RD}[OFF]${NC}"
    fi
}

# ===== INSTALAR WS =====
install_ws() {

# instalar dependencias
apt install nodejs npm -y >/dev/null 2>&1
npm install -g wstunnel >/dev/null 2>&1

# crear servicio
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel -s 0.0.0.0:8888
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws
systemctl restart kira-ws

}

# ===== CONFIGURAR NGINX =====
config_nginx() {

DOMAIN=$(cat $CONFIG)

cat > /etc/nginx/sites-enabled/default <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

systemctl restart nginx
}

# ===== MENU =====
while true; do
clear

STATUS=$(ws_status)

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}⚡ WEBSOCKET KIRA ⚡${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " Estado actual: $STATUS"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} ➤ INSTALAR / ACTIVAR WS"
echo -e " ${WH}[2]${NC} ➤ REINICIAR WS"
echo -e " ${WH}[3]${NC} ➤ DETENER WS"
echo -e " ${WH}[0]${NC} ➤ VOLVER"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion: " op

case $op in

1)
    # dominio obligatorio
    if [ ! -f "$CONFIG" ]; then
        read -p "🌐 Ingresa tu dominio: " DOMAIN
        mkdir -p /etc/kira
        echo "$DOMAIN" > "$CONFIG"
    fi

    install_ws
    config_nginx

    echo -e "${GR}✔ WebSocket instalado y funcionando${NC}"
    sleep 2
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

0)
    break
;;

*)
    echo -e "${RD}Opcion invalida${NC}"
    sleep 1
;;

esac
done