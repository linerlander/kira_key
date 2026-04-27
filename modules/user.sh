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

# ========= CREAR USUARIO =========
crear_user() {

while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${W}        ⚜️   CREADOR DE CUENTAS KIRA  ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[01]${N} ⚡ DEMO (Kira-2025)"
echo -e " ${W}[02]${N} 👤 SSH NORMAL"
echo -e " ${W}[00]${N} ⬅ VOLVER"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

# ===== DEMO =====
1|01)

clear

rand=$(shuf -i 100-999 -n 1)
user="Kira-2025$rand"
pass=$(openssl rand -hex 4)

echo -e "${G}✔ Usuario generado:${N} ${W}$user${N}"

# VALIDACION TIEMPO
while true; do
read -p "Tiempo (Ej: 30m / 2h / 1d): " tiempo
if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
break
else
echo -e "${R}Formato invalido. Usa 30m / 2h / 1d${N}"
fi
done

unit=$(echo "$tiempo" | grep -o '[smhd]$')
value=$(echo "$tiempo" | grep -o '^[0-9]\+')

case $unit in
s) exp=$(date -d "$value seconds" +"%Y-%m-%d %H:%M:%S") ;;
m) exp=$(date -d "$value minutes" +"%Y-%m-%d %H:%M:%S") ;;
h) exp=$(date -d "$value hours" +"%Y-%m-%d %H:%M:%S") ;;
d) exp=$(date -d "$value days" +"%Y-%m-%d %H:%M:%S") ;;
esac

read -p "Limite conexiones (default 1): " limit
[ -z "$limit" ] && limit=1

# CREACION CORRECTA
useradd -m -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
passwd -u "$user"
chage -E "$exp" "$user"

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)

clear

echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ✔ USUARIO CREADO CORRECTAMENTE"
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " 🌐 IP      : %s\n" "$IP"
printf " 👤 USER    : %s\n" "$user"
printf " 🔑 PASS    : %s\n" "$pass"
printf " 📡 PUERTO  : %s\n" "$PORT"
printf " 📊 LIMITE  : %s\n" "$limit"
printf " ⏳ EXPIRA  : %s\n" "$exp"

echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "Enter para continuar..."
;;

# ===== NORMAL =====
2|02)

clear

read -p "Usuario: " user
read -p "Password: " pass
read -p "Dias: " dias
read -p "Limite: " limit

[ -z "$limit" ] && limit=1

exp=$(date -d "$dias days" +"%Y-%m-%d %H:%M:%S")

useradd -m -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
passwd -u "$user"
chage -E "$exp" "$user"

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)

echo -e "\n${G}✔ USUARIO CREADO${N}"
echo -e "🌐 IP: $IP"
echo -e "👤 User: $user"
echo -e "🔑 Pass: $pass"
echo -e "⏳ Expira: $exp"
echo -e "📊 Limite: $limit"

read -p "Enter..."
;;

0|00) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac
done
}

# ========= FUNCIONES =========
eliminar_user() { read -p "Usuario: " u; userdel -r "$u"; rm -f /etc/kira/limits/$u; }
listar_users() { awk -F: '$3>=1000 {print $1}' /etc/passwd; read -p "Enter..."; }
online_users() { who; read -p "Enter..."; }

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
1|01) crear_user ;;
2|02) eliminar_user ;;
4|04) listar_users ;;
5|05) online_users ;;
0) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;
esac

done