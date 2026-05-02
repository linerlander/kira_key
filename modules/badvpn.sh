#!/bin/bash

G='\033[38;5;46m'
R='\033[38;5;196m'
Y='\033[38;5;226m'
W='\033[1;37m'
D='\033[38;5;240m'
N='\033[0m'

SERVICE="kira-badvpn"
BIN="/usr/local/bin/badvpn-udpgw"

status_badvpn() {
    pgrep -f badvpn-udpgw >/dev/null && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

ports_active() {
    ss -tuln | grep -E '7100|7200|7300' | awk '{print $5}' | cut -d: -f2 | xargs
}

# ===== INSTALAR DESDE SOURCE =====
install_badvpn() {

echo -e "${Y}Instalando BadVPN (compilando)...${N}"

apt update -y
apt install -y build-essential cmake git

cd /root
rm -rf badvpn
git clone https://github.com/ambrop72/badvpn.git

cd badvpn
mkdir build
cd build

cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make install

# verificar binario
if [ ! -f "$BIN" ]; then
    echo -e "${R}✖ Error compilando BadVPN${N}"
    return
fi

# crear servicio
cat > /etc/systemd/system/kira-badvpn.service <<EOF
[Unit]
Description=KIRA BadVPN UDPGW
After=network.target

[Service]
ExecStart=$BIN --listen-addr 127.0.0.1:7100 --listen-addr 127.0.0.1:7200 --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-badvpn
systemctl restart kira-badvpn

sleep 2

if pgrep -f badvpn-udpgw >/dev/null; then
    echo -e "${G}✔ BadVPN ACTIVO${N}"
else
    echo -e "${R}✖ Error al iniciar${N}"
    systemctl status kira-badvpn --no-pager
fi
}

stop_badvpn() {
systemctl stop kira-badvpn
echo -e "${R}✔ BadVPN detenido${N}"
}

# ===== MENU =====
while true; do
clear

STATE=$(status_badvpn)
PORTS=$(ports_active)
[ -z "$PORTS" ] && PORTS="--"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}      BADVPN UDP KIRA (COMPILADO)${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " Estado  : $STATE"
echo -e " Puertos : ${W}$PORTS${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${W} Puertos:${N}"
echo -e " ${G}7100${N} ➜ Juegos"
echo -e " ${G}7200${N} ➜ HTTP Injector"
echo -e " ${G}7300${N} ➜ DNS/UDP"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[1]${N} Instalar (compilar)"
echo -e " ${W}[2]${N} Detener"
echo -e " ${W}[0]${N} Volver"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)
install_badvpn
read -p "Enter..."
;;

2)
stop_badvpn
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