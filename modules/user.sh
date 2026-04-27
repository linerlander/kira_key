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
echo -e "${C}╔══════════════════════════════════════════════════╗${N}"
echo -e "${C}║        🔐 PANEL DE USUARIOS KIRA SYSTEM         ║${N}"
echo -e "${C}╚══════════════════════════════════════════════════╝${N}"

RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')

echo -e " ${Y}RAM:${N} ${RAM}MB   ${Y}CPU:${N} ${CPU}%"
echo -e "${D}────────────────────────────────────────────────────${N}"
}

# ========= CREAR USUARIO =========
crear_user() {

while true; do
clear

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${W}        ⚜️   CREADOR DE CUENTAS KIRA  ⚜️${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[01]${N}  > DEMO (Tiempo personalizado)"
echo -e " ${W}[02]${N}  > SSH NORMAL"
echo -e " ${W}[00]${N}  ⇦ VOLVER"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

# ===== DEMO AVANZADO =====
1|01)

clear

echo -e "${C}╔══════════════════════════════════════════════════╗${N}"
echo -e "${C}║            ⚡ GENERADOR DEMO KIRA ⚡             ║${N}"
echo -e "${C}╚══════════════════════════════════════════════════╝${N}"

rand=$(shuf -i 100-999 -n 1)
user="Kira-2025$rand"
pass=$(openssl rand -hex 4)

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}Usuario generado:${N} ${G}$user${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}Duración:${N}"
echo -e " ${D}Usa: s=seg m=min h=hora d=dia${N}"
read -p " ➤ Tiempo (Ej: 30m): " tiempo

unit=${tiempo: -1}
value=${tiempo::-1}

case $unit in
s) exp=$(date -d "$value seconds" +"%Y-%m-%d %H:%M:%S") ;;
m) exp=$(date -d "$value minutes" +"%Y-%m-%d %H:%M:%S") ;;
h) exp=$(date -d "$value hours" +"%Y-%m-%d %H:%M:%S") ;;
d) exp=$(date -d "$value days" +"%Y-%m-%d") ;;
*) echo -e "${R}Formato invalido${N}"; sleep 2; continue ;;
esac

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
read -p " ➤ Limite conexiones (default 1): " limit
[ -z "$limit" ] && limit=1

exp_date=$(date -d "$exp" +"%Y-%m-%d")

useradd -e "$exp_date" -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

mkdir -p /etc/kira/limits
echo "$limit" > /etc/kira/limits/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)

clear

echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}✔ USUARIO TEMPORAL CREADO${N}"
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

printf " ${W}IP      :${N} ${C}%s${N}\n" "$IP"
printf " ${W}USUARIO :${N} ${G}%s${N}\n" "$user"
printf " ${W}PASS    :${N} ${Y}%s${N}\n" "$pass"
printf " ${W}PUERTO  :${N} ${C}%s${N}\n" "$PORT"
printf " ${W}LIMITE  :${N} ${P}%s${N}\n" "$limit"
printf " ${W}TIEMPO  :${N} ${R}%s${N}\n" "$tiempo"

echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " Enter para continuar..."
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

0|00) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac

done
}

# ========= MENU PRINCIPAL =========
while true; do
header

echo -e " ${W}[01]${N} ➤ AGREGAR USUARIO"
echo -e " ${W}[00]${N} ➤ VOLVER"

echo -e "${D}────────────────────────────────────────────────────${N}"

read -p " ➤ Opcion: " op

case $op in

1|01) crear_user ;;
0) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;

esac

done