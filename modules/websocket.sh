#!/bin/bash

# ===== COLORES =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888
LOCAL_PORT=9999
TMP="/tmp/wstunnel.tar.gz"

mkdir -p /etc/kira

# ===== DEPENDENCIAS =====
command -v wget >/dev/null || apt install wget -y
command -v tar >/dev/null || apt install tar -y
command -v ss >/dev/null || apt install iproute2 -y

# ===== ESTADO =====
get_status() {
WS_STATUS=$(systemctl is-active kira-ws 2>/dev/null)
CLIENT_STATUS=$(systemctl is-active kira-ws-client 2>/dev/null)

[ "$WS_STATUS" = "active" ] && WS_COLOR="${GR}[ON]${NC}" || WS_COLOR="${RD}[OFF]${NC}"
[ "$CLIENT_STATUS" = "active" ] && CL_COLOR="${GR}[ON]${NC}" || CL_COLOR="${RD}[OFF]${NC}"

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"
}

# ===== INSTALAR WS =====
install_ws() {

echo -e "${CY}⬇️ Instalando WebSocket...${NC}"

systemctl stop kira-ws 2>/dev/null
rm -f /etc/systemd/system/kira-ws.service
systemctl daemon-reload

pkill -f wstunnel 2>/dev/null
fuser -k ${WS_PORT}/tcp 2>/dev/null

rm -f /usr/bin/wstunnel
rm -f $TMP

wget -O $TMP https://github.com/erebe/wstunnel/releases/download/v10.5.3/wstunnel_10.5.3_linux_amd64.tar.gz

tar -xzf $TMP -C /tmp
mv /tmp/wstunnel /usr/bin/wstunnel
chmod +x /usr/bin/wstunnel

echo -e "${GR}✔ Binario instalado${NC}"

# ===== SERVER =====
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket Server
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel server ws://0.0.0.0:${WS_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws
systemctl restart kira-ws

sleep 2

ss -tuln | grep ${WS_PORT} && echo -e "${GR}✔ WS activo${NC}" || echo -e "${RD}✖ WS error${NC}"
}

# ===== CLIENTE AUTOMATICO (LOCAL BACKEND) =====
install_client() {

echo -e "${CY}⚙️ Activando cliente automático...${NC}"

cat > /etc/systemd/system/kira-ws-client.service <<EOF
[Unit]
Description=KIRA WS CLIENT
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel client -L tcp://127.0.0.1:${LOCAL_PORT}:127.0.0.1:80 ws://127.0.0.1:${WS_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws-client
systemctl restart kira-ws-client

sleep 2

ss -tuln | grep ${LOCAL_PORT} && echo -e "${GR}✔ Cliente activo${NC}" || echo -e "${RD}✖ Cliente error${NC}"
}

# ===== NGINX + SSL =====
setup_ws_ssl() {

read -p "🌐 Dominio: " DOMAIN
echo "$DOMAIN" > $CONFIG

apt update -y
apt install nginx certbot python3-certbot-nginx -y

rm -f /etc/nginx/conf.d/kira_ws.conf

# HTTP
cat > /etc/nginx/conf.d/kira_ws.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /chat {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

systemctl restart nginx

# SSL
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# HTTPS
cat >> /etc/nginx/conf.d/kira_ws.conf <<EOF

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /chat {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

systemctl restart nginx

echo -e "${GR}✔ WS + SSL listo${NC}"
}

# ===== MENU =====
while true; do
clear
get_status

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WH}   KIRA WS HTTP INJECTOR${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " WS SERVER  : $WS_COLOR"
echo -e " WS CLIENT  : $CL_COLOR"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} Instalar WS"
echo -e " ${WH}[2]${NC} Configurar WS + SSL"
echo -e " ${WH}[3]${NC} Activar Cliente automático"
echo -e " ${WH}[4]${NC} Reiniciar todo"
echo -e " ${WH}[5]${NC} Detener todo"
echo -e " ${WH}[0]${NC} Salir"

read -p " ► Opcion: " op

case $op in
1) install_ws ;;
2) setup_ws_ssl ;;
3) install_client ;;
4) systemctl restart kira-ws && systemctl restart kira-ws-client && systemctl restart nginx ;;
5) systemctl stop kira-ws && systemctl stop kira-ws-client ;;
0) break ;;
*) echo -e "${RD}Opcion invalida${NC}"; sleep 1 ;;
esac

done