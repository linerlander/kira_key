#!/bin/bash

R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[1;37m'
N='\033[0m'

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

1|01)

rand=$(shuf -i 100-999 -n 1)
user="Kira-2025$rand"
pass=$(openssl rand -hex 4)

read -p "Tiempo (Ej: 30m / 2h / 1d): " tiempo
read -p "Limite (default 1): " limit
[ -z "$limit" ] && limit=1

useradd -m -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
passwd -u "$user"
chage -I -1 -m 0 -M 99999 -E -1 "$user"

mkdir -p /etc/kira/{limits,expire}
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) $tiempo" > /etc/kira/expire/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep Port /etc/ssh/sshd_config | awk '{print $2}')

clear

echo -e "${G}✔ USUARIO CREADO${N}"
echo -e "🌐 IP: $IP"
echo -e "👤 USER: $user"
echo -e "🔑 PASS: $pass"
echo -e "📡 PORT: $PORT"
echo -e "📊 LIMIT: $limit"
echo -e "⏳ TIME: $tiempo"

read -p "Enter..."
;;

2|02)

read -p "Usuario: " user
read -p "Password: " pass
read -p "Dias: " dias
read -p "Limite: " limit
[ -z "$limit" ] && limit=1

useradd -m -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
passwd -u "$user"
chage -I -1 -m 0 -M 99999 -E -1 "$user"

mkdir -p /etc/kira/{limits,expire}
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) ${dias}d" > /etc/kira/expire/$user

IP=$(curl -s ifconfig.me)

echo -e "${G}✔ USUARIO CREADO${N}"
echo -e "👤 $user | 🔑 $pass | ⏳ ${dias} dias"

read -p "Enter..."
;;

0|00) exit ;;
*) echo "Opcion invalida"; sleep 1 ;;

esac
done