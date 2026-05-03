#!/bin/bash

YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
GY='\033[38;5;245m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888
BACKEND_PORT=80   # 👈 puerto del proxy (puedes cambiarlo si quieres)

# ===== ESTADO =====
get_status() {

WS_STATUS=$(systemctl is-active kira-ws 2>/dev/null)
[ "$WS_STATUS" = "active" ] && WS_COLOR="${GR}[ON]${NC}" || WS_COLOR="${RD}[OFF]${NC}"

ss -tuln | grep -q ":443 " && SSL_STATUS="${GR}[ON]${NC}" || SSL_STATUS="${RD}[OFF]${NC}"
ss -tuln | grep -q ":80 " && P80="${GR}[ON]${NC}" || P80="${RD}[OFF]${NC}"

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"
}

# ===== INSTALAR WS =====
install_ws() {

echo -e "${CY}Instalando WebSocket...${NC}"

rm -f /usr/bin/wstunnel

curl -L https://github.com/erebe/wstunnel/releases/download/v7.2/wstunnel_linux_amd64 -o /usr/bin/wstunnel

chmod +x /usr/bin/wstunnel

/usr/bin/wstunnel --help >/dev/null 2>&1 || {
    echo -e "${RD}Error en wstunnel${NC}"
    return
}

cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel -s 127.0.0.1:${WS_PORT} --restrict-to 127.0.0.1:${BACKEND_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws
systemctl restart kira-ws

echo -e "${GR}✔ WS activo${NC}"
sleep 2
}

# ===== NGINX + CAMUFLAJE =====
setup_ws_ssl() {

read -p "Dominio: " DOMAIN

if [[ ! "$DOMAIN" =~ \. ]]; then
    echo -e "${RD}Dominio inválido${NC}"
    sleep 2
    return
fi

echo "$DOMAIN" > $CONFIG

apt install nginx certbot python3-certbot-nginx -y

rm -f /etc/nginx/conf.d/kira_ws.conf

cat > /etc/nginx/conf.d/kira_ws.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # CAMUFLAJE (rutas reales)
    location /chat {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }

    location /video {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }

    location /api {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
}
EOF

systemctl restart nginx

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

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
        proxy_read_timeout 86400;
    }

    location /video {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    location /api {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

systemctl restart nginx

echo -e "${GR}✔ WS + SSL + CAMUFLAJE LISTO${NC}"
sleep 2
}

# ===== MENU =====
while true; do
clear

get_status

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${WH}WEBSOCKET KIRA PRO${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : $DOMAIN"
echo -e " WS         : $WS_COLOR"
echo -e " SSL 443    : $SSL_STATUS"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " [1] Instalar WebSocket"
echo -e " [2] Configurar WS + SSL"
echo -e " [3] Reiniciar"
echo -e " [4] Detener"
echo -e " [0] Salir"

read -p "Opcion: " op

case $op in
1) install_ws ;;
2) setup_ws_ssl ;;
3) systemctl restart kira-ws && systemctl restart nginx ;;
4) systemctl stop kira-ws ;;
0) break ;;
esac

done