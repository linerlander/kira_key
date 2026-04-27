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

# Funciones
check_port() {
  ss -tuln | grep -q ":$1 " && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

# SSH
SSH_PORTS=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
SSH_STATUS=$(systemctl is-active ssh 2>/dev/null)

[ "$SSH_STATUS" = "active" ] && SSH_STATE="${G}[ON]${N}" || SSH_STATE="${R}[OFF]${N}"

# Puertos SSH en una línea
SSH_LIST=""
for p in $SSH_PORTS; do
  SSH_LIST+="$p "
done

# Servicios reales
DNS_STATE=$(check_port 53)
HTTP_STATE=$(check_port 80)
HTTPS_STATE=$(check_port 443)

# BadVPN
pgrep -f badvpn >/dev/null && BADVPN_STATE="${G}[ON]${N}" || BADVPN_STATE="${R}[OFF]${N}"

while true; do
clear

# Banner KIRA estilo hacker 🇵🇪
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${Y}════════════════════════════════════════════════════${N}"
echo -e " ${W}IP:${N} $IP    ${W}FECHA:${N} $FECHA"
echo -e "${Y}════════════════════════════════════════════════════${N}"

# LINEA PRINCIPAL (tipo panel pro)
printf " SSH: %b %-10s   System-DNS: %b\n" "$SSH_STATE" "$SSH_LIST" "$DNS_STATE"
printf " HTTP: %b        HTTPS: %b\n" "$HTTP_STATE" "$HTTPS_STATE"
printf " BadVPN: %b\n" "$BADVPN_STATE"

echo -e "${Y}════════════════════════════════════════════════════${N}"

echo -e " ${W}RAM:${N} ${USED_RAM}/${TOTAL_RAM}MB (${RAM_PERC}%)   ${W}CPU:${N} ${CPU}%"

echo -e "${Y}════════════════════════════════════════════════════${N}"

# MENU (manteniendo todo)
echo -e "${W}[01]${N} CONTROL USUARIOS"
echo -e "${W}[02]${N} OPTIMIZAR VPS"
echo -e "${W}[03]${N} USUARIOS ONLINE"
echo -e "${W}[04]${N} AUTO INICIO"
echo -e "${W}[05]${N} INSTALADOR DE PROTOCOLOS"
echo -e "${W}[06]${N} MONITOR EN TIEMPO REAL"

echo -e "${Y}════════════════════════════════════════════════════${N}"
echo -e "${R}[0] SALIR${N}"
echo -e "${Y}════════════════════════════════════════════════════${N}"

read -p "➤ Opcion: " op

case $op in

5|05)
  bash modules/protocols.sh
  ;;

6|06)
  bash monitor.sh
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