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
TMP="/tmp/wstunnel.tar.gz"
TMP_DIR="/tmp/wstunnel_extract"

mkdir -p /etc/kira

# ===== DEPENDENCIAS =====
command -v wget >/dev/null || apt install wget -y
command -v tar >/dev/null || apt install tar -y
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

# ===== INSTALAR WS =====
install_ws() {

echo -e "${CY}⬇️ Instalando WebSocket...${NC}"

# LIMPIEZA
systemctl stop kira-ws 2>/dev/null
systemctl disable kira-ws 2>/dev/null
rm -f /etc/systemd/system/kira-ws.service
systemctl daemon-reload

pkill -f wstunnel 2>/dev/null
fuser -k ${WS_PORT}/tcp 2>/dev/null

rm -f /usr/bin/wstunnel
rm -rf $TMP_DIR
rm -f $TMP

# DESCARGA
echo -e "${CY}Descargando binario oficial...${NC}"
wget -q --show-progress -O $TMP https://github.com/erebe/wstunnel/releases/download/v10.5.3/wstunnel_10.5.3_linux_amd64.tar.gz

if [ ! -f $TMP ]; then
    echo -e "${RD}✖ Error descarga${NC}"
    return
fi

SIZE=$(stat -c%s $TMP)
if [ "$SIZE" -lt 1000000 ]; then
    echo -e "${RD}✖ Archivo inválido ($SIZE bytes)${NC}"
    return
fi

# EXTRAER
mkdir -p $TMP_DIR
tar -xzf $TMP -C $TMP_DIR

BIN=$(find $TMP_DIR -type f -name wstunnel | head -n 1)

if [ ! -f "$BIN" ]; then
    echo -e "${RD}✖ No se encontró binario${NC}"
    return
fi

mv "$BIN" /usr/bin/wstunnel
chmod +x /usr/bin/wstunnel

# VALIDAR
/usr/bin/wstunnel --help >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RD}✖ Binario inválido${NC}"
    return
fi

echo -e "${GR}✔ Binario instalado${NC}"

# SERVICE CORRECTO
cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel server ws://0.0.0.0:${WS_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable kira-ws

systemctl restart kira-ws
sleep 2

if systemctl is-active --quiet kira-ws; then
    echo -e "${GR}✔ WebSocket ACTIVO${NC}"
else
    echo -e "${RD}✖ Error iniciando${NC}"
    journalctl -u kira-ws -n 10 --no-pager
    return
fi

ss -tuln | grep ${WS_PORT} && echo -e "${GR}✔ Puerto ${WS_PORT} OK${NC}" || echo -e "${RD}✖ Puerto no abierto${NC}"
}

# ===== CONFIG WS + SSL =====
setup_ws_ssl() {

read -p "🌐 Dominio: " DOMAIN

if [[ ! "$DOMAIN" =~ \. ]]; then
    echo -e "${RD}Dominio inválido${NC}"
    return
fi

echo "$DOMAIN" > $CONFIG

apt update -y
apt install nginx certbot python3-certbot-nginx -y

# LIMPIAR CONFIG PREVIA
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
        proxy_read_timeout 86400;
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

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${WH}WEBSOCKET KIRA FINAL PRO${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " WS         : $WS_COLOR"
echo -e " SSL 443    : $SSL_STATUS"
echo -e " PORT 80    : $P80"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} Instalar WebSocket"
echo -e " ${WH}[2]${NC} Configurar WS + SSL"
echo -e " ${WH}[3]${NC} Reiniciar servicios"
echo -e " ${WH}[4]${NC} Detener WebSocket"
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