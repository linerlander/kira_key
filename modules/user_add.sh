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
echo -e " ${Y}⚜️  CREADOR DE CUENTAS KIRA  ⚜️${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${Y}[01]${N} %-30s %s\n" "➤ DEMO (Kira-2025)" "⚡"
printf " ${Y}[02]${N} %-30s %s\n" "➤ SSH NORMAL" "👤"
printf " ${R}[00]${N} %-30s %s\n" "➤ VOLVER" "⬅"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opción: " op

case $op in

# ================= DEMO =================
1|01)

rand=$(shuf -i 100-999 -n 1)
user="Kira-2025$rand"
pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)

echo -e "${C}✔ Usuario generado:${N} ${W}$user${N}"

# VALIDAR TIEMPO
while true; do
read -p "Tiempo (Ej: 30m / 2h / 1d): " tiempo
if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
break
else
echo -e "${R}Formato inválido${N}"
fi
done

read -p "Limite (default 1): " limit
[ -z "$limit" ] && limit=1

# CREAR
useradd -m -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
passwd -u "$user"
chage -I -1 -m 0 -M 99999 -E -1 "$user"

mkdir -p /etc/kira/{limits,expire}
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) $tiempo" > /etc/kira/expire/$user

# INFO
IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}⚜️ CUENTA DEMO GENERADA ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${C}🌐 IP        :${N} ${W}%s\n" "$IP"
printf " ${C}👤 USER      :${N} ${W}%s\n" "$user"
printf " ${C}🔑 PASSWORD  :${N} ${W}%s\n" "$pass"
printf " ${C}📡 PUERTO    :${N} ${W}%s\n" "$PORT"
printf " ${C}📊 LIMITE    :${N} ${W}%s\n" "$limit"
printf " ${C}⏳ TIEMPO    :${N} ${W}%s\n" "$tiempo"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${C}🔗 CONEXIÓN:${N} ${W}${IP}:${PORT}@${user}:${pass}${N}"
echo -e "${C}🌐 PROXY:${N} ${W}${IP}:80@${user}:${pass}${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# LOG
echo "$user $pass DEMO $limit $(date)" >> /etc/kira/users.log

read -p "Enter..."
;;

# ================= NORMAL =================
2|02)

read -p "Usuario: " user

# VALIDAR EXISTENCIA
if id "$user" &>/dev/null; then
echo -e "${R}✖ Usuario ya existe${N}"
sleep 2
continue
fi

read -p "Password: " pass
read -p "Dias: " dias
read -p "Limite: " limit
[ -z "$limit" ] && limit=1

# VALIDAR NUMERO
if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
echo -e "${R}Dias inválido${N}"
sleep 2
continue
fi

# CREAR
useradd -m -s /bin/bash "$user"
echo "$user:$pass" | chpasswd
passwd -u "$user"
chage -I -1 -m 0 -M 99999 -E -1 "$user"

mkdir -p /etc/kira/{limits,expire}
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) ${dias}d" > /etc/kira/expire/$user

# INFO
IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22
expira=$(date -d "$dias days" +"%d/%m/%Y")

clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}⚜️ CUENTA SSH GENERADA ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${C}🌐 IP        :${N} ${W}%s\n" "$IP"
printf " ${C}👤 USER      :${N} ${W}%s\n" "$user"
printf " ${C}🔑 PASSWORD  :${N} ${W}%s\n" "$pass"
printf " ${C}📡 PUERTO    :${N} ${W}%s\n" "$PORT"
printf " ${C}📊 LIMITE    :${N} ${W}%s\n" "$limit"
printf " ${C}⏳ EXPIRA    :${N} ${W}%s\n" "$expira"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${C}🔗 CONEXIÓN:${N} ${W}${IP}:${PORT}@${user}:${pass}${N}"
echo -e "${C}🌐 PROXY:${N} ${W}${IP}:80@${user}:${pass}${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# LOG
echo "$user $pass ${dias}d $limit $(date)" >> /etc/kira/users.log

read -p "Enter..."
;;

0|00)
exit
;;

*)
echo -e "${R}Opción inválida${N}"
sleep 1
;;

esac
done