#!/bin/bash

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

# IP
IP=$(curl -s ifconfig.me)

# Fecha
FECHA=$(date "+%d/%m/%Y-%H:%M")

# RAM
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
USED_RAM=$(free -m | awk '/Mem:/ {print $3}')
RAM_PERC=$(free | awk '/Mem:/ {printf("%.2f"), $3/$2 * 100}')

# CPU
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

# Función puerto real
check_port() {
  ss -tuln | grep -q ":$1 " && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

# SSH
SSH_PORTS=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
SSH_STATUS=$(systemctl is-active ssh 2>/dev/null)

if [ "$SSH_STATUS" = "active" ]; then
  SSH_STATE="${G}[ON]${N}"
else
  SSH_STATE="${R}[OFF]${N}"
fi

# DNS (puerto 53)
DNS_STATE=$(check_port 53)

# HTTP
HTTP_STATE=$(check_port 80)

# HTTPS
HTTPS_STATE=$(check_port 443)

# BadVPN (proceso real)
if pgrep -f badvpn >/dev/null; then
  BADVPN_STATE="${G}[ON]${N}"
else
  BADVPN_STATE="${R}[OFF]${N}"
fi

while true; do
clear

echo -e "${C}════════════════════════════════════════════════════${N}"
echo -e "${W}🔥 SCRIPT KIRA - PANEL VPS 🔥${N}"
echo -e "${C}════════════════════════════════════════════════════${N}"

echo -e " ${W}IP:${N} $IP   ${W}FECHA:${N} $FECHA"

echo -e "${C}════════════════════════════════════════════════════${N}"

# SSH real
echo -e " ${W}SSH:${N} $SSH_STATE"
echo -ne " ${W}Puertos SSH:${N} "
if [ -n "$SSH_PORTS" ]; then
  for p in $SSH_PORTS; do
    echo -ne "$p "
  done
  echo ""
else
  echo "Ninguno"
fi

# Servicios reales
echo -e " ${W}System-DNS (53):${N} $DNS_STATE"
echo -e " ${W}HTTP (80):${N} $HTTP_STATE"
echo -e " ${W}HTTPS (443):${N} $HTTPS_STATE"
echo -e " ${W}BadVPN:${N} $BADVPN_STATE"

echo -e "${C}════════════════════════════════════════════════════${N}"

echo -e " ${W}RAM:${N} ${USED_RAM}MB / ${TOTAL_RAM}MB (${RAM_PERC}%)"
echo -e " ${W}CPU:${N} ${CPU}%"

echo -e "${C}════════════════════════════════════════════════════${N}"

echo -e "${W}[01]${N} CONTROL USUARIOS"
echo -e "${W}[02]${N} OPTIMIZAR VPS"
echo -e "${W}[03]${N} USUARIOS ONLINE"
echo -e "${W}[04]${N} AUTO INICIO"
echo -e "${W}[05]${N} INSTALADOR DE PROTOCOLOS"

echo -e "${C}════════════════════════════════════════════════════${N}"
echo -e "${R}[0] SALIR${N}"
echo -e "${C}════════════════════════════════════════════════════${N}"

read -p "➤ Opcion: " op

case $op in

5|05)
  bash modules/protocols.sh
  ;;

0)
  exit
  ;;

*)
  echo -e "${R}Opcion invalida${N}"
  sleep 1
  ;;

esac

done