#!/bin/bash

# ===== COLORES =====
YL='\033[38;5;220m'
GR='\033[38;5;118m'
RD='\033[38;5;203m'
CY='\033[38;5;51m'
WH='\033[1;37m'
GY='\033[38;5;245m'
NC='\033[0m'

CONFIG="/etc/kira/domain"
PORT_FILE="/etc/kira/proxy_ports"

# ===== DATOS =====
DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"

PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)
[ -z "$PORTS" ] && PORTS="--"

# ===== FUNCIONES =====
port_active() {
    ss -tuln | grep -q ":$1 "
}

service_status() {
    if systemctl is-active --quiet proxy-python; then
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

# ===== INSTALAR PROXY MULTI =====
install_proxy() {

cat > /usr/local/bin/proxy.py <<EOF
import socket, threading

PORTS = [$PORTS]

def start(port):
    s = socket.socket()
    s.bind(("0.0.0.0", port))
    s.listen(200)
    while True:
        c, _ = s.accept()
        threading.Thread(target=handle, args=(c,)).start()

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

for p in PORTS:
    threading.Thread(target=start, args=(p,)).start()

while True:
    pass
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
systemctl restart proxy-python
systemctl enable proxy-python
}

# ===== MENU =====
while true; do
clear

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}⚜️ PROXY PYTHON KIRA ⚜️${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${GY}* Puertas Activas en su Servidor *${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

printf " ∘ SSH: ${WH}%-6s${NC} ∘ HTTP: ${WH}%-6s${NC}\n" "$SSH_PORT" "$HTTP_PORT"
printf " ∘ PYTHON: ${WH}%-10s${NC} ∘ WS: ${WH}%-6s${NC}\n" "$PORTS" "$WS_PORT"
printf " ∘ BadVPN: ${WH}%-10s${NC}\n" "$BADVPN_PORTS"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " 📡 Puertos : ${WH}$PORTS${NC}"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} > Socks Python SIMPLE      ${GR}[ON]${NC}"
echo -e " ${WH}[2]${NC} > Socks Python SEGURO      ${GR}[ON]${NC}"
echo -e " ${WH}[3]${NC} > Socks Python DIRETO (WS) ${GR}[ON]${NC}"
echo -e " ${WH}[4]${NC} > Socks Python OPENVPN     ${RD}[OFF]${NC}"
echo -e " ${WH}[5]${NC} > Socks Python GETTUNEL    ${RD}[OFF]${NC}"
echo -e " ${WH}[6]${NC} > Socks Python TCP BYPASS  ${RD}[OFF]${NC}"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${WH}[7]${NC} > ANULAR TODOS   ${WH}[8]${NC} > AGREGAR PUERTO"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}[0]${NC} > VOLVER"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p " ► Opcion : " op

case $op in

1|2|3)

    if [ ! -f "$CONFIG" ]; then
        read -p "🌐 Dominio: " DOMAIN
        mkdir -p /etc/kira
        echo "$DOMAIN" > "$CONFIG"
    fi

    read -p "📡 Nuevo puerto: " NEWPORT

    if ss -tuln | grep -q ":$NEWPORT "; then
        echo -e "${RD}Puerto ocupado${NC}"
        sleep 2
        continue
    fi

    echo "$NEWPORT" >> $PORT_FILE
    PORTS=$(cat $PORT_FILE | xargs)

    install_proxy
;;

7)
> $PORT_FILE
systemctl stop proxy-python
;;

8)
read -p "Eliminar puerto: " DEL
sed -i "/$DEL/d" $PORT_FILE
PORTS=$(cat $PORT_FILE | xargs)
install_proxy
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