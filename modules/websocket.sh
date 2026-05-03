#!/bin/bash

# ===== COLORES PRO =====
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888
LOCAL_PORT=9999
TMP="/tmp/wstunnel.tar.gz"

mkdir -p /etc/kira

# ===== HEADER =====
banner() {
echo -e "${CYAN}"
echo "╔══════════════════════════════════════╗"
echo "║        🚀 KIRA WS TUNNEL PRO         ║"
echo "║        WebSocket + SSL + SSH         ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"
}

# ===== DEPENDENCIAS =====
deps() {
apt update -y
apt install -y wget tar nginx certbot python3-certbot-nginx netcat iproute2
}

# ===== ESTADO =====
status_check() {
WS=$(systemctl is-active kira-ws 2>/dev/null)
CL=$(systemctl is-active kira-ws-client 2>/dev/null)

[ "$WS" = "active" ] && WS_COLOR="${GREEN}ON${NC}" || WS_COLOR="${RED}OFF${NC}"
[ "$CL" = "active" ] && CL_COLOR="${GREEN}ON${NC}" || CL_COLOR="${RED}OFF${NC}"

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"
}

# ===== INSTALAR WSTUNNEL =====
install_ws() {

echo -e "${BLUE}📦 Instalando wstunnel...${NC}"

systemctl stop kira-ws kira-ws-client 2>/dev/null
rm -f /etc/systemd/system/kira-ws*.service
pkill -f wstunnel

rm -f /usr/bin/wstunnel
wget -O $TMP https://github.com/erebe/wstunnel/releases/download/v10.5.3/wstunnel_10.5.3_linux_amd64.tar.gz

tar -xzf $TMP -C /tmp
mv /tmp/wstunnel /usr/bin/
chmod +x /usr/bin/wstunnel

echo -e "${GREEN}✔ wstunnel instalado${NC}"

# ===== SERVER =====
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WS SERVER
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

ss -tuln | grep ${WS_PORT} && \
echo -e "${GREEN}✔ WS corriendo en ${WS_PORT}${NC}" || \
echo -e "${RED}✖ WS no inició${NC}"
}

# ===== CLIENTE SSH AUTOMÁTICO =====
install_client() {

DOMAIN=$(cat $CONFIG)

if [ -z "$DOMAIN" ]; then
echo -e "${RED}Primero configura dominio (opcion 2)${NC}"
return
fi

echo -e "${BLUE}🔗 Activando túnel SSH automático...${NC}"

fuser -k ${LOCAL_PORT}/tcp 2>/dev/null

cat > /etc/systemd/system/kira-ws-client.service <<EOF
[Unit]
Description=KIRA WS CLIENT (SSH)
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel client \
-L tcp://127.0.0.1:${LOCAL_PORT}:127.0.0.1:22 \
wss://${DOMAIN}/chat
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws-client
systemctl restart kira-ws-client

sleep 3

ss -tuln | grep ${LOCAL_PORT} && \
echo -e "${GREEN}✔ SSH tunnel activo en ${LOCAL_PORT}${NC}" || \
echo -e "${RED}✖ Fallo túnel${NC}"
}

# ===== NGINX + SSL =====
setup_ssl() {

read -p "🌐 Dominio: " DOMAIN

echo "$DOMAIN" > $CONFIG

echo -e "${BLUE}⚙️ Configurando NGINX...${NC}"

cat > /etc/nginx/conf.d/kira_ws.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /chat {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
}
EOF

systemctl restart nginx

echo -e "${BLUE}🔐 Generando SSL...${NC}"

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

cat > /etc/nginx/conf.d/kira_ws_ssl.conf <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /chat {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
    }
}
EOF

systemctl restart nginx

echo -e "${GREEN}✔ SSL + WS listo${NC}"
}

# ===== MENU =====
while true; do
clear
banner
status_check

echo -e "${WHITE}🌐 Dominio : ${CYAN}$DOMAIN${NC}"
echo -e "WS Server  : $WS_COLOR"
echo -e "WS Cliente : $CL_COLOR"

echo -e "\n${YELLOW}════════ OPCIONES ════════${NC}"
echo -e "${WHITE}[1]${NC} Instalar WebSocket"
echo -e "${WHITE}[2]${NC} Configurar SSL + Dominio"
echo -e "${WHITE}[3]${NC} Activar túnel SSH automático"
echo -e "${WHITE}[4]${NC} Reiniciar todo"
echo -e "${WHITE}[5]${NC} Detener todo"
echo -e "${WHITE}[0]${NC} Salir"

read -p "➤ Opción: " op

case $op in
1) deps; install_ws ;;
2) setup_ssl ;;
3) install_client ;;
4) systemctl restart kira-ws kira-ws-client nginx ;;
5) systemctl stop kira-ws kira-ws-client ;;
0) break ;;
*) echo -e "${RED}Opción inválida${NC}" ;;
esac

read -p "Enter para continuar..."
done