#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'
R= '\033[38;5;218m'

while true; do
clear

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${Y}🔐 CREADOR DE CUENTAS SSH | KIRA VIP${N}"
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

mkdir -p /etc/kira/limits /etc/kira/expire
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) $tiempo" > /etc/kira/expire/$user

# OBTENER DATOS DE CONEXIÓN
IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

clear
echo -e "${D}╔══════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}          ⚡ KIRA PANEL - CUENTA DEMO ⚡          ${D}║${N}"
echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${R}🖥️ IP SERVER   :${N} %-31s ${D}║${N}\n" "$IP"
printf "${D}║${N} ${R}👤 USUARIO     :${N} %-31s ${D}║${N}\n" "$user"
printf "${D}║${N} ${R}🔑 CONTRASEÑA  :${N} %-31s ${D}║${N}\n" "$pass"
printf "${D}║${N} ${R}📡 PUERTO SSH  :${N} %-31s ${D}║${N}\n" "$PORT"
printf "${D}║${N} ${R}📊 LÍMITE SSH  :${N} %-31s ${D}║${N}\n" "$limit dispositivos"
printf "${D}║${N} ${R}⏳ VALIDEZ     :${N} %-31s ${D}║${N}\n" "$tiempo"
echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${G}📋 DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):${N}       ${D}║${N}"
echo -e "${D}║${N}                                                  ${D}║${N}"
echo -e "${W}║${N}🔗 DIREC:${N} ${Y}${IP}:${PORT}@${user}:${pass}║${N}"
echo -e "${W}║${N}🖥️ PROXY:${N} ${Y}${IP}:80@${user}:${pass}║${N}"
echo -e "${D}╚══════════════════════════════════════════════════╝${N}"

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

mkdir -p /etc/kira/limits /etc/kira/expire
echo "$limit" > /etc/kira/limits/$user
echo "$(date +%s) ${dias}d" > /etc/kira/expire/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22
expira_format=$(date -d "$dias days" +"%d/%m/%Y")

clear
echo -e "${D}╔══════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}        👑 KIRA PANEL - CUENTA SSH VIP 👑        ${D}║${N}"
echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
 printf "${D}║${N}${C}🖥️ IP SERVER   :${N} %-31s ${D}║${N}\n" "$IP"
 printf "${D}║${N}${C}👤 USUARIO     :${N} %-31s ${D}║${N}\n" "$user"
 printf "${D}║${N}${C}🔑 CONTRASEÑA  :${N} ${W}%-31s${N} ${D}║${N}\n" "$pass"
 printf "${D}║${N}${C}📡 PUERTO SSH  :${N} %-31s ${D}║${N}\n" "$PORT"
 printf "${D}║${N}${C}📊 LÍMITE SSH  :${N} %-31s ${D}║${N}\n" "$limit dispo."
 printf "${D}║${N}${C}⏳ EXPIRACIÓN  :${N} %-31s ${D}║${N}\n" "$expira_format ($dias d)"
echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${G}📋 DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):${N}       ${D}║${N}"
echo -e "${D}║${N}                                                  ${D}║${N}"
echo -e "${W}║${N}🔗 DIRECTO:${N} ${Y}${IP}:${PORT}@${user}:${pass}${N}"
echo -e "${W}║${N}🖥️ PROXY  :${N} ${Y}${IP}:80@${user}:${pass}${N}"
echo -e "${D}╚══════════════════════════════════════════════════╝${N}"

echo "$user $pass ${dias}d $limit $(date)" >> /etc/kira/users.log

echo ""
read -p "Presiona Enter para continuar..."
;;

0|00)
exit 0
;;

*)
echo -e " ${R}Opción inválida${N}"
sleep 1
;;

esac
done