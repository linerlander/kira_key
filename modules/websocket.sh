#!/bin/bash

# ===== COLORES KIRA =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888

# ===== ESTADO =====
get_status() {
WS_STATUS=$(systemctl is-active kira-ws 2>/dev/null)

ss -tuln | grep -q ":443 " && SSL_STATUS="${GR}[ON]${NC}" || SSL_STATUS="${RD}[OFF]${NC}"
ss -tuln | grep -q ":80 " && P80="${GR}[ON]${NC}" || P80="${RD}[OFF]${NC}"
ss -tuln | grep -q ":8080 " && P8080="${GR}[ON]${NC}" || P8080="${RD}[OFF]${NC}"
ss -tuln | grep -q ":2082 " && P2082="${GR}[ON]${NC}" || P2082="${RD}[OFF]${NC}"
}

# ===== INSTALAR WS =====
install_ws() {

echo -e "${CY}Instalando WebSocket...${NC}"

wget -q https://github.com/erebe/wstunnel/releases/latest/download/wstunnel_linux_amd64 -O /usr/bin/wstunnel
chmod +x /usr/bin/wstunnel

cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel -s 127.0.0.1:${WS_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws
systemctl restart kira-ws

}

# ===== CONFIG MULTI WS + SSL =====
setup_ws_full() {

read -p "🌐 Dominio: " DOMAIN
mkdir -p /etc/kira
echo "$DOMAIN" > $CONFIG

apt install nginx certbot python3-certbot-nginx -y

# CONFIG MULTIPUERTO + RUTAS CAMUFLADAS
cat > /etc/nginx/sites-enabled/default <<EOF

# ===== PUERTO 80 =====
server {
    listen 80;
    server_name $DOMAIN;

    location /ws { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
}

# ===== PUERTO 8080 =====
server {
    listen 8080;
    server_name $DOMAIN;

    location /ws { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
}

# ===== PUERTO 2082 =====
server {
    listen 2082;
    server_name $DOMAIN;

    location /ws { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
}

EOF

systemctl restart nginx

# ===== SSL 443 =====
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# BLOQUE 443
cat >> /etc/nginx/sites-enabled/default <<EOF

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /ws { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
}
EOF

systemctl restart nginx

echo -e "${GR}✔ MULTI WS + SSL ACTIVO${NC}"
sleep 2
}

# ===== MENU =====
while true; do
clear

get_status

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${WH}WEBSOCKET MULTIPUERTO KIRA${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " WS        : ${GR}$WS_STATUS${NC}"
echo -e " SSL 443   : $SSL_STATUS"
echo -e " PORT 80   : $P80"
echo -e " PORT 8080 : $P8080"
echo -e " PORT 2082 : $P2082"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} Instalar WebSocket"
echo -e " ${WH}[2]${NC} Configurar MULTI WS + SSL"
echo -e " ${WH}[3]${NC} Reiniciar servicios"
echo -e " ${WH}[4]${NC} Detener WebSocket"
echo -e " ${WH}[0]${NC} Volver"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion: " op

case $op in

1)
install_ws
;;

2)
setup_ws_full
;;

3)
systemctl restart kira-ws
systemctl restart nginx
;;

4)
systemctl stop kira-ws
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