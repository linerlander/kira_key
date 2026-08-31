#!/bin/bash

# ========= COLORES Y ESTILOS =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[1;33m'
R='\033[38;5;196m'
C='\033[1;36m'
G='\033[1;32m'
B='\033[38;5;75m'
N='\033[0m'

# ========= CONFIGURACIÓN DE INTERFAZ =========
tput civis
clear

# Limpiar cursor y restaurar al salir por interrupción
trap 'tput cnorm; clear; exit 0' INT TERM

IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
[ -z "$IFACE" ] && IFACE=$(ls /sys/class/net/ | grep -v 'lo' | head -n1)

# Función para barras de progreso estilizadas
bar() {
    local percent=$1
    local color=$2
    local size=15
    local filled=$((percent * size / 100))
    local empty=$((size - filled))

    [ $filled -gt $size ] && filled=$size
    [ $empty -lt 0 ] && empty=0

    printf "${color}["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "·"; done
    printf "]${N} %3d%%" "$percent"
}

# Obtener lectura inicial de red
if [ -d "/sys/class/net/$IFACE/statistics" ]; then
    RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
    TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
else
    RX1=0; TX1=0
fi

while true; do
    tput cup 0 0

    # 1. CPU
    CPU_IDLE=$(top -bn1 | grep -i "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | tr ',' '.')
    [ -z "$CPU_IDLE" ] && CPU_IDLE=0
    CPU=$(printf "%.0f" "$(echo "100 - $CPU_IDLE" | bc 2>/dev/null || echo 0)")
    
    # Color dinámico CPU
    CPU_COL="$G"
    [ $CPU -gt 60 ] && CPU_COL="$Y"
    [ $CPU -gt 85 ] && CPU_COL="$R"

    # 2. RAM
    read RAM_USED RAM_TOTAL < <(free -m | awk '/Mem:/ {print $3, $2}')
    if [ -n "$RAM_TOTAL" ] && [ "$RAM_TOTAL" -gt 0 ]; then
        RAM_P=$((RAM_USED * 100 / RAM_TOTAL))
    else
        RAM_P=0
    fi
    RAM_COL="$G"
    [ $RAM_P -gt 70 ] && RAM_COL="$Y"
    [ $RAM_P -gt 90 ] && RAM_COL="$R"

    # 3. Red (Tasas de transferencia)
    if [ -d "/sys/class/net/$IFACE/statistics" ]; then
        RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
        TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
    else
        RX2=$RX1; TX2=$TX1
    fi

    RX_DIFF=$((RX2 - RX1))
    TX_DIFF=$((TX2 - TX1))
    RX1=$RX2
    TX1=$TX2

    # Formatear velocidades (KB/s o MB/s)
    if [ $RX_DIFF -gt 1048576 ]; then
        RX_RATE=$(printf "%.1f MB/s" "$(echo "scale=1; $RX_DIFF / 1048576" | bc)")
    else
        RX_RATE=$(printf "%d KB/s" "$((RX_DIFF / 1024))")
    fi

    if [ $TX_DIFF -gt 1048576 ]; then
        TX_RATE=$(printf "%.1f MB/s" "$(echo "scale=1; $TX_DIFF / 1048576" | bc)")
    else
        TX_RATE=$(printf "%d KB/s" "$((TX_DIFF / 1024))")
    fi

    # 4. Uptime del Sistema
    UPTIME_SYS=$(uptime -p | sed 's/up //')

    # ========= RENDERIZADO DE LA UI =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}               ⚡ MONITOR EN TIEMPO REAL ⚡          ${C}║${N}"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    echo -e "${C}║${W} Uptime: ${Y}${UPspace:-$UPTIME_SYS}                  ${C}║${N}"
    echo -e "${C}⟠─────────────────────────────────────────────────────⟠${N}"
    
    # Métricas con barras
    printf "${C}║${N} ${W}CPU:${N}  "
    bar $CPU "$CPU_COL"
    echo -e "                 ${C}       ║${N}"

    printf "${C}║${N} ${W}RAM:${N}  "
    bar $RAM_P "$RAM_COL"
    echo -e " ${D}(${RAM_USED}M/${RAM_TOTAL}M)${N}      ${C}     ║${N}"

    echo -e "${C}⟠─────────────────────────────────────────────────────⟠${N}"
   printf   "${C}║${N} ${W}RED [${B}%-5s${W}] ↓ ${G}%-9s${W} | ↑ ${G}%-9s${N}               ${C}║${N}\n" "$IFACE" "$RX_RATE" "$TX_RATE"   
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    echo -e "${C}║${W} TOP 5 PROCESOS MÁS CONSUMIDORES                     ${C}║${N}"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    echo -e "${C}║${D} PID    PROCESO          %CPU    %MEM           ${C}     ║${N}"

    # Top procesos limpios (5 líneas exactas)
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 | tail -n 5 | while read -r pid comm cpu_use mem_use; do
        printf "${C}║${N} ${W}%-6s ${C}%-16s ${Y}%-7s ${G}%-7s${N}           ${C}  ║${N}\n" "$pid" "${comm:0:15}" "${cpu_use}%" "${mem_use}%"
    done

    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    echo -e "${C}║${N} ${R}[0]${N} ${W} SALIR DEL MONITOR                              ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"

    # Captura de tecla sin interrumpir el refresco fluido de 1 segundo
    read -t 1 -n 1 key
    if [[ "$key" == "0" ]]; then
        tput cnorm
        clear
        break
    fi
done