#!/bin/bash

# 🎨 COLORES PRO (neón estilo hacker)
R='\033[38;5;196m'   # rojo fuerte
G='\033[38;5;46m'    # verde neón
Y='\033[38;5;226m'   # amarillo brillante
C='\033[38;5;51m'    # cyan
W='\033[38;5;255m'   # blanco limpio
D='\033[38;5;240m'   # gris suave
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
  ss -tuln | grep -q ":$1 " && echo -e "${G}● ON${N}" || echo -e "${R}● OFF${N}"
}

# SSH
SSH_PORTS=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
SSH_STATUS=$(systemctl is-active ssh 2>/dev/null)

[ "$SSH_STATUS" = "active" ] && SSH_STATE="${G}● ON${N}" || SSH_STATE="${R}● OFF${N}"

# Puertos SSH en una línea
SSH_LIST=""
for p in $SSH_PORTS; do
  SSH_LIST+="${C}$p${N} "
done

# Servicios reales
DNS_STATE=$(check_port 53)
HTTP_STATE=$(check_port 80)
HTTPS_STATE=$(check_port 443)

# BadVPN
pgrep -f badvpn >/dev/null && BADVPN_STATE="${G}● ON${N}" || BADVPN_STATE="${R}● OFF${N}"

while true; do
clear

# Banner KIRA (NO TOCADO)
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}IP:${N} ${W}$IP${N}    ${Y}FECHA:${N} ${W}$FECHA${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# PANEL PRO (ALINEADO)
printf " ${W}SSH:${N} %b ${C}%-12s${N}   ${W}DNS(53):${N} %b\n" "$SSH_STATE" "$SSH_LIST" "$DNS_STATE"
printf " ${W}HTTP(80):${N} %b      ${W}HTTPS(443):${N} %b\n" "$HTTP_STATE" "$HTTPS_STATE"
printf " ${W}BadVPN:${N} %b\n" "$BADVPN_STATE"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${Y}RAM:${N} ${W}${USED_RAM}/${TOTAL_RAM}MB${N} (${G}${RAM_PERC}%${N})   ${Y}CPU:${N} ${G}${CPU}%${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# MENU (MEJOR COLOR)
echo -e " ${G}[01]${N} ${W}CONTROL USUARIOS${N}"
echo -e " ${G}[02]${N} ${W}OPTIMIZAR VPS${N}"
echo -e " ${G}[03]${N} ${W}USUARIOS ONLINE${N}"
echo -e " ${G}[04]${N} ${W}AUTO INICIO${N}"
echo -e " ${G}[05]${N} ${W}INSTALADOR DE PROTOCOLOS${N}"
echo -e " ${G}[06]${N} ${W}MONITOR EN TIEMPO REAL${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] SALIR${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

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