#!/bin/bash

# Evita que cualquier error o señal cierre el menú principal
trap '' INT TERM

# ========= COLORES ANSI =========
W=$'\033[1;37m'
D=$'\033[0;90m'
Y=$'\033[1;33m'
R=$'\033[1;31m'
C=$'\033[1;36m'
G=$'\033[1;32m'
B=$'\033[1;34m'
N=$'\033[0m'

# Limpia la pantalla solo una vez al iniciar el script
clear

while true; do

# Posiciona el cursor en la primera fila y columna (Evita el parpadeo de pantalla)
printf "\033[1;1H"

# ===== DATOS EN TIEMPO REAL =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')
HORA=$(date +'%H:%M:%S')
LATENCIA="45ms"
ULTIMO_REFRESH=$HORA

# ===== ENCABEZADO RECTANGULAR PERFECCIONADO (ANCHO: 77) =====
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b %b[ ⚡ KIRA-SSH ]%b  %b🔐 ADMINISTRADOR DE USUARIOS SSH | KIRA%b                  %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b│%b %bVERSIÓN 2.5 (Premium) | LICENCIA: %bACTIVA%b %b(Expiración: 2026-12-31)%b         %b│%b\n" "$D" "$N" "$D" "$G" "$D" "$D" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"

# ===== STATS EN TIEMPO REAL =====
printf "%b│%b %b▶ M LIBRE:%b %b%-4s%b %b|%b %b▶ CPU:%b %b%-3s%%%b %b|%b %b▶ HORA:%b %b%-8s%b %b|%b %b▶ LATENCIA:%b %b%-5s%b      %b│%b\n" \
  "$D" "$N" "$C" "$N" "$W" "${RAM}M" "$N" "$D" "$N" "$C" "$N" "$W" "$CPU" "$N" "$D" "$N" "$C" "$N" "$W" "$HORA" "$N" "$D" "$N" "$C" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"

# ===== MENÚ Y COLUMNAS SECUNDARIAS ALINEADAS =====
printf " %b[01]%b 📝 AGREGAR USUARIO                             \n" "$Y" "$N"
printf " %b[02]%b 🗑️ BORRAR USUARIO(S)                          \n" "$Y" "$N"
printf " %b[03]%b 🔄 EDITAR / RENOVAR                           \n" "$Y" "$N"
printf " %b[04]%b 📋 USUARIOS REGISTRADOS                       \n" "$Y" "$N"
printf " %b[05]%b 🙋‍♂️ USUARIOS CONECTADOS                         \n" "$Y" "$N"
printf " %b[06]%b 📢 BANNER SSH                                 \n" "$Y" "$N"
printf " %b[07]%b 📊 LOG DE CONSUMO                             \n" "$Y" "$N"
printf " %b[08]%b 🔒 BLOQUEAR USUARIO            %-4s %b🔒 (ESTADO: BLOQUEADO)%b\n" "$Y" "$N" "" "$R" "$N"
printf " %b[09]%b 💾 BACKUP USUARIOS             %-4s %b⚙️ (OFICIAL★CERTIFICADO)%b\n" "$Y" "$N" "" "$W" "$N"
printf " %b[10]%b ⚙️ MENU SSR/SS                 %-4s %b⚙️ (CERTIFICADO)%b\n" "$Y" "$N" "" "$W" "$N"
printf " %b[11]%b 🤖 BOT TELEGRAM                %-4s %b🤖 (VERSIÓN BETA)%b\n" "$Y" "$N" "" "$Y" "$N"
printf " %b[12]%b 🧪 VERIFICADOR                 %-4s %b🧪 (MODO INDIVIDUAL)%b\n" "$Y" "$N" "" "$B" "$N"
printf " %b[13]%b 🔌 CHECKUSER                   %-4s %b🔌 (INACTIVO)%b\n" "$Y" "$N" "" "$R" "$N"
printf " %b[14]%b 💥 CONTROL MULTILOGIN                          \n" "$Y" "$N"

printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
printf " %b[0]%b %b►%b %b[ REGRESAR ]%b                             %bÚLTIMO REFRESH: %s%b\n" "$R" "$N" "$R" "$N" "$W" "$N" "$D" "$ULTIMO_REFRESH" "$N"
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"

printf " %b( CONTADOR: %bON%b | KILL MULTISESSION: %bOFF%b )%b    %b🔘 ESTADO DEL SERVICIO%b\n" "$D" "$G" "$D" "$R" "$D" "$N" "$D" "$N"
echo ""
printf " %bKIRA@Servidor:~/Administrador$%b %b► Opción: %b " "$C" "$N" "$W" "$N"

# Lee la opción ingresada esperando hasta 1 segundo antes de actualizar métricas
read -t 1 op

if [ $? -ne 0 ]; then
    continue
fi

case $op in

1|01)
    clear
    if [ -f "modules/user_add.sh" ]; then bash modules/user_add.sh; else echo "Falta el archivo modules/user_add.sh"; sleep 1.5; fi
    clear
    ;;

2|02)
    clear
    if [ -f "modules/user_clear.sh" ]; then bash modules/user_clear.sh; else echo "Falta el archivo modules/user_clear.sh"; sleep 1.5; fi
    clear
    ;;

3|03)
    clear
    if [ -f "modules/user_edit.sh" ]; then bash modules/user_edit.sh; else echo "Falta el archivo modules/user_edit.sh"; sleep 1.5; fi
    clear
    ;;

4|04)
    clear
    if [ -f "modules/user_list.sh" ]; then bash modules/user_list.sh; else echo "Falta el archivo modules/user_list.sh"; sleep 1.5; fi
    clear
    ;;

5|05)
    clear
    if [ -f "modules/user_online.sh" ]; then bash modules/user_online.sh; else echo "Falta el archivo modules/user_online.sh"; sleep 1.5; fi
    clear
    ;;

6|06)
    clear
    if [ -f "modules/ssh_banner.sh" ]; then bash modules/ssh_banner.sh; else echo "Falta el archivo modules/ssh_banner.sh"; sleep 1.5; fi
    clear
    ;;

11)
    clear
    if [ -f "modules/bot_telegram.sh" ]; then bash modules/bot_telegram.sh; else echo "Falta el archivo modules/bot_telegram.sh"; sleep 1.5; fi
    clear
    ;;

7|07|8|08|9|09|10|12|13|14)
    clear
    echo "Módulo en desarrollo..."
    sleep 2
    clear
    ;;

0)
    clear
    exit 0
    ;;

*)
    ;;

esac
done