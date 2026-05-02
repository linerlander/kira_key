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

pkill -9 -f proxy.py 2>/dev/null

[ -z "$PORTS" ] && PORTS="80"

PORTS=$(echo $PORTS | tr ' ' '\n' | sort -u | xargs)
PY_PORTS=$(echo $PORTS | sed 's/ /,/g')

# ===== PYTHON PRO =====
cat > /usr/local/bin/proxy.py <<EOF
import socket
import threading
import time

PORTS = [$PY_PORTS]

def start_server(port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("0.0.0.0", port))
        s.listen(200)

        print(f"[OK] Puerto activo: {port}")

        while True:
            conn, addr = s.accept()
            try:
                data = conn.recv(4096)
                if not data:
                    conn.close()
                    continue

                # respuesta básica proxy
                conn.send(b"HTTP/1.1 200 OK\\r\\n\\r\\n")

            except Exception as e:
                print("ERROR:", e)

            conn.close()

    except Exception as e:
        print(f"[ERROR] {port} -> {e}")

# 🔥 lanzar hilos correctos
for p in PORTS:
    t = threading.Thread(target=start_server, args=(p,))
    t.daemon = False
    t.start()

# 🔒 mantener vivo sin quemar CPU
while True:
    time.sleep(60)
EOF

# ===== SYSTEMD PRO =====
cat > /etc/systemd/system/proxy-python.service <<EOF
[Unit]
Description=KIRA Proxy Python
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/proxy.py
Restart=always
RestartSec=3

# 🔥 LOGS ACTIVOS
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable proxy-python
systemctl restart proxy-python

sleep 1

echo -e "${G}✔ Proxy activo y permanente${N}"
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
echo -e " ${M}[1]${N} Iniciar / Reiniciar Proxy"
echo -e " ${M}[2]${N} Agregar Puerto"
echo -e " ${M}[3]${N} Reset Completo"
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

if ! [[ "$P" =~ ^[0-9]+$ ]]; then
    echo -e "${R}Puerto inválido${N}"
    sleep 2
    continue
fi

echo "$P" >> $PORT_FILE
PORTS=$(cat $PORT_FILE | xargs)

echo -e "${G}✔ Puerto agregado${N}"
sleep 1
;;

3)
pkill -9 -f proxy.py
systemctl stop proxy-python
systemctl disable proxy-python
rm -f /usr/local/bin/proxy.py
rm -f /etc/systemd/system/proxy-python.service
> $PORT_FILE

echo -e "${R}✔ Reset TOTAL limpio${N}"
sleep 2
;;

4)
journalctl -u proxy-python -n 30 --no-pager
read -p "Enter..."
;;

0) break;;

*)
echo -e "${R}Opcion invalida${N}"
sleep 1
;;

esac

done