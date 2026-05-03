#!/bin/bash

# ===== COLORES =====
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

CONFIG="/etc/kira/domain"
WS_PORT=8888
SOCKS_PORT=1080

mkdir -p /etc/kira

banner() {
clear
echo -e "${C}"
echo "╔══════════════════════════════════════╗"
echo "║      🚀 KIRA WS + INJECTOR PRO       ║"
echo "║         FIXED & STABLE BUILD         ║"
echo "╚══════════════════════════════════════╝"
echo -e "${N}"
}

# ================================
install_all() {

echo -e "${B}📦 Instalando dependencias...${N}"
apt update -y
apt install -y wget tar nginx certbot python3-certbot-nginx

echo -e "${B}⬇️ Instalando wstunnel limpio...${N}"
rm -f /usr/bin/wstunnel
wget -q -O /tmp/ws.tar.gz https://github.com/erebe/wstunnel/releases/download/v10.5.3/wstunnel_10.5.3_linux_amd64.tar.gz
tar -xzf /tmp/ws.tar.gz -C /tmp
mv /tmp/wstunnel /usr/bin/
chmod +x /usr/bin/wstunnel

# ===== LIMPIEZA TOTAL =====
systemctl stop kira-ws 2>/dev/null
killall wstunnel 2>/dev/null
fuser -k ${WS_PORT}/tcp 2>/dev/null

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

echo -e "${G}✔ WS server activo${N}"
}

# ================================
setup_domain() {

read -p "🌐 Dominio: " DOMAIN
echo "$DOMAIN" > $CONFIG

echo -e "${B}⚙️ Configurando nginx limpio...${N}"

rm -f /etc/nginx/conf.d/*.conf

# ===== CONFIG GLOBAL =====
cat > /etc/nginx/conf.d/kira.conf <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;

        proxy_read_timeout 86400;
    }
}
EOF

systemctl restart nginx

echo -e "${B}🔐 Generando SSL...${N}"
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

systemctl restart nginx

echo -e "${G}✔ Dominio + SSL listos${N}"
}

# ================================
install_client() {

DOMAIN=$(cat $CONFIG)

if [ -z "$DOMAIN" ]; then
echo -e "${R}Configura dominio primero${N}"
return
fi

echo -e "${B}🔗 Activando SOCKS5 limpio...${N}"

# ===== LIMPIEZA =====
systemctl stop kira-client 2>/dev/null
killall wstunnel 2>/dev/null
fuser -k ${SOCKS_PORT}/tcp 2>/dev/null

# ===== CLIENT =====
cat > /etc/systemd/system/kira-client.service <<EOF
[Unit]
Description=KIRA CLIENT SOCKS5
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel client -L socks5://127.0.0.1:${SOCKS_PORT} wss://${DOMAIN}/
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-client
systemctl restart kira-client

sleep 3

ss -tuln | grep ${SOCKS_PORT} && \
echo -e "${G}✔ SOCKS5 activo en ${SOCKS_PORT}${N}" || \
echo -e "${R}✖ Error SOCKS5${N}"
}

# ================================
status_all() {

echo -e "${Y}===== ESTADO =====${N}"
echo -e "WS SERVER : $(systemctl is-active kira-ws)"
echo -e "CLIENTE   : $(systemctl is-active kira-client)"
echo ""

ss -tuln | grep -E "8888|1080"
}

# ================================
while true; do
banner

echo -e "${W}[1] Instalar sistema${N}"
echo -e "${W}[2] Configurar dominio + SSL${N}"
echo -e "${W}[3] Activar SOCKS5${N}"
echo -e "${W}[4] Estado${N}"
echo -e "${W}[0] Salir${N}"

read -p "➤ Opción: " op

case $op in
1) install_all ;;
2) setup_domain ;;
3) install_client ;;
4) status_all ;;
0) exit ;;
*) echo "Opción inválida" ;;
esac

read -p "Enter..."
done