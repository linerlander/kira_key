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

# ========= CREAR USUARIO (SUBMENU) =========
crear_user() {

while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${W}        ⚜️   CREADOR DE CUENTAS TIPO  ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[01]${N}  > SSH|DROPBEAR (DEMO)"
echo -e " ${W}[02]${N}  > SSH|DROPBEAR"
echo -e " ${W}[03]${N}  > HWID"
echo -e " ${W}[04]${N}  > TOKEN"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}[05]${N}  > MODIFICAR TOKEN"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[00]${N}  ⇦ VOLVER"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

# ===== DEMO =====
1|01)
user="demo$(date +%s | tail -c 4)"
pass="1234"
dias=1
limit=1

exp=$(date -d "$dias days" +"%Y-%m-%d")

useradd -e "$exp" -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)

echo -e "\n${G}✔ DEMO CREADO${N}"
echo -e "IP: $IP"
echo -e "User: $user"
echo -e "Pass: $pass"
echo -e "Port: $PORT"
echo -e "Expira: $exp"
read -p "Enter..."
;;

# ===== NORMAL =====
2|02)
read -p "Usuario: " user
read -p "Password: " pass
read -p "Dias: " dias
read -p "Limite: " limit

if id "$user" &>/dev/null; then
echo -e "${R}✖ Usuario ya existe${N}"
sleep 2
continue
fi

exp=$(date -d "$dias days" +"%Y-%m-%d")

useradd -e "$exp" -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)
PORTS=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}' | tr '\n' ' ')

echo -e "\n${G}✔ USUARIO CREADO${N}"
echo -e "${Y}════════════════════════════${N}"
echo -e "IP: $IP"
echo -e "User: $user"
echo -e "Pass: $pass"
echo -e "Ports: $PORTS"
echo -e "Expira: $exp"
echo -e "Limite: $limit"
echo -e "${Y}════════════════════════════${N}"
read -p "Enter..."
;;

# ===== TOKEN =====
4|04)
token=$(openssl rand -hex 4)
mkdir -p /etc/kira
echo "$token" > /etc/kira/token.txt
echo -e "${G}✔ TOKEN: $token${N}"
sleep 2
;;

# ===== EDIT TOKEN =====
5|05)
read -p "Nuevo token: " token
echo "$token" > /etc/kira/token.txt
echo -e "${G}✔ TOKEN ACTUALIZADO${N}"
sleep 2
;;

0|00) break ;;

*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac

done
}

# ========= FUNCIONES =========

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

# ========= MENU PRINCIPAL =========

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

0) break ;;

*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac

done