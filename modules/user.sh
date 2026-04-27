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

# ========= FUNCION CREAR USUARIO =========
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

rand=$(shuf -i 100-999 -n 1)
user="Kira-2025$rand"
pass=$(openssl rand -hex 4)

echo -e "\n${G}Usuario:${N} $user"
read -p "Tiempo (Ej: 30m): " tiempo

unit=${tiempo: -1}
value=${tiempo::-1}

case $unit in
m) exp=$(date -d "$value minutes" +"%Y-%m-%d") ;;
h) exp=$(date -d "$value hours" +"%Y-%m-%d") ;;
d) exp=$(date -d "$value days" +"%Y-%m-%d") ;;
*) echo "Formato invalido"; sleep 2; continue ;;
esac

read -p "Limite (default 1): " limit
[ -z "$limit" ] && limit=1

useradd -e "$exp" -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)

echo -e "\n${G}✔ CREADO${N}"
echo -e "🌐 IP: $IP"
echo -e "👤 User: $user"
echo -e "🔑 Pass: $pass"
echo -e "⏳ Tiempo: $tiempo"
echo -e "📊 Limite: $limit"

read -p "Enter..."
;;

# ===== NORMAL =====
2|02)

read -p "Usuario: " user
read -p "Pass: " pass
read -p "Dias: " dias
read -p "Limite: " limit

exp=$(date -d "$dias days" +"%Y-%m-%d")

useradd -e "$exp" -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

echo -e "${G}✔ Usuario creado${N}"
read -p "Enter..."
;;

0|00) break ;;
*) echo -e "${R}Opcion invalida${N}" ; sleep 1 ;;

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

# ========= MENU PRINCIPAL =========
while true; do
clear

# ===== LOGO KIRA =====
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

# ===== STATS =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')

printf " ${C}▶ RAM:${N} ${G}%-6s${N}   ${C}▶ CPU:${N} ${G}%s%%%s\n" "${RAM}MB" "$CPU" "$N"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== MENU =====
printf " ${G}[01]${N} ◇ AGREGAR USUARIO (KIRA)              📝\n"
printf " ${G}[02]${N} ◇ BORRAR USUARIO/s                   🗑️\n"
printf " ${G}[03]${N} ◇ EDITAR / RENOVAR                  🔄\n"
printf " ${G}[04]${N} ◇ USUARIOS REGISTRADOS              📋\n"
printf " ${G}[05]${N} ◇ USUARIOS ONLINE                   🌐\n"
printf " ${G}[06]${N} ◇ BANNER SSH                        🖥️\n"
printf " ${G}[07]${N} ◇ LOG DE CONSUMO                    📊\n"
printf " ${G}[08]${N} ◇ BLOQUEAR USUARIOS (${R}LOCK${N})       🔒\n"
printf " ${G}[09]${N} ◇ BACKUP (${G}KIRA${N})                  💾\n"
printf " ${G}[10]${N} ◇ CUENTAS SSR/SS                    ⚙️\n"
printf " ${G}[11]${N} ◇ BOT TELEGRAM (${G}ON${N}) (${Y}BETA${N}) 🤖\n"
printf " ${G}[12]${N} ◇ VERIFICADOR                      🧪\n"
printf " ${G}[13]${N} ◇ CHECKUSER (${R}OFF${N})               📡\n"
printf " ${G}[14]${N} ◇ MULTILOGIN CONTROL               🔥\n"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0]${N} ◇ REGRESAR"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${G}(KIRA CORE: ON)${N}   ${C}(KILL MULTI: OFF)${N}"

echo
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