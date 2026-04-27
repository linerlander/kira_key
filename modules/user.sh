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

echo -e "${G}Usuario generado:${N} $user"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
read -p "Tiempo (Ej: 30m / 2h / 1d): " tiempo

unit=${tiempo: -1}
value=${tiempo::-1}

case $unit in
m) exp=$(date -d "$value minutes" +"%Y-%m-%d %H:%M:%S") ;;
h) exp=$(date -d "$value hours" +"%Y-%m-%d %H:%M:%S") ;;
d) exp=$(date -d "$value days" +"%Y-%m-%d %H:%M:%S") ;;
*) echo -e "${R}Formato invalido${N}"; sleep 2; continue ;;
esac

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
read -p "Limite conexiones (default 1): " limit
[ -z "$limit" ] && limit=1

# ===== CREACION REAL =====
useradd -M -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
chage -E "$exp" "$user"

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)

clear

echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}✔ USUARIO CREADO CORRECTAMENTE${N}"
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${W}🌐 IP      :${N} ${C}%s${N}\n" "$IP"
printf " ${W}👤 USUARIO :${N} ${G}%s${N}\n" "$user"
printf " ${W}🔑 PASS    :${N} ${Y}%s${N}\n" "$pass"
printf " ${W}📡 PUERTO  :${N} ${C}%s${N}\n" "$PORT"
printf " ${W}📊 LIMITE  :${N} ${P}%s${N}\n" "$limit"
printf " ${W}⏳ EXPIRA  :${N} ${R}%s${N}\n" "$exp"

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

useradd -M -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
chage -E "$exp" "$user"

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)

echo -e "\n${G}✔ USUARIO CREADO${N}"
echo -e "${Y}════════════════════════════${N}"
echo -e "🌐 IP: $IP"
echo -e "👤 User: $user"
echo -e "🔑 Pass: $pass"
echo -e "⏳ Expira: $exp"
echo -e "📊 Limite: $limit"
echo -e "${Y}════════════════════════════${N}"

read -p "Enter..."
;;

0|00) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac

done
}

# ========= FUNCIONES =========
eliminar_user() {
read -p "Usuario: " u
userdel -r "$u"
rm -f /etc/kira/limits/$u
}

listar_users() {
awk -F: '$3>=1000 {print $1}' /etc/passwd
read -p "Enter..."
}

online_users() {
who
read -p "Enter..."
}

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

printf " ${C}▶ RAM:${N} ${G}%-6s${N}   ${C}▶ CPU:${N} ${G}%s%%%s\n" "${RAM}MB" "$CPU" "$N"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${G}[01]${N} 👤 AGREGAR USUARIO\n"
printf " ${G}[02]${N} ❌ BORRAR USUARIO\n"
printf " ${G}[03]${N} 🔄 RENOVAR\n"
printf " ${G}[04]${N} 📋 USUARIOS\n"
printf " ${G}[05]${N} 🌐 ONLINE\n"
printf " ${G}[14]${N} 🔥 MULTILOGIN\n"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] VOLVER${N}"
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