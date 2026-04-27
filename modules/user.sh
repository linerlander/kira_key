#!/bin/bash

# ========= COLORES =========
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
P='\033[38;5;201m'
W='\033[1;37m'
D='\033[38;5;240m'
N='\033[0m'

# ========= RUTA SEGURA =========
DIR="$(cd "$(dirname "$0")" && pwd)"

# ========= MENU =========
while true; do
clear

echo -e "${G}"
echo "██╗  ██╗██╗██████╗  █████╗ "
echo "██║ ██╔╝██║██╔══██╗██╔══██╗"
echo "█████╔╝ ██║██████╔╝███████║"
echo "██╔═██╗ ██║██╔══██╗██╔══██║"
echo "██║  ██╗██║██║  ██║██║  ██║"
echo "╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🔐 ${W}KIRA USER MANAGER${N} 🔐"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')

printf " ▶ RAM: %sMB   ▶ CPU: %s%%\n" "$RAM" "$CPU"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " [01] 👤 AGREGAR USUARIO\n"
printf " [02] ❌ BORRAR USUARIO\n"
printf " [03] 🔄 RENOVAR USUARIO\n"
printf " [04] 📋 USUARIOS REGISTRADOS\n"
printf " [05] 🌐 USUARIOS ONLINE\n"
printf " [06] 🖥️ BANNER\n"
printf " [07] 📊 LOG\n"
printf " [08] 🔒 BLOQUEAR\n"
printf " [09] 💾 BACKUP\n"
printf " [10] ⚙️ SSR/SS\n"
printf " [11] 🤖 TELEGRAM\n"
printf " [12] 🧪 VERIFICADOR\n"
printf " [13] 📡 CHECKUSER\n"
printf " [14] 🔥 MULTILOGIN\n"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " [0] VOLVER"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ▶ Opcion : " op

case $op in

# 👉 AGREGAR USUARIO (MODULE)
1|01)
bash "$DIR/modules/user_add.sh"
;;

# 👉 BORRAR USUARIO
2|02)
read -p "Usuario a eliminar: " u
userdel -r "$u" 2>/dev/null
rm -f /etc/kira/limits/$u
rm -f /etc/kira/expire/$u
echo -e "${G}✔ Usuario eliminado${N}"
sleep 2
;;

# 👉 RENOVAR (placeholder)
3|03)
echo -e "${Y}En desarrollo...${N}"
sleep 2
;;

# 👉 LISTAR
4|04)
awk -F: '$3>=1000 {print $1}' /etc/passwd
read -p "Enter..."
;;

# 👉 ONLINE
5|05)
who
read -p "Enter..."
;;

# 👉 OTROS (placeholder pro)
6|06|7|07|8|08|9|09|10|11|12|13|14)
echo -e "${Y}Modulo en desarrollo...${N}"
sleep 2
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