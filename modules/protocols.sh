#!/bin/bash

# 🎨 COLORES
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[38;5;255m'
N='\033[0m'

status() {
  systemctl is-active --quiet $1 && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🍄 ${W}INSTALACION DE PROTOCOLOS${Y} ( KIRA ) 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 PROTOCOLOS (ALINEADO REAL)
printf "${W}[01]${N} %-18s %-8s   ${W}[11]${N} %-22s %s\n" "OpenSSH" "$(status ssh)" "Psiphon Server" "${R}[OFF]${N}"
printf "${W}[02]${N} %-18s %-8s   ${W}[12]${N} %-22s %s\n" "Dropbear" "$(status dropbear)" "TCP DNS" "${Y}[BETA]${N}"
printf "${W}[03]${N} %-18s %-8s   ${W}[13]${N} %-22s %s\n" "OpenVPN" "${R}[OFF]${N}" "Webmin" "${R}[OFF]${N}"
printf "${W}[04]${N} %-18s %-8s   ${W}[14]${N} %-22s %s\n" "SSL/TLS" "${R}[OFF]${N}" "SlowDNS" "${R}[OFF]${N}"
printf "${W}[05]${N} %-18s %-8s   ${W}[15]${N} %-22s %s\n" "Shadowsocks" "${R}[OFF]${N}" "SSL→Python" "${R}[OFF]${N}"
printf "${W}[06]${N} %-18s %-8s   ${W}[16]${N} %-22s %s\n" "Squid Proxy" "$(status squid)" "SSH Multiplex" "${R}[OFF]${N}"
printf "${W}[07]${N} %-18s %-8s   ${W}[17]${N} %-22s %s\n" "Proxy Python" "${C}[PyD]${N}" "Over WebSocket" "${Y}[BETA]${N}"
printf "${W}[08]${N} %-18s %-8s   ${W}[18]${N} %-22s %s\n" "V2Ray Switch" "${R}[OFF]${N}" "SOCKS5" "${R}[OFF]${N}"
printf "${W}[09]${N} %-18s %-8s   ${W}[19]${N} %-22s %s\n" "CEA (Clash)" "${R}[OFF]${N}" "Protocolos UDP" "${R}[OFF]${N}"
printf "${W}[10]${N} %-18s %-8s   ${W}[20]${N} %-22s %s\n" "Trojan-Go" "${R}[OFF]${N}" "Funciones" "${Y}[DEV]${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " 🍄 ${W}HERRAMIENTAS Y SERVICIOS${N} 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 SERVICIOS
printf "${W}[21]${N} %-20s ${R}[OFF]${N}   ${W}[22]${N} %-18s ${G}[ON]${N}\n" "Block Torrent" "BadVPN"
printf "${W}[23]${N} %-20s ${R}[OFF]${N}   ${W}[24]${N} %-18s ${R}[OFF]${N}\n" "TCP BBR" "Fail2Ban"
printf "${W}[25]${N} %-20s ${G}[443]${N}   ${W}[26]${N} %-18s ${C}[RUN]${N}\n" "Archivo Online" "SpeedTest"
printf "${W}[27]${N} %-20s ${C}[INFO]${N}  ${W}[28]${N} %-18s ${R}[OFF]${N}\n" "Detalles VPS" "Block Ads"
printf "${W}[29]${N} %-20s ${R}[OFF]${N}   ${W}[30]${N} %-18s ${C}[EXTRA]${N}\n" "DNS Netflix" "Herramientas"
printf "${W}[31]${N} %-20s ${C}[SYS]${N}   ${W}[32]${N} %-18s ${R}[OFF]${N}\n" "Reiniciar Serv." "Brook Server"
printf "${W}[33]${N} %-20s ${C}[IPT]${N}   ${W}[34]${N} %-18s ${Y}[ROOT]${N}\n" "Firewall" "Cambiar Pass"
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