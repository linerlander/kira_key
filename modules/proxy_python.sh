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
MODE_FILE="/etc/kira/proxy_mode"
BANNER_FILE="/etc/kira/proxy_banner"

mkdir -p /etc/kira

# ===== DATOS =====
DOMAIN=$(cat $CONFIG 2>/dev/null)
PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)
MODE=$(cat $MODE_FILE 2>/dev/null)
BANNER=$(cat $BANNER_FILE 2>/dev/null)

[ -z "$DOMAIN" ] && DOMAIN="--"
[ -z "$PORTS" ] && PORTS="--"
[ -z "$MODE" ] && MODE="none"
[ -z "$BANNER" ] && BANNER="KIRA-PROXY"

# ===== STATUS =====
mode_status() {
    if systemctl is-active --quiet proxy-python; then
        [ "$MODE" = "$1" ] && echo -e "${GR}[ON]${NC}" || echo -e "${GY}[OFF]${NC}"
    else
        echo -e "${RD}[OFF]${NC}"
    fi
}

# ===== INSTALAR PROXY =====
install_proxy() {

cat > /usr/local/bin/proxy.py <<EOF
import socket, threading

PORTS = [$PORTS]
MODE = "$MODE"
BANNER = "$BANNER"

def handle(c):
    try:
        data = c.recv(4096)

        if MODE == "secure":
            if b"Host:" not in data:
                c.close()
                return

        if b"CONNECT" in data or b"GET" in data or b"Upgrade" in data:
            response = f"HTTP/1.1 200 OK\\r\\nServer: {BANNER}\\r\\n\\r\\n"
            c.send(response.encode())

        while True:
            c.recv(4096)
    except:
        pass
    c.close()

def start(port):
    s = socket.socket()
    s.bind(("0.0.0.0", port))
    s.listen(200)
    while True:
        c, _ = s.accept()
        threading.Thread(target=handle, args=(c,)).start()

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

# ===== DEBUG MODE =====
run_debug() {
screen -dmS kira-proxy python3 /usr/local/bin/proxy.py
}

# ===== MENU =====
while true; do
clear

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}⚜️ PROXY PYTHON KIRA ⚜️${NC}"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " 🌐 Dominio : ${WH}$DOMAIN${NC}"
echo -e " 📡 Puertos : ${WH}$PORTS${NC}"
echo -e " 🏷️ Banner  : ${WH}$BANNER${NC}"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WH}[1]${NC} > 🟢 SIMPLE (SYSTEM)   $(mode_status simple)"
echo -e " ${WH}[2]${NC} > 🟢 SEGURO (SYSTEM)   $(mode_status secure)"
echo -e " ${WH}[3]${NC} > 🔥 WS (SYSTEM)       $(mode_status ws)"
echo -e " ${WH}[4]${NC} > 🧪 DEBUG (SCREEN)"

echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${WH}[5]${NC} > ✏️ Cambiar Banner"
echo -e " ${WH}[6]${NC} > ➕ Agregar Puerto"
echo -e " ${WH}[7]${NC} > ❌ Detener Todo"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${WH}[0]${NC} > Volver"
echo -e "${YL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${GY}💡 SYSTEM = estable | DEBUG = pruebas en vivo${NC}"

read -p " ► Opcion : " op

case $op in

1) MODE="simple"; echo "simple" > $MODE_FILE ;;
2) MODE="secure"; echo "secure" > $MODE_FILE ;;
3) MODE="ws"; echo "ws" > $MODE_FILE ;;

4)
run_debug
echo -e "${CY}✔ Proxy en modo DEBUG (screen)${NC}"
sleep 2
continue
;;

5)
read -p "Nuevo banner: " BANNER
echo "$BANNER" > $BANNER_FILE
;;

6)
read -p "Puerto nuevo: " NEWPORT
if ss -tuln | grep -q ":$NEWPORT "; then
    echo -e "${RD}Puerto ocupado${NC}"
    sleep 2
    continue
fi
echo "$NEWPORT" >> $PORT_FILE
;;

7)
> $PORT_FILE
systemctl stop proxy-python
pkill -f proxy.py
echo -e "${RD}✔ Todo detenido${NC}"
sleep 2
continue
;;

0) break ;;

*)
echo -e "${RD}Opcion invalida${NC}"
sleep 1
continue
;;

esac

# ===== CONFIG BASICA =====
[ ! -f "$CONFIG" ] && read -p "Dominio: " DOMAIN && echo "$DOMAIN" > $CONFIG
[ ! -f "$PORT_FILE" ] && read -p "Puerto inicial: " PORT && echo "$PORT" > $PORT_FILE

PORTS=$(cat $PORT_FILE | xargs)

install_proxy

done