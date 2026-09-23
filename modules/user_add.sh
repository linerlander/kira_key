#!/bin/bash

# Limpiar pantalla al entrar
clear

# ========== PALETA DE COLORES EXACTA DE LAS CAPTURAS ==========
Y=$'\033[1;33m' # Amarillo
C=$'\033[1;36m' # Cian / Azul claro
W=$'\033[1;37m' # Blanco brillante
D=$'\033[0;90m' # Gris bordes y barras
G=$'\033[1;32m' # Verde
R=$'\033[1;31m' # Rojo
N=$'\033[0m'    # Reset

# ===== CAPTURA DE MÉTRICAS DEL SISTEMA =====
RAM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}')
[ -z "$RAM" ] && RAM="135"

CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2+$4)}')
[ -z "$CPU" ] && CPU="90"

HORA=$(date +'%H:%M:%S')
LATENCIA="45ms"

# ===== ENCABEZADO PERFECTAMENTE ALINEADO =====
printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
printf "%b│%b  [ %b⚡ KIRA-SSH%b ]  🔐 %bCREADOR DE CUENTAS SSH | KIRA VIP%b                  %b│%b\n" "$D" "$C" "$N" "$Y" "$N" "$D" "$N"
printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
printf "%b│%b %b▶ M LIBRE:%b %b%-4s%b %b|%b %b▶ CPU:%b %b%-3s%%%b %b|%b %b▶ HORA:%b %b%-8s%b %b|%b %b▶ LATENCIA:%b %b%-5s%b     %b│%b\n" \
  "$D" "$C" "$N" "$W" "${RAM}M" "$N" "$D" "$C" "$N" "$W" "$CPU" "$N" "$D" "$C" "$N" "$W" "$HORA" "$N" "$D" "$C" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"
echo ""

# ===== OPCIONES DEL MÓDULO =====
printf " [%b01%b] ⚡ GENERAR CUENTA DEMO                        %b⚡ (TEMPORAL)%b\n" "$Y" "$N" "$C" "$N"
printf " [%b02%b] 👤 CREAR USUARIO NORMAL                       %b👤 (OFICIAL)%b\n" "$Y" "$N" "$G" "$N"
echo ""
printf "%b─────────────────────────────────────────────────────────────────────────────%b\n" "$D" "$N"
printf " [%b0%b] %b►%b [ REGRESAR ]                                 %bÚLTIMO REFRESH: %s%b\n" "$R" "$N" "$R" "$N" "$D" "$HORA" "$N"
printf "%b─────────────────────────────────────────────────────────────────────────────%b\n" "$D" "$N"
echo ""

# ===== CAPTURA DE OPCIÓN =====
read -p "$(echo -e " ${C}KIRA@Servidor:~/Usuarios$ ${N}${W}► Opción: ${N}")" opcion_sub

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