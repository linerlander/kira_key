#!/bin/bash

R='\033[1;91m'
G='\033[1;92m'
Y='\033[1;93m'
M='\033[1;95m'
C='\033[1;96m'
W='\033[1;97m'
N='\033[0m'

CONFIG="/etc/kira/domain"
PORT_FILE="/etc/kira/proxy_ports"
MODE_FILE="/etc/kira/proxy_mode"
BANNER_FILE="/etc/kira/proxy_banner"

mkdir -p /etc/kira

DOMAIN=$(cat $CONFIG 2>/dev/null)
PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)
MODE=$(cat $MODE_FILE 2>/dev/null)
BANNER=$(cat $BANNER_FILE 2>/dev/null)

[ -z "$DOMAIN" ] && DOMAIN="--"
[ -z "$PORTS" ] && PORTS=""
[ -z "$MODE" ] && MODE="ws"
[ -z "$BANNER" ] && BANNER="KIRA"

# ===== INSTALAR PROXY =====
install_proxy() {

# limpiar procesos
pkill -9 -f proxy.py 2>/dev/null

# validar puertos
[ -z "$PORTS" ] && PORTS="80"

PORTS=$(echo $PORTS | tr ' ' '\n' | sort -u | xargs)

PY_PORTS=$(echo $PORTS | sed 's/ /,/g')

# ===== PYTHON =====
cat > /usr/local/bin/proxy.py <<EOF
import socket, threading

PORTS = [$PY_PORTS]
BUFFER = 4096

def handle(c):
    try:
        data = c.recv(BUFFER)
        if not data:
            c.close()
            return

        if b"CONNECT" in data:
            c.send(b"HTTP/1.1 200 OK\\r\\n\\r\\n")
        else:
            c.send(b"HTTP/1.1 200 OK\\r\\n\\r\\n")

    except Exception as e:
        print("ERROR:", e)
    finally:
        c.close()

def start(p):
    try:
        s = socket.socket()
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("0.0.0.0", p))
        s.listen(200)
        print("PUERTO ACTIVO:", p)

        while True:
            c, _ = s.accept()
            threading.Thread(target=handle, args=(c,)).start()

    except Exception as e:
        print("ERROR PUERTO", p, e)

for p in PORTS:
    threading.Thread(target=start, args=(p,)).start()

while True:
    pass
EOF

# ===== SYSTEMD =====
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

systemctl daemon-reload
systemctl enable proxy-python
systemctl restart proxy-python

sleep 1

echo -e "${G}✔ Proxy iniciado${N}"
}

# ===== MENU =====
while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}⚜️ KIRA PROXY ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " 🌐 Dominio : $DOMAIN"
echo -e " 📡 Puertos : $PORTS"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${M}[1]${N} Iniciar Proxy"
echo -e " ${M}[2]${N} Agregar Puerto"
echo -e " ${M}[3]${N} Reset"
echo -e " ${M}[4]${N} Ver Logs"
echo -e " ${R}[0] Salir${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op

case $op in

1)
install_proxy
;;

2)
read -p "Puerto: " P
echo "$P" >> $PORT_FILE
PORTS=$(cat $PORT_FILE | xargs)
;;

3)
pkill -9 -f proxy.py
systemctl stop proxy-python
> $PORT_FILE
echo -e "${R}Reset completo${N}"
sleep 2
;;

4)
journalctl -u proxy-python -n 20 --no-pager
read -p "Enter..."
;;

0) break;;

esac

done