#!/bin/bash

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
M='\033[1;35m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

check_port () {
  ss -tuln | grep -q ":$1 " && echo "${G}ON${N}" || echo "${R}OFF${N}"
}

while true; do
clear

IP=$(curl -s ifconfig.me)
RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
DATE=$(date "+%d/%m/%Y-%H:%M")

SSH_STATUS=$(check_port 22)
HTTP_STATUS=$(check_port 80)
HTTPS_STATUS=$(check_port 443)

echo -e "${M}"
echo "   ██╗  ██╗██╗██████╗  █████╗ "
echo "   ██║ ██╔╝██║██╔══██╗██╔══██╗"
echo "   █████╔╝ ██║██████╔╝███████║"
echo "   ██╔═██╗ ██║██╔══██╗██╔══██║"
echo "   ██║  ██╗██║██║  ██║██║  ██║"
echo "   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${N}"

echo -e "${Y}════════════════════════════════════════════════════${N}"

echo -e "${C}• ${W}IP:${G} $IP   ${C}• ${W}FECHA:${Y} $DATE${N}"
echo -e "${C}• ${W}RAM:${G} $RAM   ${C}• ${W}CPU:${R} $CPU${N}"

echo -e "${Y}════════════════════════════════════════════════════${N}"

echo -e "${C}• ${W}SSH:${SSH_STATUS}   ${C}• ${W}HTTP:${HTTP_STATUS}   ${C}• ${W}HTTPS:${HTTPS_STATUS}${N}"

echo -e "${Y}════════════════════════════════════════════════════${N}"

echo -e "${Y}[01]${N} ${W}CONTROL USUARIOS"
echo -e "${Y}[02]${N} ${W}OPTIMIZAR VPS ${R}[OFF]${N}"
echo -e "${Y}[03]${N} ${W}VER USUARIOS ONLINE ${G}[ON]${N}"
echo -e "${Y}[04]${N} ${W}VER PROCESOS ACTIVOS"
echo -e "${Y}[05]${N} ${W}VER USO DE DISCO"
echo -e "${Y}[07]${N} ${W}MONITOR EN TIEMPO REAL"
echo -e "${Y}[08]${N} ${W}INSTALAR PROTOCOLOS"

echo ""
echo -e "${Y}[06]${N} ${W}UPDATE SCRIPT"
echo -e "${R}[00]${N} ${W}SALIR"

echo -e "${Y}════════════════════════════════════════════════════${N}"

read -p "➤ Opcion: " op

case $op in

01|1)
  echo -e "${G}Modulo de usuarios (proximamente)${N}"
  read -p "ENTER..."
  ;;

02|2)
  echo -e "${Y}Optimizando VPS...${N}"
  read -p "ENTER..."
  ;;

03|3)
  echo -e "${C}Usuarios conectados:${N}"
  who
  read -p "ENTER..."
  ;;

04|4)
  echo -e "${C}Procesos activos:${N}"
  top
  ;;

05|5)
  echo -e "${C}Uso de disco:${N}"
  df -h
  read -p "ENTER..."
  ;;

07|7)
  bash monitor.sh
  ;;

08|8)
  bash modules/protocols.sh
  ;;

06)
  echo -e "${Y}Actualizando script...${N}"
  git pull
  read -p "ENTER..."
  ;;

00|0)
  exit
  ;;

*)
  echo -e "${R}Opcion invalida${N}"
  sleep 1
  ;;

esac

done