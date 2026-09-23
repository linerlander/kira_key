#!/bin/bash

# Limpiar pantalla al entrar
clear

# ========== PALETA DE COLORES ANSI (ESTILO MORADO) ==========
P=$'\033[1;35m'   # Morado brillante
D_P=$'\033[0;35m' # Morado oscuro
W=$'\033[1;37m'   # Blanco
D=$'\033[0;90m'   # Gris bordes
C=$'\033[1;36m'   # Cian
G=$'\033[1;32m'   # Verde
R=$'\033[1;31m'   # Rojo
N=$'\033[0m'      # Reset

# ===== CAPTURA DE MÉTRICAS DEL SISTEMA =====
RAM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}')
[ -z "$RAM" ] && RAM="135"

CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2+$4)}')
[ -z "$CPU" ] && CPU="0"

HORA=$(date +'%H:%M:%S')
LATENCIA="45ms"

# ===== ENCABEZADO CON MÉTRICAS =====
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b🔐 CREADOR DE CUENTAS SSH | KIRA VIP%b                  %b│%b\n" "$D" "$N" "$P" "$N" "$P" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b▶ M LIBRE:%b %b%-4s%b %b|%b %b▶ CPU:%b %b%-3s%%%b %b|%b %b▶ HORA:%b %b%-8s%b %b|%b %b▶ LATENCIA:%b %b%-5s%b     %b│%b\n" \
  "$D" "$N" "$P" "$N" "$W" "${RAM}M" "$N" "$D" "$N" "$P" "$N" "$W" "$CPU" "$N" "$D" "$N" "$P" "$N" "$W" "$HORA" "$N" "$D" "$N" "$P" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"
echo ""

# ===== OPCIONES DEL MÓDULO =====
printf " %b[01]%b ⚡ GENERAR CUENTA DEMO                        %b⚡ (TEMPORAL)%b\n" "$P" "$N" "$C" "$N"
printf " %b[02]%b 👤 CREAR USUARIO NORMAL                       %b👤 (OFICIAL)%b\n" "$P" "$N" "$G" "$N"
echo ""
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
printf " %b[0]%b %b►%b %b[ REGRESAR ]%b                                 %bÚLTIMO REFRESH: %s%b\n" "$R" "$N" "$R" "$N" "$W" "$N" "$D" "$HORA" "$N"
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
echo ""

# ===== CAPTURA DE OPCCIÓN =====
read -p "$(echo -e " ${P}KIRA@Servidor:~/Usuarios$ ${N}${W}► Opción: ${N}")" opcion_sub

case $opcion_sub in
    1|01)
        echo -e "\n${G}[+] Generando cuenta Demo...${N}"
        sleep 2
        ;;
    2|02)
        echo -e "\n${G}[+] Generando usuario Oficial...${N}"
        sleep 2
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "\n${R}[!] Opción no válida.${N}"
        sleep 1.5
        ;;
esac