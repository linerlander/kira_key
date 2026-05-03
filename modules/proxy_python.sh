#!/bin/bash

# ===== COLORES =====
R='\033[1;91m'
G='\033[1;92m'
Y='\033[1;93m'
M='\033[1;95m'
C='\033[1;96m'
W='\033[1;97m'
N='\033[0m'

CONFIG="/etc/kira/domain"
PORT_FILE="/etc/kira/proxy_ports"

mkdir -p /etc/kira

DOMAIN=$(cat $CONFIG 2>/dev/null)
PORTS=$(cat $PORT_FILE 2>/dev/null | xargs)

[ -z "$DOMAIN" ] && DOMAIN="--"
[ -z "$PORTS" ] && PORTS="80"

# ===== INSTALAR PROXY =====
install_proxy() {

echo -e "${Y}➤ Iniciando Proxy...${N}"

systemctl stop proxy-python 2>/dev/null

PORTS=$(echo $PORTS | tr ' ' '\n' | sort -u | xargs)
[ -z "$PORTS" ] && PORTS="80"

PY_PORTS=$(echo $PORTS | sed 's/ /,/g')

# ===== PYTHON CONNECT REAL =====
cat > /usr/local/bin/proxy.py <<EOF
import socket
import threading
import select
import time

PORTS = [$PY_PORTS]
BUFFER = 4096

def tunnel(client, remote):
    try:
        while True:
            r, _, _ = select.select([client, remote], [], [])
            if client in r:
                data = client.recv(BUFFER)
                if not data:
                    break
                remote.sendall(data)
            if remote in r:
                data = remote.recv(BUFFER)
                if not data:
                    break
                client.sendall(data)
    except:
        pass
    finally:
        client.close()
        remote.close()

def handle_client(conn):
    try:
        data = conn.recv(BUFFER)
        if not data:
            conn.close()
            return

        first_line = data.split(b'\n')[0]

        # ===== CONNECT =====
        if b"CONNECT" in first_line:
            target = first_line.split()[1]
            host, port = target.split(b":")
            port = int(port)

            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.connect((host.decode(), port))

            conn.send(b"HTTP/1.1 200 Connection Established\\r\\n\\r\\n")
            tunnel(conn, remote)
            return

        # ===== HTTP NORMAL =====
        else:
            lines = data.split(b"\\r\\n")
            host = None

            for line in lines:
                if line.lower().startswith(b"host:"):
                    host = line.split(b":")[1].strip()
                    break

            if not host:
                conn.close()
                return

            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.connect((host.decode(), 80))

            remote.sendall(data)
            tunnel(conn, remote)

    except:
        pass
    finally:
        conn.close()

def start_server(port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("0.0.0.0", port))
        s.listen(200)

        print(f"[OK] Proxy activo en puerto {port}")

        while True:
            conn, _ = s.accept()
            threading.Thread(target=handle_client, args=(conn,), daemon=True).start()

    except Exception as e:
        print(f"[ERROR] {port}: {e}")

for p in PORTS:
    threading.Thread(target=start_server, args=(p,), daemon=False).start()

while True:
    time.sleep(60)
EOF

chmod +x /usr/local/bin/proxy.py

# ===== SYSTEMD =====
cat > /etc/systemd/system/proxy-python.service <<EOF
[Unit]
Description=KIRA Proxy Python
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/proxy.py
Restart=always
RestartSec=3

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start proxy-python
systemctl enable proxy-python

sleep 1

if systemctl is-active --quiet proxy-python; then
    echo -e "${G}✔ Proxy ACTIVO${N}"
else
    echo -e "${R}✖ Error al iniciar${N}"
fi
}

# ===== RESET =====
reset_all() {

echo -e "${Y}➤ Eliminando todo...${N}"

systemctl stop proxy-python 2>/dev/null
systemctl disable proxy-python 2>/dev/null

rm -f /etc/systemd/system/proxy-python.service
rm -f /usr/local/bin/proxy.py
rm -f $PORT_FILE

systemctl daemon-reload

echo -e "${G}✔ Reset completo limpio${N}"
}

# ===== MENU =====
while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}⚜️ KIRA PROXY FINAL ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " 🌐 Dominio : ${C}$DOMAIN${N}"
echo -e " 📡 Puertos : ${C}${PORTS}${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${M}[1]${N} Iniciar / Reiniciar Proxy"
echo -e " ${M}[2]${N} Agregar Puerto"
echo -e " ${M}[3]${N} Reset Total"
echo -e " ${M}[4]${N} Ver Logs"
echo -e " ${R}[0] Salir${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op

case $op in

1)
install_proxy
;;

2)
read -p "➤ Nuevo puerto: " P

if ! [[ "$P" =~ ^[0-9]+$ ]]; then
    echo -e "${R}Puerto inválido${N}"
    sleep 2
    continue
fi

if grep -qw "$P" $PORT_FILE 2>/dev/null; then
    echo -e "${Y}Ya existe${N}"
    sleep 2
    continue
fi

echo "$P" >> $PORT_FILE
PORTS=$(cat $PORT_FILE | xargs)

echo -e "${G}✔ Puerto agregado${N}"
sleep 1
;;

3)
reset_all
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