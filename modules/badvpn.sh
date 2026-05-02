#!/bin/bash

# 🎨 COLORES
G='\033[38;5;46m'
R='\033[38;5;196m'
Y='\033[38;5;226m'
W='\033[1;37m'
N='\033[0m'

SERVICE="/etc/systemd/system/kira-badvpn.service"

# ===== DETECTAR ESTADO =====
status_badvpn() {
    if pgrep -f badvpn-udpgw >/dev/null; then
        echo -e "${G}[ON]${N}"
    else
        echo -e "${R}[OFF]${N}"
    fi
}

# ===== MOSTRAR PUERTOS ACTIVOS =====
ports_active() {
    ss -tuln | grep -E '7100|7200|7300' | awk '{print $5}' | cut -d: -f2 | xargs
}

# ===== INSTALAR BADVPN =====
install_badvpn() {

echo -e "${Y}Instalando BadVPN...${N}"

# Descargar binario (evita bloqueo usando curl fallback)
curl -L -o /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw 2>/dev/null

if [ ! -f /usr/bin/badvpn-udpgw ]; then
    echo -e "${R}✖ Error descargando BadVPN (GitHub bloqueado)${N}"
    return
fi

chmod +x /usr/bin/badvpn-udpgw

# Crear servicio MULTI PUERTO
cat > $SERVICE <<EOF
[Unit]
Description=KIRA BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw \
--listen-addr 127.0.0.1:7100 \
--listen-addr 127.0.0.1:7200 \
--listen-addr 127.0.0.1:7300 \
--max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kira-badvpn
systemctl restart kira-badvpn

sleep 2

if pgrep -f badvpn-udpgw >/dev/null; then
    echo -e "${G}✔ BadVPN instalado y activo${N}"
else
    echo -e "${R}✖ Error al iniciar BadVPN${N}"
fi

}

# ===== DETENER =====
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
echo -e " ${W} ADMINISTRADOR BADVPN UDP - KIRA${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " Estado : $STATE"
echo -e " Puertos activos : ${W}$PORTS${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 📚 EXPLICACIÓN PRO
echo -e "${W} ¿PARA QUE SIRVEN LOS PUERTOS?${N}"
echo -e " ${G}7100${N} ➜ Juegos (FreeFire, PUBG, etc)"
echo -e " ${G}7200${N} ➜ Apps VPN (HTTP Injector, KPN)"
echo -e " ${G}7300${N} ➜ DNS / tráfico general UDP"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[1]${N} ➤ INSTALAR / REINICIAR BADVPN"
echo -e " ${W}[2]${N} ➤ DETENER BADVPN"
echo -e " ${W}[0]${N} ➤ VOLVER"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)
install_badvpn
sleep 2
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