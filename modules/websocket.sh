#!/bin/bash

# ===== COLORES PRO =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
GY='\033[38;5;245m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888

# ===== DEPENDENCIAS =====
command -v curl >/dev/null || apt install curl -y
command -v ss >/dev/null || apt install iproute2 -y

# ===== ESTADO =====
get_status() {

WS_STATUS=$(systemctl is-active kira-ws 2>/dev/null)
[ "$WS_STATUS" = "active" ] && WS_COLOR="${GR}[ON]${NC}" || WS_COLOR="${RD}[OFF]${NC}"

ss -tuln | grep -q ":443 " && SSL_STATUS="${GR}[ON]${NC}" || SSL_STATUS="${RD}[OFF]${NC}"
ss -tuln | grep -q ":80 " && P80="${GR}[ON]${NC}" || P80="${RD}[OFF]${NC}"

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"
}

# ===== DESCARGA PRO (ANTI BLOQUEO) =====
install_ws() {

echo -e "${CY}⬇️ Instalando WebSocket...${NC}"

rm -f /usr/bin/wstunnel

# 🔥 MULTI SOURCE
curl -L --connect-timeout 10 https://github.com/erebe/wstunnel/releases/download/v7.2/wstunnel_linux_amd64 -o /usr/bin/wstunnel || \
curl -L https://ghproxy.com/https://github.com/erebe/wstunnel/releases/download/v7.2/wstunnel_linux_amd64 -o /usr/bin/wstunnel

# VALIDAR BINARIO
if ! file /usr/bin/wstunnel | grep -q "ELF"; then
    echo -e "${RD}✖ ERROR: descarga corrupta (GitHub bloqueado)${NC}"
    rm -f /usr/bin/wstunnel
    sleep 2
    return
fi

chmod +x /usr/bin/wstunnel

# CREAR SERVICIO
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel -s 0.0.0.0:${WS_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable kira-ws >/dev/null 2>&1
systemctl restart kira-ws

sleep 2

if systemctl is-active --quiet kira-ws; then
    echo -e "${GR}✔ WebSocket activo${NC}"
else
    echo -e "${RD}✖ Error iniciando WebSocket${NC}"
    systemctl status kira-ws --no-pager
fi

sleep 3
}

# ===== NGINX + SSL + MULTI WS =====
setup_ws_ssl() {

read -p "🌐 Dominio (Cloudflare en GRIS): " DOMAIN

mkdir -p /etc/kira
echo "$DOMAIN" > $CONFIG

echo -e "${CY}⚙️ Instalando NGINX + SSL...${NC}"

apt update -y
apt install nginx certbot python3-certbot-nginx -y

rm -f /etc/nginx/sites-enabled/default

# ===== HTTP (80) =====
cat > /etc/nginx/conf.d/kira_ws.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /ws {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
}
EOF

systemctl restart nginx

echo -e "${YL}⚠️ Asegúrate que Cloudflare esté en DNS ONLY (gris)${NC}"
sleep 3

# ===== SSL =====
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# ===== HTTPS (443) =====
cat >> /etc/nginx/conf.d/kira_ws.conf <<EOF

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /ws {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_read_timeout 86400; }
}
EOF

systemctl restart nginx

echo -e "${GR}✔ WS + SSL LISTO (80/443)${NC}"
sleep 3
}

# ===== MENU =====
while true; do
clear

get_status

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${WH}WEBSOCKET KIRA (PRO)${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " WS         : $WS_COLOR"
echo -e " SSL 443    : $SSL_STATUS"
echo -e " PORT 80    : $P80"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} ➤ Instalar WebSocket"
echo -e " ${WH}[2]${NC} ➤ Configurar WS + SSL (80/443)"
echo -e " ${WH}[3]${NC} ➤ Reiniciar servicios"
echo -e " ${WH}[4]${NC} ➤ Detener WebSocket"
echo -e " ${WH}[0]${NC} ➤ Volver"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion: " op

case $op in

1)
install_ws
;;

2)
setup_ws_ssl
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