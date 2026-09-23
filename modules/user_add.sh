#!/bin/bash

# Evita cierres accidentales por señales
trap '' INT TERM

# ========= COLORES ANSI DE TU MENÚ PRINCIPAL =========
W=$'\033[1;37m'
D=$'\033[0;90m'
Y=$'\033[1;33m'
R=$'\033[1;31m'
C=$'\033[1;36m'
G=$'\033[1;32m'
B=$'\033[1;34m'
N=$'\033[0m'

while true; do
clear

# ===== ENCABEZADO RECTANGULAR PRINCIPAL (ANCHO: 77) =====
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b🔐 CREADOR DE CUENTAS SSH | KIRA VIP%b                  %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %bSELECCIONA EL TIPO DE CUENTA A GENERAR EN EL SISTEMA%b                        %b│%b\n" "$D" "$N" "$W" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"

# ===== OPCIONES DEL MENÚ =====
printf " %b[01]%b ⚡ GENERAR CUENTA DEMO             %-4s %b⚡ (TEMPORAL)%b\n" "$Y" "$N" "" "$C" "$N"
printf " %b[02]%b 👤 CREAR USUARIO NORMAL           %-4s %b👤 (OFICIAL)%b\n" "$Y" "$N" "" "$G" "$N"

printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
printf " %b[0]%b %b►%b %b[ REGRESAR ]%b\n" "$R" "$N" "$R" "$N" "$W" "$N"
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
echo ""
printf " %bKIRA@Servidor:~/Usuarios$%b %b► Opción: %b " "$C" "$N" "$W" "$N"

read op

case $op in

# ================= 01: CUENTA DEMO =================
1|01)
clear
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b⚡ CREAR CUENTA DEMO TEMPORAL%b                         %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"

rand=$(shuf -i 100-999 -n 1)
user="Kira-2026$rand"
pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)

printf "\n %b▶ Usuario autogenerado:%b %b%s%b\n\n" "$C" "$N" "$W" "$user" "$N"

while true; do
    printf " %b► Tiempo de duración (Ej: 30m / 2h / 1d):%b " "$W" "$N"
    read tiempo
    if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
        break
    else
        printf " %b❌ Formato inválido. Usa m (minutos), h (horas), d (días).%b\n" "$R" "$N"
    fi
done

printf " %b► Límite de conexiones (Default 1):%b " "$W" "$N"
read limit
[ -z "$limit" ] && limit=1

# PROCESAMIENTO DE TIEMPO
cantidad=$(echo "$tiempo" | grep -oE '[0-9]+')
unidad=$(echo "$tiempo" | grep -oE '[smhd]')

case "$unidad" in
    m) tipo_tiempo="$cantidad minutes" ;;
    h) tipo_tiempo="$cantidad hours" ;;
    d) tipo_tiempo="$cantidad days" ;;
    *) tipo_tiempo="1 days" ;;
esac

exp_date=$(date -d "+$tipo_tiempo" +%Y-%m-%d)
useradd -M -s /bin/false "$user" 2>/dev/null
echo "$user:$pass" | chpasswd 2>/dev/null
passwd -u "$user" &>/dev/null
chage -E "$exp_date" "$user" 2>/dev/null

# GUARDADO EN BASE DE DATOS
mkdir -p /etc/kira/limits /etc/kira/expire /etc/kira/pass
echo "$limit" > /etc/kira/limits/$user
echo "$exp_date" > /etc/kira/expire/$user
echo "$pass" > /etc/kira/pass/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

directo="${IP}:${PORT}@${user}:${pass}"
proxy="${IP}:80@${user}:${pass}"

clear
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b⚡ DETALLES DE CUENTA DEMO CREADA%b                   %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b🖥️ Ip Server    :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$IP" "$N" "$D" "$N"
printf "%b│%b %b👤 Usuario      :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$Y" "$user" "$N" "$D" "$N"
printf "%b│%b %b🔑 Contraseña   :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$pass" "$N" "$D" "$N"
printf "%b│%b %b📡 Puerto SSH   :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$PORT" "$N" "$D" "$N"
printf "%b│%b %b📊 Límite SSH   :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$limit dispositivos" "$N" "$D" "$N"
printf "%b│%b %b⏳ Validez      :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$tiempo (Expira: $exp_date)" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b📋 DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):%b                            %b│%b\n" "$D" "$N" "$G" "$N" "$D" "$N"
printf "%b│%b %b🔗 Direc: %b%-60s%b %b│%b\n" "$D" "$N" "$Y" "$directo" "$N" "$D" "$N"
printf "%b│%b %b🖥️ Proxy: %b%-60s%b %b│%b\n" "$D" "$N" "$Y" "$proxy" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"

echo "$user $pass DEMO $limit $(date)" >> /etc/kira/users.log

echo ""
printf " %bPresiona Enter para continuar...%b " "$W" "$N"
read
;;

# ================= 02: USUARIO NORMAL =================
2|02)
clear
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b👤 CREAR USUARIO SSH ESTÁNDAR%b                        %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"

printf " %b► Nombre de usuario:%b " "$W" "$N"
read user

if id "$user" &>/dev/null; then
    printf "\n %b❌ El usuario '%s' ya existe en el servidor.%b\n" "$R" "$user" "$N"
    sleep 2
    continue
fi

printf " %b► Contraseña:%b " "$W" "$N"
read pass
printf " %b► Días de validez:%b " "$W" "$N"
read dias
printf " %b► Límite de conexiones (Default 1):%b " "$W" "$N"
read limit
[ -z "$limit" ] && limit=1

if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
    printf "\n %b❌ Cantidad de días inválida.%b\n" "$R" "$N"
    sleep 2
    continue
fi

exp_date=$(date -d "+$dias days" +%Y-%m-%d)
useradd -M -s /bin/false "$user" 2>/dev/null
echo "$user:$pass" | chpasswd 2>/dev/null
passwd -u "$user" &>/dev/null
chage -E "$exp_date" "$user" 2>/dev/null

mkdir -p /etc/kira/limits /etc/kira/expire /etc/kira/pass
echo "$limit" > /etc/kira/limits/$user
echo "$exp_date" > /etc/kira/expire/$user
echo "$pass" > /etc/kira/pass/$user

IP=$(curl -s ifconfig.me)
PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22
expira_format=$(date -d "$exp_date" +"%d/%m/%Y" 2>/dev/null || echo "$exp_date")

directo="${IP}:${PORT}@${user}:${pass}"
proxy="${IP}:80@${user}:${pass}"

clear
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b👑 DETALLES DE CUENTA SSH VIP CREADA%b                 %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b🖥️ Ip Server    :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$IP" "$N" "$D" "$N"
printf "%b│%b %b👤 Usuario      :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$Y" "$user" "$N" "$D" "$N"
printf "%b│%b %b🔑 Contraseña   :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$pass" "$N" "$D" "$N"
printf "%b│%b %b📡 Puerto SSH   :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$PORT" "$N" "$D" "$N"
printf "%b│%b %b📊 Límite SSH   :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$limit dispositivos" "$N" "$D" "$N"
printf "%b│%b %b⏳ Validez      :%b %b%-52s%b %b│%b\n" "$D" "$N" "$R" "$N" "$W" "$expira_format ($dias días)" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b📋 DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):%b                            %b│%b\n" "$D" "$N" "$G" "$N" "$D" "$N"
printf "%b│%b %b🔗 Direc: %b%-60s%b %b│%b\n" "$D" "$N" "$Y" "$directo" "$N" "$D" "$N"
printf "%b│%b %b🖥️ Proxy: %b%-60s%b %b│%b\n" "$D" "$N" "$Y" "$proxy" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"

echo "$user $pass ${dias}d $limit $(date)" >> /etc/kira/users.log

echo ""
printf " %bPresiona Enter para continuar...%b " "$W" "$N"
read
;;

0|00)
exit 0
;;

*)
printf " %bOpción inválida%b\n" "$R" "$N"
sleep 1
;;

esac
done