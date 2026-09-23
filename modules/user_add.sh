#!/bin/bash

# ========== PALETA DE COLORES ANSI EXACTA ==========
Y=$'\033[1;33m' # Amarillo
C=$'\033[1;36m' # Cian / Azul claro
W=$'\033[1;37m' # Blanco brillante
D=$'\033[0;90m' # Gris (bordes y textos secundarios)
G=$'\033[1;32m' # Verde
R=$'\033[1;31m' # Rojo
N=$'\033[0m'    # Reset

# Limpiar pantalla solo UNA VEZ al iniciar
clear

# ===== BUCLE CONTINUO SIN PARPADEO =====
while true; do
    # Captura de métricas en vivo
    RAM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}')
    [ -z "$RAM" ] && RAM="0"

    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2+$4)}')
    [ -z "$CPU" ] && CPU="0"

    HORA=$(date +'%H:%M:%S')

    # Medición rápida de latencia
    PING_RES=$(ping -c 1 -W 1 1.1.1.1 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
    if [ -n "$PING_RES" ]; then
        LATENCIA="${PING_RES%.*}ms"
    else
        LATENCIA="N/A"
    fi

    # Reposicionar cursor arriba sin limpiar la pantalla (Evita el parpadeo)
    printf "\033[1;1H"

    # Redibujar interfaz
    printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
    printf "%b│%b  %b[ %b⚡ KIRA-SSH%b ]%b  🔐 %bCREADOR DE CUENTAS SSH | KIRA VIP%b                    %b│%b\n" "$D" "$N" "$D" "$C" "$D" "$N" "$Y" "$N" "$D" "$N"
    printf "%b│%b  %bVERSIÓN 2.5 (Premium) | LICENCIA: %bACTIVA%b %b(Expiración: 2026-12-31)%b        %b│%b\n" "$D" "$N" "$D" "$G" "$D" "$D" "$N" "$D" "$N"
    printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
    printf "%b│%b %b▶ M LIBRE:%b %b%-4s%b %b|%b %b▶ CPU:%b %b%-3s%%%b %b|%b %b▶ HORA:%b %b%-8s%b %b|%b %b▶ LATENCIA:%b %b%-5s%b      %b│%b\n" \
      "$D" "$N" "$C" "$N" "$W" "${RAM}M" "$N" "$D" "$N" "$C" "$N" "$W" "$CPU" "$N" "$D" "$N" "$C" "$N" "$W" "$HORA" "$N" "$D" "$N" "$C" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
    printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"
    echo ""

    # Opciones del menú
    printf " [%b01%b] 🚀 GENERAR CUENTA DEMO                        🚀 %b(TEMPORAL)%b\033[K\n" "$Y" "$N" "$C" "$N"
    printf " [%b02%b] 🙋‍♂️ CREAR USUARIO NORMAL                       %b🙋‍♂️ (OFICIAL)%b\033[K\n" "$Y" "$N" "$G" "$N"
    echo ""
    printf "%b─────────────────────────────────────────────────────────────────────────────%b\033[K\n" "$D" "$N"
    printf " [%b0%b] %b►%b [ REGRESAR ]                                 %bÚLTIMO REFRESH: %s%b\033[K\n" "$R" "$N" "$R" "$N" "$D" "$HORA" "$N"
    printf "%b─────────────────────────────────────────────────────────────────────────────%b\033[K\n" "$D" "$N"
    echo ""

    # Captura de opción con refresco de 1 segundo
    read -t 1 -p "$(echo -e " ${C}KIRA@Servidor:~/Usuarios$ ${N}${W}► Opción: ${N}\033[K")" opcion_sub

    # Si el usuario ingresa una opción, procesarla
    if [ -n "$opcion_sub" ]; then
        case $opcion_sub in
           1|01)
            echo -e "\n${G}[+] Cargando módulo Demo...${N}"
            sleep 1

            # Verificar la ubicación del script user_demo.sh y ejecutarlo
            if [ -f "./user_demo.sh" ]; then
                bash ./user_demo.sh
            elif [ -f "./modules/user_demo.sh" ]; then
                bash ./modules/user_demo.sh
            elif [ -f "/etc/kira/modules/user_demo.sh" ]; then
                bash /etc/kira/modules/user_demo.sh
            else
                echo -e " ${R}❌ Error: No se encontró el archivo user_demo.sh${N}"
                sleep 2
            fi

            clear
            ;;
            2|02)
                echo -e "\n${G}[+] Generando usuario Oficial...${N}"
                sleep 2
                clear
                ;;
            0)
                clear
                break
                ;;
            *)
                echo -e "\n${R}[!] Opción no válida.${N}"
                sleep 1
                clear
                ;;
        esac
    fi
done