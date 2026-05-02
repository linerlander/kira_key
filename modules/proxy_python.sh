#!/bin/bash

# ===== COLORES PRO =====
R='\033[1;91m'   # rojo fuerte
G='\033[1;92m'   # verde fuerte
Y='\033[1;93m'
M='\033[1;95m'
C='\033[1;96m'
W='\033[1;97m'
D='\033[38;5;240m'
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
[ -z "$MODE" ] && MODE="none"
[ -z "$BANNER" ] && BANNER="KIRA"

# ===== LIMPIAR PUERTOS =====
valid_ports() {
    CLEAN=""
    for p in $PORTS; do
        [[ "$p" =~ ^[0-9]+$ ]] && CLEAN="$CLEAN $p"
    done
    PORTS=$(echo $CLEAN | tr ' ' '\n' | sort -u | xargs)
}

# ===== STATUS LIMPIO =====
mode_status() {
    if systemctl is-active --quiet proxy-python && [ "$MODE" = "$1" ]; then
        echo -e "${G}[ON]${N}"
    else
        echo -e "${R}[OFF]${N}"
    fi
}

# ===== INSTALAR PROXY =====
install_proxy() {

valid_ports

# eliminar puertos ocupados
FINAL_PORTS=""
for p in $PORTS; do
    if ! ss -tuln | grep -q ":$p "; then
        FINAL_PORTS="$FINAL_PORTS $p"
    fi
done

PORTS=$(echo $FINAL_PORTS | xargs)

cat > /usr/local/bin/proxy.py <<EOF
import socket, threading

PORTS = [${PORTS// /,}]
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
            res = f"HTTP/1.1 200 OK\\r\\nServer: {BANNER}\\r\\n\\r\\n"
            c.send(res.encode())

        while True:
            c.recv(4096)
    except:
        pass
    c.close()

def start(port):
    try:
        s = socket.socket()
        s.bind(("0.0.0.0", port))
        s.listen(200)
        while True:
            c, _ = s.accept()
            threading.Thread(target=handle, args=(c,)).start()
    except:
        pass

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

# ===== AUTO CONFIG =====
auto_mode() {
echo "ws" > $MODE_FILE
echo "80 8080" > $PORT_FILE

[ ! -f "$CONFIG" ] && read -p "🌐 Dominio: " DOMAIN && echo "$DOMAIN" > $CONFIG

echo -e "${G}✔ Configuración automática lista${N}"
sleep 2
}

# ===== MENU =====
while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "  ${W}⚜️ PROXY PYTHON KIRA ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " 🌐 ${C}Dominio${N} : ${W}$DOMAIN${N}"
echo -e " 📡 ${C}Puertos${N} : ${W}${PORTS:---}${N}"
echo -e " 🏷️ ${C}Banner${N}  : ${W}$BANNER${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${M}[1]${N} SIMPLE        $(mode_status simple)"
echo -e " ${M}[2]${N} SEGURO        $(mode_status secure)"
echo -e " ${M}[3]${N} WS 🔥         $(mode_status ws)"
echo -e " ${M}[4]${N} DEBUG"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${M}[5]${N} Cambiar Banner"
echo -e " ${M}[6]${N} Agregar Puerto"
echo -e " ${M}[7]${N} Resetear Todo"
echo -e " ${M}[8]${N} AUTO CONFIG"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] SALIR${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${D}💡 Usa WS + puerto 80 para mejor compatibilidad${N}"
echo -e "${D}💡 Alternativos: 8080 / 8888${N}"

read -p "➤ Opcion: " op

case $op in

1)
echo "simple" > $MODE_FILE
MODE="simple"
install_proxy
;;

2)
echo "secure" > $MODE_FILE
MODE="secure"
install_proxy
;;

3)
echo "ws" > $MODE_FILE
MODE="ws"
install_proxy
;;

4)
screen -dmS kira-proxy python3 /usr/local/bin/proxy.py
echo -e "${C}✔ DEBUG activo${N}"
sleep 2
;;

5)
read -p "Nuevo banner: " BANNER
echo "$BANNER" > $BANNER_FILE
;;

6)
read -p "➤ Puerto: " NEWPORT

if ! [[ "$NEWPORT" =~ ^[0-9]+$ ]]; then
    echo -e "${R}✖ Puerto inválido${N}"
    sleep 2
    continue
fi

if grep -qw "$NEWPORT" $PORT_FILE 2>/dev/null; then
    echo -e "${Y}⚠ Ya existe${N}"
    sleep 2
    continue
fi

if ss -tuln | grep -q ":$NEWPORT "; then
    echo -e "${R}✖ Puerto ocupado${N}"
    sleep 2
    continue
fi

echo "$NEWPORT" >> $PORT_FILE
echo -e "${G}✔ Puerto agregado${N}"
sleep 1
;;

7)
> $PORT_FILE
systemctl stop proxy-python
pkill -f proxy.py
echo -e "${R}✔ Reset completo${N}"
sleep 2
;;

8)
auto_mode
;;

0) break ;;

*)
echo -e "${R}Opcion invalida${N}"
sleep 1
;;

esac

[ ! -f "$CONFIG" ] && read -p "Dominio: " DOMAIN && echo "$DOMAIN" > $CONFIG

PORTS=$(cat $PORT_FILE | xargs)

done