#!/bin/bash

# ===== COLORES =====
G='\033[38;5;46m'
R='\033[38;5;196m'
Y='\033[38;5;226m'
W='\033[1;37m'
D='\033[38;5;240m'
N='\033[0m'

SERVICE="kira-badvpn"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"
BIN="/usr/bin/badvpn-udpgw"

# ===== ESTADO =====
status_badvpn() {
    if pgrep -f badvpn-udpgw >/dev/null; then
        echo -e "${G}[ON]${N}"
    else
        echo -e "${R}[OFF]${N}"
    fi
}

# ===== PUERTOS ACTIVOS =====
ports_active() {
    ss -tuln | grep -E '7100|7200|7300' | awk '{print $5}' | cut -d: -f2 | xargs
}

# ===== INSTALAR =====
install_badvpn() {

echo -e "${Y}Instalando BadVPN...${N}"

# limpiar viejo
rm -f $BIN

# descarga (doble método)
wget -qO $BIN https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw \
|| curl -L -o $BIN https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw

# validar descarga
if [ ! -f "$BIN" ]; then
    echo -e "${R}✖ Error descargando BadVPN (bloqueo GitHub)${N}"
    return
fi

chmod +x $BIN

# validar ejecutable
if ! $BIN --help >/dev/null 2>&1; then
    echo -e "${R}✖ Binario inválido o incompatible${N}"
    return
fi

# verificar puertos
for p in 7100 7200 7300; do
    if ss -tuln | grep -q ":$p "; then
        echo -e "${R}✖ Puerto $p en uso${N}"
        return
    fi
done

# crear servicio
cat > $SERVICE_FILE <<EOF
[Unit]
Description=KIRA BadVPN UDPGW
After=network.target

[Service]
ExecStart=$BIN --listen-addr 127.0.0.1:7100 --listen-addr 127.0.0.1:7200 --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable $SERVICE >/dev/null 2>&1
systemctl restart $SERVICE

sleep 2

# verificar
if pgrep -f badvpn-udpgw >/dev/null; then
    echo -e "${G}✔ BadVPN ACTIVO${N}"
else
    echo -e "${R}✖ Error al iniciar BadVPN${N}"
    echo -e "${Y}Detalle:${N}"
    systemctl status $SERVICE --no-pager
fi
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
PORTS=$(ports_active)
[ -z "$PORTS" ] && PORTS="--"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}      ADMINISTRADOR BADVPN UDP - KIRA${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " Estado           : $STATE"
echo -e " Puertos activos  : ${W}$PORTS${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 📚 EXPLICACION
echo -e "${W} Uso de puertos:${N}"
echo -e " ${G}7100${N} ➜ Juegos (FreeFire, PUBG, etc)"
echo -e " ${G}7200${N} ➜ Apps VPN (HTTP Injector, KPN)"
echo -e " ${G}7300${N} ➜ DNS / UDP general"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[1]${N} ➤ INSTALAR / REINICIAR"
echo -e " ${W}[2]${N} ➤ DETENER"
echo -e " ${W}[0]${N} ➤ VOLVER"

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