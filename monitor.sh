#!/bin/bash

G='\033[1;32m'
Y='\033[1;33m'
R='\033[1;31m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

bar() {
  percent=$1
  size=20
  filled=$((percent*size/100))
  empty=$((size-filled))

  printf "["
  for ((i=0;i<filled;i++)); do printf "#"; done
  for ((i=0;i<empty;i++)); do printf "-"; done
  printf "] %d%%" "$percent"
}

clear
tput civis

while true; do
tput cup 0 0

CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
CPU=$(printf "%.0f" "$(echo "100 - $CPU_IDLE" | bc)")

RAM_USED=$(free | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free | awk '/Mem:/ {print $2}')
RAM_P=$(awk "BEGIN {printf \"%d\", ($RAM_USED/$RAM_TOTAL)*100}")

RX1=$(cat /sys/class/net/eth0/statistics/rx_bytes)
TX1=$(cat /sys/class/net/eth0/statistics/tx_bytes)
sleep 1
RX2=$(cat /sys/class/net/eth0/statistics/rx_bytes)
TX2=$(cat /sys/class/net/eth0/statistics/tx_bytes)

RX_RATE=$(( (RX2-RX1)/1024 ))
TX_RATE=$(( (TX2-TX1)/1024 ))

echo -e "${C}════════════════════════════════════════════${N}"
echo -e "${G}        MONITOR EN TIEMPO REAL${N}"
echo -e "${C}════════════════════════════════════════════${N}"

echo -ne "${W}CPU: ${R}"
bar $CPU
echo -e "${N}"

echo -ne "${W}RAM: ${Y}"
bar $RAM_P
echo -e "${N}"

echo -e "${W}RED ↓: ${G}${RX_RATE} KB/s  ${W}↑: ${G}${TX_RATE} KB/s${N}"

echo -e "${C}════════════════════════════════════════════${N}"

ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6

echo -e "${Y}CTRL + C para salir${N}"

done