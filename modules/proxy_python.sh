#!/bin/bash

CONFIG="/etc/kira/domain"

# ===== COLORES =====
G='\033[38;5;46m'
R='\033[38;5;196m'
Y='\033[38;5;220m'
W='\033[1;37m'
N='\033[0m'

# ===== ESTADO =====
check_status() {
    if systemctl is-active --quiet proxy-python; then
        STATUS="${G}[ON]${N}"
    else
        STATUS="${R}[OFF]${N}"
    fi
}

# ===== PUERTOS OCUPADOS =====
show_ports() {
    echo -e "${Y}Puertos en uso:${N}"
    ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -n | uniq | xargs
    echo ""
}

# ===== DOMINIO =====
get_domain() {
    if [ ! -f "$CONFIG" ]; then
        read -p "🌐 Dominio: " DOMAIN
        mkdir -p /etc/kira
        echo "$DOMAIN" > "$CONFIG"
    else
        DOMAIN=$(cat $CONFIG)
    fi
}

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
check_status

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}PROXY PYTHON KIRA${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " [1] ➤ ACTIVAR PROXY        $STATUS"
echo -e " [2] ➤ CAMBIAR PUERTO"
echo -e " [3] ➤ VER PUERTOS EN USO"
echo -e " [4] ➤ DETENER PROXY"
echo -e " [0] ➤ VOLVER"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion: " op

case $op in

1)
get_domain

read -p "📡 Puerto (default 80): " PORT
[ -z "$PORT" ] && PORT=80

# VALIDAR PUERTO LIBRE
if ss -tuln | grep -q ":$PORT "; then
    echo -e "${R}Puerto ocupado${N}"
    sleep 2
    continue
fi

install_proxy

echo -e "${G}✔ PROXY ACTIVO${N}"
echo -e "🌐 $DOMAIN:$PORT"

read -p "Enter..."
;;

2)
read -p "Nuevo puerto: " PORT
echo "$PORT" > /etc/kira/proxy_port
echo -e "${G}✔ Puerto guardado${N}"
sleep 2
;;

3)
show_ports
read -p "Enter..."
;;

4)
systemctl stop proxy-python
echo -e "${R}Proxy detenido${N}"
sleep 2
;;

0)
break
;;

*)
echo -e "${R}Opcion invalida${N}"
sleep 1
;;

esac
done