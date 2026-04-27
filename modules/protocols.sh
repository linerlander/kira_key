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
echo -e " 🍄 ${W}INSTALACION DE PROTOCOLOS${Y} ( KIRA ) 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 PROTOCOLOS (PERFECTAMENTE ALINEADO)
printf "${W}[01]${N} %-14s %-10b   ${W}[11]${N} %-16s %-8b\n" "OpenSSH" "$(status ssh)" "Psiphon Server" "${R}[OFF]${N}"
printf "${W}[02]${N} %-14s %-10b   ${W}[12]${N} %-16s %-8b\n" "Dropbear" "$(status dropbear)" "TCP DNS" "${Y}[BETA]${N}"
printf "${W}[03]${N} %-14s %-10b   ${W}[13]${N} %-16s %-8b\n" "OpenVPN" "${R}[OFF]${N}" "Webmin" "${R}[OFF]${N}"
printf "${W}[04]${N} %-14s %-10b   ${W}[14]${N} %-16s %-8b\n" "SSL/TLS" "${R}[OFF]${N}" "SlowDNS" "${R}[OFF]${N}"
printf "${W}[05]${N} %-14s %-10b   ${W}[15]${N} %-16s %-8b\n" "Shadowsocks" "${R}[OFF]${N}" "SSL→Python" "${R}[OFF]${N}"
printf "${W}[06]${N} %-14s %-10b   ${W}[16]${N} %-16s %-8b\n" "Squid Proxy" "$(status squid)" "SSH Multiplex" "${R}[OFF]${N}"
printf "${W}[07]${N} %-14s %-10b   ${W}[17]${N} %-16s %-8b\n" "Proxy Python" "${C}[PyD]${N}" "Over WebSocket" "${Y}[BETA]${N}"
printf "${W}[08]${N} %-14s %-10b   ${W}[18]${N} %-16s %-8b\n" "V2Ray Switch" "${R}[OFF]${N}" "SOCKS5" "${R}[OFF]${N}"
printf "${W}[09]${N} %-14s %-10b   ${W}[19]${N} %-16s %-8b\n" "CEA (Clash)" "${R}[OFF]${N}" "Protocolos UDP" "${R}[OFF]${N}"
printf "${W}[10]${N} %-14s %-10b   ${W}[20]${N} %-16s %-8b\n" "Trojan-Go" "${R}[OFF]${N}" "Funciones" "${Y}[DEV]${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " 🍄 ${W}HERRAMIENTAS Y SERVICIOS${N} 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 SERVICIOS (ALINEADO)
printf "${W}[21]${N} %-16s ${R}[OFF]${N}   ${W}[22]${N} %-14s ${G}[ON]${N}\n" "Block Torrent" "BadVPN"
printf "${W}[23]${N} %-16s ${R}[OFF]${N}   ${W}[24]${N} %-14s ${R}[OFF]${N}\n" "TCP BBR" "Fail2Ban"
printf "${W}[25]${N} %-16s ${G}[443]${N}   ${W}[26]${N} %-14s ${C}[RUN]${N}\n" "Archivo Online" "SpeedTest"
printf "${W}[27]${N} %-16s ${C}[INFO]${N}  ${W}[28]${N} %-14s ${R}[OFF]${N}\n" "Detalles VPS" "Block Ads"
printf "${W}[29]${N} %-16s ${R}[OFF]${N}   ${W}[30]${N} %-14s ${C}[EXTRA]${N}\n" "DNS Netflix" "Herramientas"
printf "${W}[31]${N} %-16s ${C}[SYS]${N}   ${W}[32]${N} %-14s ${R}[OFF]${N}\n" "Reiniciar Serv." "Brook Server"
printf "${W}[33]${N} %-16s ${C}[IPT]${N}   ${W}[34]${N} %-14s ${Y}[ROOT]${N}\n" "Firewall" "Cambiar Pass"
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