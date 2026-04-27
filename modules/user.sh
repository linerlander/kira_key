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

# ========= HEADER =========
header() {
clear
echo -e "${G}╔════════════════════════════════════════════════════╗${N}"
echo -e "${G}║   🔐 ADMINISTRADOR DE USUARIOS SSH | DROPBEAR     ║${N}"
echo -e "${G}╚════════════════════════════════════════════════════╝${N}"

RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')

echo -e " ${Y}► MEM LIBRE:${N} ${RAM}MB   ${Y}► CPU:${N} ${CPU}%"
echo -e "${D}────────────────────────────────────────────────────${N}"
}

# ========= FUNCIONES =========

crear_user() {
read -p "Usuario: " u
read -p "Password: " p
read -p "Dias: " d
read -p "Limite: " l

exp=$(date -d "$d days" +"%Y-%m-%d")

useradd -e "$exp" -M -s /bin/false "$u"
echo "$u:$p" | chpasswd

mkdir -p /etc/kira/limits
echo "$l" > /etc/kira/limits/$u

echo -e "${G}✔ Usuario creado${N}"
sleep 2
}

eliminar_user() {
read -p "Usuario: " u
userdel -r "$u" 2>/dev/null
rm -f /etc/kira/limits/$u
echo -e "${R}✔ Eliminado${N}"
sleep 2
}

renovar_user() {
read -p "Usuario: " u
read -p "Dias extra: " d
chage -E $(date -d "$d days" +"%Y-%m-%d") "$u"
echo -e "${G}✔ Renovado${N}"
sleep 2
}

listar_users() {
echo -e "${Y}USUARIOS:${N}"
awk -F: '$3>=1000 {print $1}' /etc/passwd
read -p "Enter..."
}

online_users() {
echo -e "${C}ONLINE:${N}"
who
read -p "Enter..."
}

backup_users() {
tar czf /root/backup_usuarios.tar.gz /etc/passwd /etc/shadow /etc/kira 2>/dev/null
echo -e "${G}✔ Backup creado${N}"
sleep 2
}

# ========= MENU =========

while true; do
header

printf " ${W}[01]${N} ➤ AGREGAR USUARIO        ${G}✔${N}\n"
printf " ${W}[02]${N} ➤ BORRAR USUARIO/S       ${R}✖${N}\n"
printf " ${W}[03]${N} ➤ EDITAR / RENOVAR       ${Y}⚙${N}\n"
printf " ${W}[04]${N} ➤ USUARIOS REGISTRADOS   ${C}👁${N}\n"
printf " ${W}[05]${N} ➤ USUARIOS CONECTADOS    ${P}🌐${N}\n"
printf " ${W}[06]${N} ➤ ADD/REMOVE BANNER      ${Y}⚙${N}\n"
printf " ${W}[07]${N} ➤ LOG DE CONSUMO         ${C}📊${N}\n"
printf " ${W}[08]${N} ➤ BLOQUEAR USUARIO       ${R}🔒${N}\n"
printf " ${W}[09]${N} ➤ BACKUP USUARIOS        ${G}✔${N}\n"
printf " ${W}[10]${N} ➤ MENU SSR/SS            ${C}⚙${N}\n"
printf " ${W}[11]${N} ➤ BOT TELEGRAM           ${Y}[BETA]${N}\n"
printf " ${W}[12]${N} ➤ VERIFICADOR CLIENTES   ${C}✔${N}\n"
printf " ${W}[13]${N} ➤ CHECKUSER              ${R}[OFF]${N}\n"
printf " ${W}[14]${N} ➤ CONTROL MULTILOGIN     ${G}[ON]${N}\n"

echo -e "${D}────────────────────────────────────────────────────${N}"
echo -e " ${R}[0] ➤ REGRESAR${N}"
echo -e "${D}────────────────────────────────────────────────────${N}"

read -p " ➤ Opcion: " op

case $op in

1|01) crear_user ;;
2|02) eliminar_user ;;
3|03) renovar_user ;;
4|04) listar_users ;;
5|05) online_users ;;
9|09) backup_users ;;

6) echo "banner (pendiente)"; sleep 1 ;;
7) echo "log consumo (pendiente)"; sleep 1 ;;
8) echo "bloqueo usuario (pendiente)"; sleep 1 ;;
10) echo "ssr menu (pendiente)"; sleep 1 ;;
11) echo "telegram (pendiente)"; sleep 1 ;;
12) echo "verificador (pendiente)"; sleep 1 ;;
13) echo "checkuser (pendiente)"; sleep 1 ;;
14) echo "multilogin activo"; sleep 1 ;;

0) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac

done