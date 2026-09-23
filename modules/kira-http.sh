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
PY_PORT=8080

mkdir -p /etc/kira

banner() {
clear
echo -e "${C}"
echo "╔══════════════════════════════════════╗"
echo "║     🚀 KIRA HTTP INJECTOR (CHUMO)    ║"
echo "║       Python + SSL + Proxy HTTP      ║"
echo "╚══════════════════════════════════════╝"
echo -e "${N}"
}

# ================================
install_all() {

echo -e "${B}📦 Instalando dependencias...${N}"
apt update -y
apt install -y python3 nginx certbot python3-certbot-nginx

# limpieza total
systemctl stop nginx 2>/dev/null
killall python3 2>/dev/null
fuser -k 80/tcp 2>/dev/null
fuser -k 443/tcp 2>/dev/null

rm -f /run/nginx.pid

echo -e "${G}✔ Sistema limpio${N}"
}

# ================================
start_python() {

echo -e "${B}🔥 Iniciando Python en puerto ${PY_PORT}...${N}"

killall python3 2>/dev/null
fuser -k ${PY_PORT}/tcp 2>/dev/null

nohup python3 -m http.server ${PY_PORT} > /dev/null 2>&1 &

sleep 2

ss -tuln | grep :${PY_PORT} && \
echo -e "${G}✔ Python activo en ${PY_PORT}${N}" || \
echo -e "${R}✖ Error Python${N}"
}

# ================================
setup_domain() {

read -p "🌐 Dominio: " DOMAIN
echo "$DOMAIN" > $CONFIG

echo -e "${B}⚙️ Configurando nginx...${N}"

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/conf.d/*.conf

cat > /etc/nginx/conf.d/kira.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:${PY_PORT};
        proxy_set_header Host \$host;
    }
}
EOF

# probar config antes de reiniciar
nginx -t || { echo -e "${R}Error en nginx config${N}"; return; }

systemctl start nginx
systemctl enable nginx

echo -e "${B}🔐 Generando SSL...${N}"

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

systemctl restart nginx

echo -e "${G}✔ Dominio + SSL listos${N}"
}

# ================================
status_all() {

echo -e "${Y}===== ESTADO =====${N}"

echo -e "PYTHON : $(ss -tuln | grep :${PY_PORT} >/dev/null && echo ACTIVO || echo OFF)"
echo -e "NGINX  : $(systemctl is-active nginx)"

echo ""
ss -tuln | grep -E "80|443|${PY_PORT}"
}

# ================================
while true; do
banner

echo -e "${W}[1] Instalar sistema${N}"
echo -e "${W}[2] Iniciar Python${N}"
echo -e "${W}[3] Configurar dominio + SSL${N}"
echo -e "${W}[4] Estado${N}"
echo -e "${W}[0] Salir${N}"

read -p "➤ Opción: " op

case $op in
1) install_all ;;
2) start_python ;;
3) setup_domain ;;
4) status_all ;;
0) exit ;;
*) echo "Opción inválida" ;;
esac

read -p "Enter..."
done