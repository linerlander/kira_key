#!/bin/bash

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

status() {
  systemctl is-active --quiet $1 && echo "${G}[ON]${N}" || echo "${R}[OFF]${N}"
}

while true; do
clear

echo -e "${Y}══════════════════════════════════════════════════════════════${N}"
echo -e " 🍄 ${W}INSTALACION DE PROTOCOLOS${Y} ( KIRA ) 🍄${N}"
echo -e "${Y}══════════════════════════════════════════════════════════════${N}"

echo -e "${W}[01]${N} OpenSSH        $(status ssh)        ${W}[11]${N} Psiphon Server   ${R}[OFF]${N}"
echo -e "${W}[02]${N} Dropbear       $(status dropbear)   ${W}[12]${N} TCP DNS          ${Y}[BETA]${N}"
echo -e "${W}[03]${N} OpenVPN        ${R}[OFF]${N}        ${W}[13]${N} Webmin           ${R}[OFF]${N}"
echo -e "${W}[04]${N} SSL/TLS        ${R}[OFF]${N}        ${W}[14]${N} SlowDNS          ${R}[OFF]${N}"
echo -e "${W}[05]${N} Shadowsocks    ${R}[OFF]${N}        ${W}[15]${N} SSL→Python       ${R}[OFF]${N}"
echo -e "${W}[06]${N} Squid Proxy    $(status squid)     ${W}[16]${N} SSH Multiplex    ${R}[OFF]${N}"
echo -e "${W}[07]${N} Proxy Python   ${Y}[PyD]${N}        ${W}[17]${N} Over WebSocket   ${Y}[BETA]${N}"
echo -e "${W}[08]${N} V2Ray Switch   ${R}[OFF]${N}        ${W}[18]${N} SOCKS5           ${R}[OFF]${N}"
echo -e "${W}[09]${N} CEA (Clash)    ${R}[OFF]${N}        ${W}[19]${N} Protocolos UDP   ${R}[OFF]${N}"
echo -e "${W}[10]${N} Trojan-Go      ${R}[OFF]${N}        ${W}[20]${N} Funciones        ${Y}[DEV]${N}"

echo -e "${Y}══════════════════════════════════════════════════════════════${N}"

echo -e " 🍄 ${W}HERRAMIENTAS Y SERVICIOS${N} 🍄"
echo -e "${Y}══════════════════════════════════════════════════════════════${N}"

echo -e "${W}[21]${N} Block Torrent      ${R}[OFF]${N}     ${W}[22]${N} BadVPN          ${G}[ON]${N}"
echo -e "${W}[23]${N} TCP BBR           ${R}[OFF]${N}     ${W}[24]${N} Fail2Ban        ${R}[OFF]${N}"
echo -e "${W}[25]${N} Archivo Online    ${G}[443]${N}     ${W}[26]${N} SpeedTest       ${W}[RUN]${N}"
echo -e "${W}[27]${N} Detalles VPS      ${W}[INFO]${N}    ${W}[28]${N} Block Ads       ${R}[OFF]${N}"
echo -e "${W}[29]${N} DNS Netflix       ${R}[OFF]${N}     ${W}[30]${N} Herramientas    ${W}[EXTRA]${N}"
echo -e "${W}[31]${N} Reiniciar Servicios           ${W}[32]${N} Brook Server    ${R}[OFF]${N}"
echo -e "${W}[33]${N} Firewall (iptables)           ${W}[34]${N} Cambiar Passwd  ${W}[ROOT]${N}"
echo -e "${W}[35]${N} AToken Mods"

echo -e "${Y}══════════════════════════════════════════════════════════════${N}"
echo -e "${R}[0] REGRESAR${N}"
echo -e "${Y}══════════════════════════════════════════════════════════════${N}"

read -p "➤ Opcion: " op

case $op in

1|01)
  apt install openssh-server -y
  systemctl restart ssh
  ;;

2|02)
  apt install dropbear -y
  systemctl restart dropbear
  ;;

6|06)
  apt install squid -y
  systemctl restart squid
  ;;

22)
  echo "BadVPN activo (manual)"
  ;;

31)
  systemctl restart ssh 2>/dev/null
  systemctl restart squid 2>/dev/null
  systemctl restart dropbear 2>/dev/null
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