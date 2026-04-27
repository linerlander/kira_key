#!/bin/bash

# 🎨 COLORES PRO
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[38;5;255m'
D='\033[38;5;240m'
N='\033[0m'

status() {
  systemctl is-active --quiet $1 && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🍄 ${W}INSTALACION DE PROTOCOLOS${Y} ( KIRA ) 🍄${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 PROTOCOLOS (ALINEADO)
printf "${W}[01]${N} OpenSSH        %-12b   ${W}[11]${N} Psiphon Server   ${R}[OFF]${N}\n" "$(status ssh)"
printf "${W}[02]${N} Dropbear       %-12b   ${W}[12]${N} TCP DNS          ${Y}[BETA]${N}\n" "$(status dropbear)"
printf "${W}[03]${N} OpenVPN        ${R}[OFF]${N}        ${W}[13]${N} Webmin           ${R}[OFF]${N}\n"
printf "${W}[04]${N} SSL/TLS        ${R}[OFF]${N}        ${W}[14]${N} SlowDNS          ${R}[OFF]${N}\n"
printf "${W}[05]${N} Shadowsocks    ${R}[OFF]${N}        ${W}[15]${N} SSL→Python       ${R}[OFF]${N}\n"
printf "${W}[06]${N} Squid Proxy    %-12b   ${W}[16]${N} SSH Multiplex    ${R}[OFF]${N}\n" "$(status squid)"
printf "${W}[07]${N} Proxy Python   ${C}[PyD]${N}        ${W}[17]${N} Over WebSocket   ${Y}[BETA]${N}\n"
printf "${W}[08]${N} V2Ray Switch   ${R}[OFF]${N}        ${W}[18]${N} SOCKS5           ${R}[OFF]${N}\n"
printf "${W}[09]${N} CEA (Clash)    ${R}[OFF]${N}        ${W}[19]${N} Protocolos UDP   ${R}[OFF]${N}\n"
printf "${W}[10]${N} Trojan-Go      ${R}[OFF]${N}        ${W}[20]${N} Funciones        ${Y}[DEV]${N}\n"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " 🍄 ${W}HERRAMIENTAS Y SERVICIOS${N} 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 SERVICIOS (ALINEADO)
printf "${W}[21]${N} Block Torrent   ${R}[OFF]${N}     ${W}[22]${N} BadVPN        ${G}[ON]${N}\n"
printf "${W}[23]${N} TCP BBR         ${R}[OFF]${N}     ${W}[24]${N} Fail2Ban      ${R}[OFF]${N}\n"
printf "${W}[25]${N} Archivo Online  ${G}[443]${N}     ${W}[26]${N} SpeedTest     ${C}[RUN]${N}\n"
printf "${W}[27]${N} Detalles VPS    ${C}[INFO]${N}    ${W}[28]${N} Block Ads     ${R}[OFF]${N}\n"
printf "${W}[29]${N} DNS Netflix     ${R}[OFF]${N}     ${W}[30]${N} Herramientas  ${C}[EXTRA]${N}\n"
printf "${W}[31]${N} Reiniciar Serv. ${C}[SYS]${N}     ${W}[32]${N} Brook Server  ${R}[OFF]${N}\n"
printf "${W}[33]${N} Firewall        ${C}[IPT]${N}     ${W}[34]${N} Cambiar Pass  ${Y}[ROOT]${N}\n"
printf "${W}[35]${N} AToken Mods\n"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${R}[0] REGRESAR${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op

case $op in

1|01)
  bash modules/ssh.sh
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