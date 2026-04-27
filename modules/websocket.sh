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

# ===== DEPENDENCIAS =====
command -v curl >/dev/null || apt install curl -y

# ===== ESTADO DINAMICO =====
get_status() {

WS_STATUS=$(systemctl is-active kira-ws 2>/dev/null)

[ "$WS_STATUS" = "active" ] && WS_COLOR="${GR}[ON]${NC}" || WS_COLOR="${RD}[OFF]${NC}"

ss -tuln | grep -q ":443 " && SSL_STATUS="${GR}[ON]${NC}" || SSL_STATUS="${RD}[OFF]${NC}"
ss -tuln | grep -q ":80 " && P80="${GR}[ON]${NC}" || P80="${RD}[OFF]${NC}"
ss -tuln | grep -q ":8080 " && P8080="${GR}[ON]${NC}" || P8080="${RD}[OFF]${NC}"
ss -tuln | grep -q ":2082 " && P2082="${GR}[ON]${NC}" || P2082="${RD}[OFF]${NC}"

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"
}

# ===== INSTALAR WEBSOCKET (ANTI-FALLOS) =====
install_ws() {

echo -e "${CY}⬇️ Instalando WebSocket...${NC}"

rm -f /usr/bin/wstunnel

curl -L https://github.com/erebe/wstunnel/releases/download/v7.2/wstunnel_linux_amd64 -o /usr/bin/wstunnel

# VALIDAR
if [ ! -f /usr/bin/wstunnel ]; then
    echo -e "${RD}✖ Error descargando wstunnel${NC}"
    sleep 2
    return
fi

file /usr/bin/wstunnel | grep -q "ELF"

if [ $? -ne 0 ]; then
    echo -e "${RD}✖ Descarga corrupta (bloqueo GitHub)${NC}"
    rm -f /usr/bin/wstunnel
    sleep 2
    return
fi

chmod +x /usr/bin/wstunnel

# SERVICIO
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

# ===== MULTI WS + NGINX + SSL =====
setup_ws_full() {

read -p "🌐 Dominio: " DOMAIN
mkdir -p /etc/kira
echo "$DOMAIN" > $CONFIG

echo -e "${CY}⚙️ Instalando NGINX + SSL...${NC}"

apt install nginx certbot python3-certbot-nginx -y

# LIMPIAR
rm -f /etc/nginx/sites-enabled/default

# ===== CONFIG MULTIPUERTO =====
cat > /etc/nginx/conf.d/kira_ws.conf <<EOF

# ===== HTTP MULTIPUERTO =====
server {
    listen 80;
    listen 8080;
    listen 2082;
    server_name $DOMAIN;

    location /ws { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /api { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /connect { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /graphql { proxy_pass http://127.0.0.1:${WS_PORT}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
}
EOF

systemctl restart nginx

# ===== SSL =====
echo -e "${YL}⚠️ IMPORTANTE: Cloudflare en modo DNS ONLY (gris)${NC}"
sleep 2

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# ===== BLOQUE 443 =====
cat >> /etc/nginx/conf.d/kira_ws.conf <<EOF

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
sleep 3
}

# ===== MENU =====
while true; do
clear

get_status

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${WH}WEBSOCKET MULTIPUERTO KIRA${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " WS        : $WS_COLOR"
echo -e " SSL 443   : $SSL_STATUS"
echo -e " PORT 80   : $P80"
echo -e " PORT 8080 : $P8080"
echo -e " PORT 2082 : $P2082"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} ➤ Instalar WebSocket"
echo -e " ${WH}[2]${NC} ➤ Configurar MULTI WS + SSL"
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