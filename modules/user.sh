#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;245m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
N='\033[0m'

while true; do
clear

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}🔐 ADMINISTRADOR DE USUARIOS SSH | KIRA${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== STATS =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')

echo -e " ${C}▶ M LIBRE:${N} ${W}${RAM}M   ${C}▶ CPU:${N} ${W}${CPU}%${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== MENU EN COLUMNAS =====
printf " ${Y}[01]${N} %-36s ${D}%-12s${N} %s\n" "➤ AGREGAR USUARIO" "" "📝"
printf " ${Y}[02]${N} %-36s ${D}%-12s${N} %s\n" "➤ BORRAR USUARIO(S)" "" "🗑️"
printf " ${Y}[03]${N} %-36s ${D}%-12s${N} %s\n" "➤ EDITAR / RENOVAR" "" "🔄"
printf " ${Y}[04]${N} %-36s ${D}%-12s${N} %s\n" "➤ USUARIOS REGISTRADOS" "" "📋"
printf " ${Y}[05]${N} %-36s ${D}%-12s${N} %s\n" "➤ USUARIOS CONECTADOS" "" "🌐"
printf " ${Y}[06]${N} %-36s ${D}%-12s${N} %s\n" "➤ BANNER SSH" "" "🎭"
printf " ${Y}[07]${N} %-36s ${D}%-12s${N} %s\n" "➤ LOG DE CONSUMO" "" "📊"
printf " ${Y}[08]${N} %-36s ${R}%-12s${N} %s\n" "➤ BLOQUEAR USUARIO" "(LOCKED)" "🔒"
printf " ${Y}[09]${N} %-36s ${D}%-12s${N} %s\n" "➤ BACKUP USUARIOS" "(OFICIAL)" "💾"
printf " ${Y}[10]${N} %-36s ${D}%-12s${N} %s\n" "➤ MENU SSR/SS" "(OFICIAL)" "⚙️"
printf " ${Y}[11]${N} %-36s ${Y}%-12s${N} %s\n" "➤ BOT TELEGRAM" "(BETA)" "🤖"
printf " ${Y}[12]${N} %-36s ${D}%-12s${N} %s\n" "➤ VERIFICADOR" "(INDV)" "🧪"
printf " ${Y}[13]${N} %-36s ${R}%-12s${N} %s\n" "➤ CHECKUSER" "(OFF)" "📡"
printf " ${Y}[14]${N} %-36s ${D}%-12s${N} %s\n" "➤ CONTROL MULTILOGIN" "" "💥"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0]${N} ➤ ${W}[ REGRESAR ]${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${D}( CONTADOR: ${Y}ON${D} )   ( KILL MULTISESSION: ${R}OFF${D} )${N}"
echo ""
read -p " ► Opción: " op

case $op in

1|01)
bash modules/user_add.sh
;;

2|02)
read -p "Usuario: " u
userdel -r "$u" 2>/dev/null
rm -f /etc/kira/limits/$u
rm -f /etc/kira/expire/$u
echo -e "${Y}✔ Usuario eliminado${N}"
sleep 2
;;

3|03)
echo -e "${Y}En desarrollo...${N}"
sleep 2
;;

4|04)
awk -F: '$3>=1000 {print $1}' /etc/passwd
read -p "Enter..."
;;

5|05)
who
read -p "Enter..."
;;

6|06)
bash modules/protocols.sh
;;

7|07|8|08|9|09|10|11|12|13|14)
echo -e "${Y}Modulo en desarrollo...${N}"
sleep 2
;;

0)
break
;;

*)
echo -e "${R}Opción inválida${N}"
sleep 1
;;

esac
done