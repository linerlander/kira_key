#!/bin/bash

# ========= PALETA DE COLORES (ENFOQUE MORADO / PURPLE) =========
P=$'\033[1;35m'  # Morado brillante / Purple
D_P=$'\033[0;35m' # Morado oscuro
W=$'\033[1;37m'   # Blanco
D=$'\033[0;90m'   # Gris / Bordes
C=$'\033[1;36m'   # Cian
G=$'\033[1;32m'   # Verde
R=$'\033[1;31m'   # Rojo
N=$'\033[0m'      # Reset

clear

# ===== MÉTRICAS EN TIEMPO REAL =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')
HORA=$(date +'%H:%M:%S')
LATENCIA="45ms"

# ===== ENCABEZADO MORADO =====
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  %b[ ⚡ KIRA-SSH ]%b  %b🔐 CREADOR DE CUENTAS SSH | KIRA VIP%b                  %b│%b\n" "$D" "$N" "$P" "$N" "$P" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b▶ M LIBRE:%b %b%-4s%b %b|%b %b▶ CPU:%b %b%-3s%%%b %b|%b %b▶ HORA:%b %b%-8s%b %b|%b %b▶ LATENCIA:%b %b%-5s%b     %b│%b\n" \
  "$D" "$N" "$P" "$N" "$W" "${RAM}M" "$N" "$D" "$N" "$P" "$N" "$W" "$CPU" "$N" "$D" "$N" "$P" "$N" "$W" "$HORA" "$N" "$D" "$N" "$P" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"
echo ""

# ===== OPCIONES DEL MENÚ =====
printf " %b[01]%b ⚡ GENERAR CUENTA DEMO                        %b⚡ (TEMPORAL)%b\n" "$P" "$N" "$C" "$N"
printf " %b[02]%b 👤 CREAR USUARIO NORMAL                       %b👤 (OFICIAL)%b\n" "$P" "$N" "$G" "$N"
echo ""
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
printf " %b[0]%b %b►%b %b[ REGRESAR ]%b                                 %bÚLTIMO REFRESH: %s%b\n" "$R" "$N" "$R" "$N" "$W" "$N" "$D" "$HORA" "$N"
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$D" "$N"
echo ""
printf " %bKIRA@Servidor:~/Usuarios$%b %b► Opción: %b" "$P" "$N" "$W" "$N"