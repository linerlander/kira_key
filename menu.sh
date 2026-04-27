#!/bin/bash

# 🎨 COLORES PRO
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[38;5;255m'
D='\033[38;5;240m'
N='\033[0m'

# IP
IP=$(curl -s ifconfig.me)

# Fecha
FECHA=$(date "+%d/%m/%Y-%H:%M")

# RAM
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
USED_RAM=$(free -m | awk '/Mem:/ {print $3}')
RAM_PERC=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')

# CPU
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')

# 🔥 BARRA PRO DINÁMICA
bar() {
  local percent=$1
  local size=20
  local filled=$((percent * size / 100))
  local empty=$((size - filled))

  # color dinámico
  if [ $percent -lt 50 ]; then
    COLOR=$G
  elif [ $percent -lt 80 ]; then
    COLOR=$Y
  else
    COLOR=$R
  fi

  printf "$COLOR"
  printf "%0.s█" $(seq 1 $filled)

  printf "$D"
  printf "%0.s░" $(seq 1 $empty)

  printf "$N"
}

# CHECK PORT
check_port() {
  ss -tuln | grep -q ":$1 " && echo -e "${G}● ON${N}" || echo -e "${R}● OFF${N}"
}

# SSH
SSH_PORTS=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
SSH_STATUS=$(systemctl is-active ssh 2>/dev/null)

[ "$SSH_STATUS" = "active" ] && SSH_STATE="${G}● ON${N}" || SSH_STATE="${R}● OFF${N}"

# Servicios
DNS_STATE=$(check_port 53)
HTTP_STATE=$(check_port 80)
HTTPS_STATE=$(check_port 443)

# BadVPN
pgrep -f badvpn >/dev/null && BADVPN_STATE="${G}● ON${N}" || BADVPN_STATE="${R}● OFF${N}"

while true; do
clear

# 🔥 BANNER KIRA (NO TOCADO)
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}IP:${N} ${W}$IP${N}    ${Y}FECHA:${N} ${W}$FECHA${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔌 PANEL SERVICIOS
printf " ${W}SSH:${N} %b " "$SSH_STATE"
for p in $SSH_PORTS; do
  printf "${C}%s${N} " "$p"
done
printf "   ${W}DNS(53):${N} %b\n" "$DNS_STATE"

printf " ${W}HTTP(80):${N} %b      ${W}HTTPS(443):${N} %b\n" "$HTTP_STATE" "$HTTPS_STATE"
printf " ${W}BadVPN:${N} %b\n" "$BADVPN_STATE"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 BARRAS PRO
printf " ${Y}RAM:${N} "
bar $RAM_PERC
printf " ${W}%3s%%${N}\n" "$RAM_PERC"

printf " ${Y}CPU:${N} "
bar $CPU
printf " ${W}%3s%%${N}\n" "$CPU"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🎛️ MENU
echo -e " ${G}[01]${N} ${W}CONTROL USUARIOS${N}"
echo -e " ${G}[02]${N} ${W}OPTIMIZAR VPS${N}"
echo -e " ${G}[03]${N} ${W}USUARIOS ONLINE${N}"
echo -e " ${G}[04]${N} ${W}AUTO INICIO${N}"
echo -e " ${G}[05]${N} ${W}INSTALADOR DE PROTOCOLOS${N}"
echo -e " ${G}[06]${N} ${W}MONITOR EN TIEMPO REAL${N}"
echo -e " ${G}[07]${N} ${W}ACTUALIZAR SCRIPT${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] SALIR${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op

case $op in

1|01)
  bash modules/user.sh
  ;;

5|05)
  bash modules/protocols.sh
  ;;

6|06)
  bash monitor.sh
  ;;

7|07)
  bash modules/update.sh
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