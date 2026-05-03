#!/bin/bash

CONFIG="/etc/kira/domain"
WS_PORT=8888
LOCAL_PORT=9999

mkdir -p /etc/kira

install_ws() {

apt update -y
apt install wget tar nginx certbot python3-certbot-nginx -y

# ===== INSTALAR WSTUNNEL =====
wget -O /tmp/ws.tar.gz https://github.com/erebe/wstunnel/releases/download/v10.5.3/wstunnel_10.5.3_linux_amd64.tar.gz
tar -xzf /tmp/ws.tar.gz -C /tmp
mv /tmp/wstunnel /usr/bin/wstunnel
chmod +x /usr/bin/wstunnel

# ===== SERVER WS =====
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WS SERVER
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel server ws://0.0.0.0:${WS_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws
systemctl restart kira-ws

echo "WS SERVER OK"
}

setup_ssl() {

read -p "Dominio: " DOMAIN
echo "$DOMAIN" > $CONFIG

# CONFIG NGINX LIMPIO
cat > /etc/nginx/conf.d/kira.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /chat {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

systemctl restart nginx

# SSL
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# HTTPS FINAL
cat > /etc/nginx/conf.d/kira.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

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
    }
}
EOF

systemctl restart nginx

echo "SSL OK"
}

install_client() {

# MATAR SI EXISTE
fuser -k ${LOCAL_PORT}/tcp 2>/dev/null

cat > /etc/systemd/system/kira-client.service <<EOF
[Unit]
Description=KIRA CLIENT (SSH OVER WS)
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel client -L tcp://127.0.0.1:${LOCAL_PORT}:127.0.0.1:22 wss://$(cat $CONFIG)/chat
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-client
systemctl restart kira-client

echo "CLIENTE SSH ACTIVO"
}

status_all() {
echo "-----------------------"
systemctl status kira-ws | grep Active
systemctl status kira-client | grep Active
ss -tuln | grep -E "8888|9999"
echo "-----------------------"
}

while true; do
clear
echo "KIRA WS PANEL"
echo "1) Instalar WS"
echo "2) Configurar SSL"
echo "3) Activar cliente SSH (HTTP Injector)"
echo "4) Estado"
echo "0) Salir"
read -p "Opcion: " op

case $op in
1) install_ws ;;
2) setup_ssl ;;
3) install_client ;;
4) status_all ;;
0) exit ;;
esac
done