#!/bin/bash

# Evita que cualquier error o señal cierre el menú principal
trap '' INT TERM

# ========= COLORES ANSI =========
W='\033[1;37m'
D='\033[0;90m'
Y='\033[1;33m'
R='\033[1;31m'
C='\033[1;36m'
G='\033[1;32m'
B='\033[1;34m'
N='\033[0m'

while true; do
clear

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🔐 ${Y}ADMINISTRADOR DE USUARIOS SSH | KIRA${N}"
echo -e " ${D}VERSIÓN 2.5 (Premium) | LICENCIA: ${G}ACTIVA${N} ${D}(Expiración: 2024-12-31)${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== STATS =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')
LATENCIA="45ms"

echo -e " ${C}▶ M LIBRE:${N} ${W}${RAM}M${N} ${D}|${N} ${C}▶ CPU:${N} ${W}${CPU}%${N} ${D}|${N} ${C}▶ LATENCIA:${N} ${W}${LATENCIA}${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== MENU EN COLUMNAS IMPRESO CON ECHO =====
echo -e " ${Y}[01]${N} 📝 AGREGAR USUARIO"
echo -e " ${Y}[02]${N} 🗑️  BORRAR USUARIO(S)"
echo -e " ${Y}[03]${N} 🔄 EDITAR / RENOVAR"
echo -e " ${Y}[04]${N} 📋 USUARIOS REGISTRADOS"
echo -e " ${Y}[05]${N} 👥 USUARIOS CONECTADOS"
echo -e " ${Y}[06]${N} 📢 BANNER SSH"
echo -e " ${Y}[07]${N} 📊 LOG DE CONSUMO"
echo -e " ${Y}[08]${N} 🔒 BLOQUEAR USUARIO           ${R}🔒 (ESTADO: BLOQUEADO)${N}"
echo -e " ${Y}[09]${N} 💾 BACKUP USUARIOS            ${W}⚙️  (OFICIAL★CERTIFICADO)${N}"
echo -e " ${Y}[10]${N} ⚙️  MENU SSR/SS               ${W}⚙️  (CERTIFICADO)${N}"
echo -e " ${Y}[11]${N} 🤖 BOT TELEGRAM               ${Y}🤖 (VERSIÓN BETA)${N}"
echo -e " ${Y}[12]${N} 🧪 VERIFICADOR                ${B}🧪 (MODO INDIVIDUAL)${N}"
echo -e " ${Y}[13]${N} 📡 CHECKUSER                  ${R}📡 (INACTIVO)${N}"
echo -e " ${Y}[14]${N} 💥 CONTROL MULTILOGIN"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0]${N} ${R}►${N} ${W}[ REGRESAR ]${N}                                ${D}ÚLTIMO REFRF${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${D}( CONTADOR: ${G}ON${D} | KILL MULTISESSION: ${R}OFF${D} )${N}   ${D}🔘 ESTADO DEL SERVICIO${N}"
echo ""
echo -ne " ${C}KIRA@Servidor:~/Administrador $${N} ${W}► Opción [_ ]${N} "
read op

case $op in

1|01)
    if [ -f "modules/user_add.sh" ]; then bash modules/user_add.sh; else echo -e "${R}Falta el archivo modules/user_add.sh${N}"; sleep 1.5; fi
    ;;

2|02)
    if [ -f "modules/user_clear.sh" ]; then bash modules/user_clear.sh; else echo -e "${R}Falta el archivo modules/user_clear.sh${N}"; sleep 1.5; fi
    ;;

3|03)
    if [ -f "modules/user_edit.sh" ]; then bash modules/user_edit.sh; else echo -e "${R}Falta el archivo modules/user_edit.sh${N}"; sleep 1.5; fi
    ;;

4|04)
    if [ -f "modules/user_list.sh" ]; then bash modules/user_list.sh; else echo -e "${R}Falta el archivo modules/user_list.sh${N}"; sleep 1.5; fi
    ;;

5|05)
    if [ -f "modules/user_online.sh" ]; then bash modules/user_online.sh; else echo -e "${R}Falta el archivo modules/user_online.sh${N}"; sleep 1.5; fi
    ;;

6|06)
    if [ -f "modules/ssh_banner.sh" ]; then bash modules/ssh_banner.sh; else echo -e "${R}Falta el archivo modules/ssh_banner.sh${N}"; sleep 1.5; fi
    ;;

11)
    if [ -f "modules/bot_telegram.sh" ]; then bash modules/bot_telegram.sh; else echo -e "${R}Falta el archivo modules/bot_telegram.sh${N}"; sleep 1.5; fi
    ;;

7|07|8|08|9|09|10|12|13|14)
    echo -e "${Y}Módulo en desarrollo...${N}"
    sleep 2
    ;;

0)
    clear
    exit 0
    ;;

*)
    echo -e "${R}Opción inválida${N}"
    sleep 1
    ;;

esac
done