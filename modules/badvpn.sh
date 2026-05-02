#!/bin/bash

# 🎨 COLORES PRO
G='\033[38;5;82m'
R='\033[38;5;203m'
Y='\033[38;5;220m'
C='\033[38;5;45m'
W='\033[1;37m'
D='\033[38;5;240m'
N='\033[0m'

SERVICE="kira-badvpn"
BIN="/usr/local/bin/badvpn-udpgw"
PORT_FILE="/etc/kira/badvpn_ports"

mkdir -p /etc/kira

# ===== ESTADO =====
status_badvpn() {
    pgrep -f badvpn-udpgw >/dev/null && echo -e "${G}● ACTIVO${N}" || echo -e "${R}● DETENIDO${N}"
}

# ===== LEER PUERTOS =====
get_ports() {
    [ -f "$PORT_FILE" ] && cat "$PORT_FILE" || echo "7100 7200 7300"
}

# ===== GENERAR SERVICIO =====
generate_service() {

PORTS=$(get_ports)

CMD=""
for p in $PORTS; do
    CMD+="--listen-addr 127.0.0.1:$p "
done

cat > /etc/systemd/system/${SERVICE}.service <<EOF
[Unit]
Description=KIRA BadVPN PRO
After=network.target

[Service]
ExecStart=$BIN $CMD --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart $SERVICE
}

# ===== INSTALAR =====
install_badvpn() {

echo -e "${Y}⚙️ Instalando BadVPN (modo PRO)...${N}"

apt update -y
apt install -y build-essential cmake git >/dev/null 2>&1

cd /root
rm -rf badvpn
git clone https://github.com/ambrop72/badvpn.git >/dev/null 2>&1

cd badvpn
mkdir build && cd build

cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null
make install >/dev/null 2>&1

if [ ! -f "$BIN" ]; then
    echo -e "${R}✖ Error al compilar BadVPN${N}"
    return
fi

# puertos por defecto
echo "7100 7200 7300" > $PORT_FILE

generate_service

systemctl enable $SERVICE >/dev/null 2>&1

sleep 2

echo -e "${G}✔ BadVPN instalado correctamente${N}"
}

# ===== AGREGAR PUERTO =====
add_port() {
read -p "➤ Nuevo puerto: " NEWPORT

if ss -tuln | grep -q ":$NEWPORT "; then
    echo -e "${R}✖ Puerto ocupado${N}"
    return
fi

PORTS=$(get_ports)

if echo "$PORTS" | grep -w "$NEWPORT" >/dev/null; then
    echo -e "${Y}⚠️ Ya existe ese puerto${N}"
    return
fi

echo "$PORTS $NEWPORT" > $PORT_FILE

generate_service

echo -e "${G}✔ Puerto agregado${N}"
}

# ===== ELIMINAR PUERTO =====
del_port() {
PORTS=$(get_ports)

echo -e "${Y}Puertos actuales:${N} ${W}$PORTS${N}"
read -p "➤ Puerto a eliminar: " DEL

NEW=$(echo $PORTS | sed "s/\b$DEL\b//g")

echo "$NEW" > $PORT_FILE

generate_service

echo -e "${R}✔ Puerto eliminado${N}"
}

# ===== DETENER =====
stop_badvpn() {
systemctl stop $SERVICE
echo -e "${R}✔ BadVPN detenido${N}"
}

# ===== MENU =====
while true; do
clear

STATE=$(status_badvpn)
PORTS=$(get_ports)

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}🚀 BADVPN UDP PRO - KIRA${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${C}Estado:${N} $STATE"
echo -e " ${C}Puertos:${N} ${W}$PORTS${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# INFO PRO
echo -e "${W}📡 Uso recomendado:${N}"
echo -e " ${G}7100${N} ➜ 🎮 Juegos (FreeFire, PUBG)"
echo -e " ${G}7200${N} ➜ 📱 HTTP Injector / KPN"
echo -e " ${G}7300${N} ➜ 🌐 DNS / tráfico general"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[1]${N} ⚙️ Instalar / Reinstalar"
echo -e " ${W}[2]${N} ➕ Añadir puerto"
echo -e " ${W}[3]${N} ➖ Eliminar puerto"
echo -e " ${W}[4]${N} 🔄 Reiniciar"
echo -e " ${W}[5]${N} ⛔ Detener"
echo -e " ${W}[0]${N} 🔙 Volver"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)
install_badvpn
read -p "Enter..."
;;

2)
add_port
sleep 2
;;

3)
del_port
sleep 2
;;

4)
generate_service
echo -e "${G}✔ Reiniciado${N}"
sleep 2
;;

5)
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