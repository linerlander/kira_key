#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;245m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
N='\033[0m'

DIR="$(cd "$(dirname "$0")" && pwd)"

while true; do
clear

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}🔐 ADMINISTRADOR DE USUARIOS SSH | PANEL KIRA${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== STATS =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')

echo -e " ${C}▶ M LIBRE:${N} ${W}${RAM}M   ${C}▶ USO CPU:${N} ${W}${CPU}%${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== MENU =====
echo -e " ${Y}[01]${N} ➤ ${W}AGREGAR USUARIO${N} ${D}(HWID/NORMAL/TOKEN)${N} 📝"
echo -e " ${Y}[02]${N} ➤ ${W}BORRAR USUARIO(S)${N} 🗑️"
echo -e " ${Y}[03]${N} ➤ ${W}EDITAR / RENOVAR${N} 🔄"
echo -e " ${Y}[04]${N} ➤ ${W}USUARIOS REGISTRADOS${N} 📋"
echo -e " ${Y}[05]${N} ➤ ${W}USUARIOS CONECTADOS${N} 🌐"
echo -e " ${Y}[06]${N} ➤ ${W}BANNER SSH${N} 🎭"
echo -e " ${Y}[07]${N} ➤ ${W}LOG DE CONSUMO${N} 📊"
echo -e " ${Y}[08]${N} ➤ ${W}BLOQUEAR USUARIO${N} ${R}(LOCKED)${N} 🔒"
echo -e " ${Y}[09]${N} ➤ ${W}BACKUP USUARIOS${N} 💾"
echo -e " ${Y}[10]${N} ➤ ${W}MENU SSR/SS${N} ⚙️"
echo -e " ${Y}[11]${N} ➤ ${W}BOT TELEGRAM${N} ${Y}(BETA)${N} 🤖"
echo -e " ${Y}[12]${N} ➤ ${W}VERIFICADOR${N} 🧪"
echo -e " ${Y}[13]${N} ➤ ${W}CHECKUSER${N} ${R}(OFF)${N} 📡"
echo -e " ${Y}[14]${N} ➤ ${W}CONTROL MULTILOGIN${N} 💥"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0]${N} ➤ ${W}[ REGRESAR ]${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${D}( CONTADOR: ${Y}ON${D} )   ( KILL MULTISESSION: ${R}OFF${D} )${N}"

echo ""
read -p " ► Opción: " op

case $op in

1|01)
bash "$DIR/modules/user_add.sh"
;;

2|02)
read -p "Usuario: " u
userdel -r "$u" 2>/dev/null
rm -f /etc/kira/limits/$u
rm -f /etc/kira/expire/$u
echo -e "${Y}✔ Usuario eliminado${N}"
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

0)
break
;;

*)
echo -e "${R}Opción inválida${N}"
sleep 1
;;

esac
done