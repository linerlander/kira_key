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
BACKEND_PORT=80

mkdir -p /etc/kira

# ===== DEPENDENCIAS =====
command -v curl >/dev/null || apt install curl -y
command -v wget >/dev/null || apt install wget -y
command -v ss >/dev/null || apt install iproute2 -y
command -v lsof >/dev/null || apt install lsof -y

# ===== ESTADO =====
get_status() {

WS_STATUS=$(systemctl is-active kira-ws 2>/dev/null)
[ "$WS_STATUS" = "active" ] && WS_COLOR="${GR}[ON]${NC}" || WS_COLOR="${RD}[OFF]${NC}"

ss -tuln | grep -q ":443 " && SSL_STATUS="${GR}[ON]${NC}" || SSL_STATUS="${RD}[OFF]${NC}"
ss -tuln | grep -q ":80 " && P80="${GR}[ON]${NC}" || P80="${RD}[OFF]${NC}"

DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"
}

# ===== INSTALAR WEBSOCKET =====
install_ws() {

echo -e "${CY}⬇️ Instalando WebSocket...${NC}"

# limpiar
pkill -f wstunnel 2>/dev/null
rm -f /usr/bin/wstunnel

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    FILE="wstunnel_linux_amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    FILE="wstunnel_linux_arm64"
else
    echo -e "${RD}✖ Arquitectura no soportada${NC}"
    return
fi

echo -e "${CY}Descargando desde GitHub...${NC}"

# DESCARGA REAL (FUENTE CORRECTA)
wget -O /usr/bin/wstunnel \
https://github.com/erebe/wstunnel/releases/download/v7.2/$FILE

# FALLBACK
if [ ! -f /usr/bin/wstunnel ]; then
    curl -L https://github.com/erebe/wstunnel/releases/download/v7.2/$FILE -o /usr/bin/wstunnel
fi

# VALIDAR
if [ ! -f /usr/bin/wstunnel ]; then
    echo -e "${RD}✖ No se pudo descargar${NC}"
    return
fi

SIZE=$(stat -c%s /usr/bin/wstunnel 2>/dev/null)

if [ "$SIZE" -lt 1000000 ]; then
    echo -e "${RD}✖ Archivo inválido ($SIZE bytes)${NC}"
    rm -f /usr/bin/wstunnel
    return
fi

chmod +x /usr/bin/wstunnel

# validar ejecución
/usr/bin/wstunnel --help >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RD}✖ Binario no ejecutable${NC}"
    rm -f /usr/bin/wstunnel
    return
fi

echo -e "${GR}✔ WebSocket instalado correctamente${NC}"

# liberar puerto
PID=$(lsof -t -i:${WS_PORT})
[ ! -z "$PID" ] && kill -9 $PID

# ===== SYSTEMD =====
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel -s 127.0.0.1:${WS_PORT} --restrict-to 127.0.0.1:${BACKEND_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-ws >/dev/null 2>&1
systemctl restart kira-ws

sleep 2

if systemctl is-active --quiet kira-ws; then
    echo -e "${GR}✔ WebSocket ACTIVO${NC}"
else
    echo -e "${RD}✖ Error al iniciar${NC}"
    journalctl -u kira-ws -n 10 --no-pager
fi
}

# ===== CONFIG NGINX + SSL =====
setup_ws_ssl() {

read -p "🌐 Dominio: " DOMAIN

if [[ ! "$DOMAIN" =~ \. ]]; then
    echo -e "${RD}✖ Dominio inválido${NC}"
    return
fi

echo "$DOMAIN" > $CONFIG

apt update -y
apt install nginx certbot python3-certbot-nginx -y

rm -f /etc/nginx/conf.d/kira_ws.conf

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
    }

    location /api {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

systemctl restart nginx

echo -e "${GR}✔ WS + SSL configurado${NC}"
}

# ===== MENU =====
while true; do
clear

get_status

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${WH}WEBSOCKET KIRA (FINAL)${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " WS         : $WS_COLOR"
echo -e " SSL 443    : $SSL_STATUS"
echo -e " PORT 80    : $P80"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} Instalar WebSocket"
echo -e " ${WH}[2]${NC} Configurar WS + SSL"
echo -e " ${WH}[3]${NC} Reiniciar"
echo -e " ${WH}[4]${NC} Detener"
echo -e " ${WH}[0]${NC} Salir"

read -p " ► Opcion: " op

case $op in

1) install_ws ;;
2) setup_ws_ssl ;;
3) systemctl restart kira-ws && systemctl restart nginx ;;
4) systemctl stop kira-ws ;;
0) break ;;

*) echo -e "${RD}Opcion invalida${NC}"; sleep 1 ;;

esac
done