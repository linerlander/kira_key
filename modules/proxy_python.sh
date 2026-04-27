#!/bin/bash

# ===== COLORES =====
AZ='\033[38;5;39m'
GR='\033[38;5;120m'
RD='\033[38;5;203m'
WH='\033[1;37m'
GY='\033[38;5;245m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
PORT_FILE="/etc/kira/proxy_port"

# ===== DATOS =====
DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"

PORT=$(cat $PORT_FILE 2>/dev/null)
[ -z "$PORT" ] && PORT="--"

# ===== FUNCIONES =====
port_active() {
    ss -tuln | grep -q ":$1 "
}

service_status() {
    if systemctl is-active --quiet proxy-python && port_active "$PORT"; then
        echo -e "${GR}[ON]${NC}"
    else
        echo -e "${RD}[OFF]${NC}"
    fi
}

# ===== DETECTAR PUERTOS =====
SSH_PORT=$(ss -tuln | grep -w ':22 ' >/dev/null && echo "22" || echo "--")
HTTP_PORT=$(ss -tuln | grep -w ':80 ' >/dev/null && echo "80" || echo "--")
WS_PORT=$(ss -tuln | grep -w ':8888 ' >/dev/null && echo "8888" || echo "--")

BADVPN_PORTS=$(ss -tuln | grep -E ':7100|:7200|:7300' | awk '{print $5}' | cut -d: -f2 | xargs)
[ -z "$BADVPN_PORTS" ] && BADVPN_PORTS="--"

STATUS=$(service_status)

# ===== INSTALAR PROXY =====
install_proxy() {

cat > /usr/local/bin/proxy.py <<EOF
import socket, threading
PORT = $PORT

def handle(c):
    try:
        data = c.recv(4096)
        if b"CONNECT" in data or b"GET" in data:
            c.send(b"HTTP/1.1 200 OK\\r\\n\\r\\n")
        while True:
            c.recv(4096)
    except:
        pass
    c.close()

s = socket.socket()
s.bind(("0.0.0.0", PORT))
s.listen(200)

while True:
    c, _ = s.accept()
    threading.Thread(target=handle, args=(c,)).start()
EOF

cat > /etc/systemd/system/proxy-python.service <<EOF
[Unit]
Description=KIRA Proxy Python
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/proxy.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable proxy-python
systemctl restart proxy-python
}

# ===== MENU =====
while true; do
clear

echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}==== SCRIPT MOD KIRA ==== ${NC}"
echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${GY}* Puertas Activas en su Servidor *${NC}"
echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

printf " ∘ SSH: ${WH}%-6s${NC} ∘ HTTP: ${WH}%-6s${NC}\n" "$SSH_PORT" "$HTTP_PORT"
printf " ∘ PYTHON: ${WH}%-6s${NC} ∘ WS: ${WH}%-6s${NC}\n" "$PORT" "$WS_PORT"
printf " ∘ BadVPN: ${WH}%-10s${NC}\n" "$BADVPN_PORTS"

echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " 📡 Puerto  : ${WH}$PORT${NC}"

echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} > Socks Python SIMPLE      $STATUS"
echo -e " ${WH}[2]${NC} > Socks Python SEGURO      $STATUS"
echo -e " ${WH}[3]${NC} > Socks Python DIRETO (WS) $STATUS"
echo -e " ${WH}[4]${NC} > Socks Python OPENVPN     ${RD}[OFF]${NC}"
echo -e " ${WH}[5]${NC} > Socks Python GETTUNEL    ${RD}[OFF]${NC}"
echo -e " ${WH}[6]${NC} > Socks Python TCP BYPASS  ${RD}[OFF]${NC}"

echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${WH}[7]${NC} > ANULAR TODOS   ${WH}[8]${NC} > CAMBIAR PUERTO"
echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}[0]${NC} > VOLVER"
echo -e "${AZ}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion : " op

case $op in

1|2|3)

    if [ ! -f "$CONFIG" ]; then
        read -p "🌐 Dominio: " DOMAIN
        mkdir -p /etc/kira
        echo "$DOMAIN" > "$CONFIG"
    fi

    read -p "📡 Puerto (default 80): " PORT
    [ -z "$PORT" ] && PORT=80

    if ss -tuln | grep -q ":$PORT "; then
        echo -e "${RD}Puerto ocupado${NC}"
        sleep 2
        continue
    fi

    echo "$PORT" > $PORT_FILE
    install_proxy
;;

7)
systemctl stop proxy-python
;;

8)
read -p "Nuevo puerto: " PORT
echo "$PORT" > $PORT_FILE
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