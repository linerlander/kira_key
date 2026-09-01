#!/bin/bash

# 🎨 COLORES
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[38;5;255m'
N='\033[0m'

# ===== FUNCIONES DE ESTADO REAL =====
# Devuelven exactamente 5 caracteres visuales ("[ON] " o "[OFF]") 
# para no romper la alineación perfecta de las columnas.

# Verifica servicios de Systemd (ej. ssh, dropbear)
chk_sys() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        printf "${G}[ON] ${N}"
    else
        printf "${R}[OFF]${N}"
    fi
}

# Verifica procesos en ejecución (ej. badvpn, psiphon)
chk_prc() {
    if pgrep -f "$1" >/dev/null 2>&1; then
        printf "${G}[ON] ${N}"
    else
        printf "${R}[OFF]${N}"
    fi
}

# Verifica si el acelerador TCP BBR está activo
chk_bbr() {
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        printf "${G}[ON] ${N}"
    else
        printf "${R}[OFF]${N}"
    fi
}

# ===== MOTOR DE ALINEACIÓN PERFECTA =====
# $1=Num1, $2=Nombre1, $3=Estado1, $4=Num2, $5=Nombre2, $6=Estado2
print_row() {
    printf "${W}[%02d]${N} %-18s %b   ${W}[%02d]${N} %-18s %b\n" "$1" "$2" "$3" "$4" "$5" "$6"
}

while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🍄 ${W}INSTALACION DE PROTOCOLOS${Y} ( KIRA ) 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 PROTOCOLOS (Verificaciones Reales)
print_row 1  "OpenSSH"      "$(chk_sys ssh)"               11 "Psiphon Server" "$(chk_prc psiphon)"
print_row 2  "Dropbear"     "$(chk_sys dropbear)"          12 "TCP DNS"        "${Y}[BETA]${N}"
print_row 3  "OpenVPN"      "$(chk_prc openvpn)"           13 "Webmin"         "$(chk_sys webmin)"
print_row 4  "SSL/TLS"      "$(chk_sys stunnel4)"          14 "SlowDNS"        "$(chk_prc slowdns)"
print_row 5  "Shadowsocks"  "$(chk_sys shadowsocks-libev)" 15 "SSL→Python"     "  ${R}[OFF]${N}"
print_row 6  "Squid Proxy"  "$(chk_sys squid)"             16 "SSH Multiplex"  "${R}[OFF]${N}"
print_row 7  "Proxy Python" "$(chk_sys proxy-python)"      17 "Over WebSocket" "$(chk_prc ws-epro)"
print_row 8  "V2Ray Switch" "$(chk_sys v2ray)"             18 "SOCKS5"         "$(chk_sys danted)"
print_row 9  "CEA (Clash)"  "$(chk_sys clash)"             19 "Protocolos UDP" "${R}[OFF]${N}"
print_row 10 "Trojan-Go"    "$(chk_sys trojan-go)"         20 "Funciones"      "${Y}[DEV]${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🍄 ${W}HERRAMIENTAS Y SERVICIOS${N} 🍄"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔥 SERVICIOS (Verificaciones Reales y Etiquetas Fijas)
print_row 21 "Block Torrent"  "${R}[OFF]${N}" 22 "BadVPN"       "$(chk_prc badvpn-udpgw)"
print_row 23 "TCP BBR"        "$(chk_bbr)"    24 "Fail2Ban"     "$(chk_sys fail2ban)"
print_row 25 "Archivo Online" "${G}[443]${N}" 26 "SpeedTest"    "${C}[RUN]${N}"
print_row 27 "Detalles VPS"   "${C}[INF]${N}" 28 "Block Ads"    "${R}[OFF]${N}"
print_row 29 "DNS Netflix"    "${R}[OFF]${N}" 30 "Herramientas" "${C}[EXTRA]${N}"
print_row 31 "Reiniciar Serv." "${C}[SYS]${N}" 32 "Brook Server" "$(chk_sys brook)"
print_row 33 "Firewall"       "${C}[IPT]${N}" 34 "Cambiar Pass" "${Y}[ROOT]${N}"

printf "${W}[35]${N} %-18s\n" "AToken Mods"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${R}[0]${W} REGRESAR${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op 

case $op in

  1|01)
    bash modules/ssh.sh
  ;;
  
  2|02)
    bash modules/dropbear.sh
  ;;
  
  4|04)
    bash modules/ssl_tls.sh
  ;;
  
  6|06)
    apt install squid -y
    systemctl restart squid
  ;;
  
  7|07)
    bash modules/proxy_python.sh
  ;;
  
  17|17)
    bash modules/websocket.sh
  ;;
  
  22|22)
    bash modules/badvpn.sh
  ;;
  
  31)
    # Aprovechamos para reiniciar también stunnel4 que es tu SSL
    systemctl restart ssh 2>/dev/null
    systemctl restart stunnel4 2>/dev/null
    systemctl restart squid 2>/dev/null
    systemctl restart dropbear 2>/dev/null
    echo -e "\n${G}Servicios reiniciados.${N}"
    sleep 1
  ;;
  
  0)
    break
  ;;
  
  *)
    echo -e "\n${R}Opcion invalida${N}"
    sleep 1
  ;;

esac
done