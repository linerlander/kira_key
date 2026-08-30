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
echo -e " ${Y}🔐 CREADOR DE CUENTAS SSH | KIRA${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${Y}[01]${N} %-36s ${D}%-12s${N} %s\n" "➤ GENERAR CUENTA DEMO" "(TEMPORAL)" "⚡"
printf " ${Y}[02]${N} %-36s ${D}%-12s${N} %s\n" "➤ CREAR USUARIO NORMAL" "(OFICIAL)" "👤"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[00]${N} ➤ ${W}[ REGRESAR ]${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opción: " op

case $op in

# ================= DEMO =================
1|01)
clear
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}⚡ CREAR CUENTA DEMO TEMPORAL${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

rand=$(shuf -i 100-999 -n 1)
user="Kira-2025$rand"
pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)

echo -e " ${C}▶ Usuario autogenerado:${N} ${W}$user${N}\n"

while true; do
    read -p " ► Tiempo de duración (Ej: 30m / 2h / 1d): " tiempo
    if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
        break
    else
        echo -e " ${R}❌ Formato inválido. Usa m (minutos), h (horas), d (días).${N}"
    fi
done

read -p " ► Límite de conexiones (Default 1): " limit
[ -z "$limit" ] && limit=1

# CREACIÓN EN SISTEMA
useradd -M -s /bin/false "$user" 2>/dev/null
echo "$user:$pass" | chpasswd 2>/dev/null
passwd -u "$user" &>/dev/null
chage -I -1 -m 0 -M 99999 -E -1 "$user"

mkdir -p /etc/kira/{limits,expire}
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) $tiempo" > /etc/kira/expire/$user

# OBTENER DATOS DE CONEXIÓN
IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

clear
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}⚡ CUENTA DEMO GENERADA EXITOSAMENTE ⚡${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${C}🌐 IP SERVER   :${N} ${W}%s\n" "$IP"
printf " ${C}👤 USUARIO     :${N} ${W}%s\n" "$user"
printf " ${C}🔑 CONTRASEÑA  :${N} ${W}%s\n" "$pass"
printf " ${C}📡 PUERTO SSH  :${N} ${W}%s\n" "$PORT"
printf " ${C}📊 LÍMITE SSH  :${N} ${W}%s dispositivo(s)\n" "$limit"
printf " ${C}⏳ TIEMPO VALIDO:${N} ${W}%s\n" "$tiempo"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${C}🔗 CONEXIÓN DIRECTA:${N}\n ${W}${IP}:${PORT}@${user}:${pass}${N}"
echo -e " ${C}🌐 PROXY PAYLOAD:${N}\n ${W}${IP}:80@${user}:${pass}${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo "$user $pass DEMO $limit $(date)" >> /etc/kira/users.log

echo ""
read -p "Presiona Enter para continuar..."
;;

# ================= NORMAL =================
2|02)
clear
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}👤 CREAR CUENTA SSH ESTÁNDAR${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Nombre de usuario: " user

if id "$user" &>/dev/null; then
    echo -e " ${R}❌ El usuario '$user' ya existe en el servidor.${N}"
    sleep 2
    continue
fi

read -p " ► Contraseña: " pass
read -p " ► Días de validez: " dias
read -p " ► Límite de conexiones (Default 1): " limit
[ -z "$limit" ] && limit=1

if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
    echo -e " ${R}❌ Cantidad de días inválida.${N}"
    sleep 2
    continue
fi

# CREACIÓN EN SISTEMA
exp_date=$(date -d "+$dias days" +%Y-%m-%d)
useradd -M -s /bin/false -e "$exp_date" "$user" 2>/dev/null
echo "$user:$pass" | chpasswd 2>/dev/null
passwd -u "$user" &>/dev/null
chage -I -1 -m 0 -M 99999 -E -1 "$user"

mkdir -p /etc/kira/{limits,expire}
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) ${dias}d" > /etc/kira/expire/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22
expira_format=$(date -d "$dias days" +"%d/%m/%Y")

clear
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}👤 CUENTA SSH GENERADA EXITOSAMENTE 👤${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${C}🌐 IP SERVER   :${N} ${W}%s\n" "$IP"
printf " ${C}👤 USUARIO     :${N} ${W}%s\n" "$user"
printf " ${C}🔑 CONTRASEÑA  :${N} ${W}%s\n" "$pass"
printf " ${C}📡 PUERTO SSH  :${N} ${W}%s\n" "$PORT"
printf " ${C}📊 LÍMITE SSH  :${N} ${W}%s dispositivo(s)\n" "$limit"
printf " ${C}⏳ EXPIRACIÓN  :${N} ${W}%s (%s días)\n" "$expira_format" "$dias"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${C}🔗 CONEXIÓN DIRECTA:${N}\n ${W}${IP}:${PORT}@${user}:${pass}${N}"
echo -e " ${C}🌐 PROXY PAYLOAD:${N}\n ${W}${IP}:80@${user}:${pass}${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo "$user $pass ${dias}d $limit $(date)" >> /etc/kira/users.log

echo ""
read -p "Presiona Enter para continuar..."
;;

0|00)
break
;;

*)
echo -e " ${R}Opción inválida${N}"
sleep 1
;;

esac
dones