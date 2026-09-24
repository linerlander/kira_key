#!/bin/bash

# Evita que señales externas cierren el script por error
trap '' INT TERM

# ========== PALETA DE COLORES ANSI ==========
Y=$'\033[1;33m' # Amarillo
C=$'\033[1;36m' # Cian
W=$'\033[1;37m' # Blanco brillante
D=$'\033[0;90m' # Gris (bordes)
G=$'\033[1;32m' # Verde
R=$'\033[1;31m' # Rojo
N=$'\033[0m'    # Reset

PROMPT_BASE="${C}KIRA@Servidor:~/Usuarios$ ${N}${W}►${N}"

obtener_ip() {
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$IP" ] && IP="127.0.0.1"
    echo "$IP"
}

obtener_puerto() {
    PORT=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    [ -z "$PORT" ] && PORT=22
    echo "$PORT"
}

obtener_metricas() {
    RAM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}')
    [ -z "$RAM" ] && RAM=0

    if [ -f /proc/stat ]; then
        read -r _ u1 n1 s1 i1 io1 ir1 sir1 st1 _ < /proc/stat
        tot1=$((u1 + n1 + s1 + i1 + io1 + ir1 + sir1 + st1))
        idl1=$((i1 + io1))
        
        sleep 0.1
        
        read -r _ u2 n2 s2 i2 io2 ir2 sir2 st2 _ < /proc/stat
        tot2=$((u2 + n2 + s2 + i2 + io2 + ir2 + sir2 + st2))
        idl2=$((i2 + io2))
        
        dtot=$((tot2 - tot1))
        didl=$((idl2 - idl1))
        
        if [ "$dtot" -gt 0 ]; then
            CPU=$((100 * (dtot - didl) / dtot))
        else
            CPU=0
        fi
    else
        CPU=0
    fi
    [ "$CPU" -lt 0 ] && CPU=0
    [ "$CPU" -gt 100 ] && CPU=100

    HORA=$(date +'%H:%M:%S')

    LATENCIA=$(ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'/' 'END {printf "%.0fms", $5}')
    [ -z "$LATENCIA" ] && LATENCIA="N/A"
}

# Limpiamos pantalla una vez al iniciar
clear

# ===== BUCLE PRINCIPAL CON RELOJ EN TIEMPO REAL (SIN HILOS CONGELANTES) =====
while true; do
    obtener_metricas

    # Coloca el cursor en la esquina superior izquierda sin parpadeos molestos de pantalla completa
    printf "\033[H"

    printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
    printf "%b│%b %b[ ⚡ KIRA-SSH ]%b  🔐 %bADMINISTRADOR DE USUARIOS SSH | KIRA%b                  %b│%b\n" "$D" "$N" "$C" "$N" "$Y" "$N" "$D" "$N"
    printf "%b│%b %bVERSIÓN 2.5 (Premium)%b | LICENCIA: %bACTIVA%b %b(Expiración: 2026-12-31)%b      %b│%b\n" "$D" "$N" "$D" "$N" "$G" "$N" "$D" "$N" "$D" "$N"
    printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
    printf "%b│%b %b▶ RAM LIBRE:%b %b%-6s%b %b│%b %b▶ CPU:%b %b%-4s%b %b│%b %b▶ HORA:%b %b%-8s%b %b│%b %b▶ LAT:%b %b%-6s%b %b│%b\n" \
        "$D" "$N" "$C" "$N" "$W" "${RAM}MB" "$N" "$D" "$N" \
        "$C" "$N" "$W" "${CPU}%" "$N" "$D" "$N" \
        "$C" "$N" "$W" "$HORA" "$N" "$D" "$N" \
        "$C" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
    printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"
    printf "\n"

    printf " [%b01%b] GENERAR CUENTA DEMO (TEMPORAL)\n" "$Y" "$N"
    printf " [%b02%b] CREAR USUARIO NORMAL\n" "$Y" "$N"
    echo ""
    echo -e "${D}─────────────────────────────────────────────────────────────────────────────${N}"
    printf " [%b0%b] %b►%b [ REGRESAR ]\n" "$R" "$N" "$R" "$N"
    echo -e "${D}─────────────────────────────────────────────────────────────────────────────${N}"
    echo ""

    echo -ne " ${PROMPT_BASE} ${W}Opción: ${N}"
    
    # Lee con un timeout de 1 segundo exacto. Si no escribes nada, el bucle se repite solo actualizando la hora y métricas en vivo.
    read -t 1 opcion_sub
    if [ $? -ne 0 ]; then
        continue
    fi

    case "$opcion_sub" in
        1|01)
            clear
            rand=$(shuf -i 100-999 -n 1)
            user="Kira-2025$rand"
            pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)

            while true; do
                echo -ne " ${PROMPT_BASE} ${W}Tiempo de duración (30m/2h/1d): ${N}"
                read -r tiempo
                
                if [[ "$tiempo" == "0" ]]; then
                    echo -e "\n ${R}[!] Cancelado.${N}"
                    sleep 1
                    break
                fi

                if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
                    break
                else
                    echo -e " ${R}[!] Formato inválido. Usa m (minutos), h (horas) o d (días).${N}\n"
                fi
            done

            [ "$tiempo" == "0" ] && { clear; continue; }

            echo -ne " ${PROMPT_BASE} ${W}Límite de conexiones [Default 1]: ${N}"
            read -r limit
            if [[ "$limit" == "0" ]]; then
                echo -e "\n ${R}[!] Cancelado.${N}"
                sleep 1
                clear
                continue
            fi
            [ -z "$limit" ] && limit=1

            cantidad=$(echo "$tiempo" | grep -oE '[0-9]+')
            unidad=$(echo "$tiempo" | grep -oE '[smhd]')

            case "$unidad" in
                m) tipo_tiempo="$cantidad minutes" ;;
                h) tipo_tiempo="$cantidad hours" ;;
                d) tipo_tiempo="$cantidad days" ;;
                *) tipo_tiempo="1 days" ;;
            esac

            exp_date=$(date -d "+$tipo_tiempo" +%Y-%m-%d 2>/dev/null)
            [ -z "$exp_date" ] && exp_date=$(date +%Y-%m-%d)

            useradd -M -s /bin/false "$user" 2>/dev/null
            echo "$user:$pass" | chpasswd 2>/dev/null
            passwd -u "$user" &>/dev/null
            chage -E "$exp_date" "$user" 2>/dev/null

            mkdir -p /etc/kira/limits /etc/kira/expire /etc/kira/pass
            echo "$limit" > /etc/kira/limits/$user
            echo "$exp_date" > /etc/kira/expire/$user
            echo "$pass" > /etc/kira/pass/$user

            IP=$(obtener_ip)
            PORT=$(obtener_puerto)

            directo="${IP}:${PORT}@${user}:${pass}"
            proxy="${IP}:80@${user}:${pass}"

            clear
            echo -e "${D}╔══════════════════════════════════════════════════╗${N}"
            echo -e "${D}║${Y}         KIRA PANEL - CUENTA DEMO                 ${D}║${N}"
            echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
            printf "${D}║${N} ${R}Ip Server   :${N} %-35s ${D}║${N}\n" "$IP"
            printf "${D}║${N} ${R}Usuario     :${N} %-35s ${D}║${N}\n" "$user"
            printf "${D}║${N} ${R}Contraseña  :${N} ${W}%-35s${N} ${D}║${N}\n" "$pass"
            printf "${D}║${N} ${R}Puerto Ssh  :${N} %-35s ${D}║${N}\n" "$PORT"
            printf "${D}║${N} ${R}Límite Ssh  :${N} %-35s ${D}║${N}\n" "$limit dispo..."
            printf "${D}║${N} ${R}Validez     :${N} %-35s ${D}║${N}\n" "$tiempo (Expira: $exp_date)"
            echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
            echo -e "${D}║${N} ${G}DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):${N}          ${D}║${N}"
            echo -e "${D}║${N}                                                  ${D}║${N}"
            printf "${D}║${N} Direc: ${Y}%-42s${N} ${D}║${N}\n" "$directo"
            printf "${D}║${N} Proxy: ${Y}%-42s${N} ${D}║${N}\n" "$proxy"
            echo -e "${D}╚══════════════════════════════════════════════════╝${N}"

            echo "$user $pass DEMO $limit $(date)" >> /etc/kira/users.log

            echo ""
            echo -ne " ${PROMPT_BASE} ${W}Presiona Enter para continuar...${N}"
            read -r
            clear
            ;;

        2|02)
            clear
            while true; do
                echo -ne " ${PROMPT_BASE} ${W}Nombre de usuario: ${N}"
                read -r user

                if [[ "$user" == "0" ]]; then
                    echo -e "\n ${R}[!] Cancelado.${N}"
                    sleep 1
                    break
                fi

                if [[ -z "$user" ]]; then
                    echo -e " ${R}[!] El usuario no puede estar vacío.${N}\n"
                elif id "$user" &>/dev/null; then
                    echo -e " ${R}[!] El usuario '$user' ya existe.${N}\n"
                elif [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    echo -e " ${R}[!] Nombre inválido. Usa letras y números.${N}\n"
                else
                    break
                fi
            done

            [ "$user" == "0" ] && { clear; continue; }

            echo -ne " ${PROMPT_BASE} ${W}Contraseña (Enter = autogenerar): ${N}"
            read -r pass
            if [[ "$pass" == "0" ]]; then
                echo -e "\n ${R}[!] Cancelado.${N}"
                sleep 1
                clear
                continue
            fi

            if [[ -z "$pass" ]]; then
                pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)
            fi

            while true; do
                echo -ne " ${PROMPT_BASE} ${W}Días de validez (Ej: 30): ${N}"
                read -r dias

                if [[ "$dias" == "0" ]]; then
                    echo -e "\n ${R}[!] Cancelado.${N}"
                    sleep 1
                    break
                fi

                if [[ "$dias" =~ ^[0-9]+$ ]] && [ "$dias" -gt 0 ]; then
                    break
                else
                    echo -e " ${R}[!] Ingresa un número de días válido.${N}\n"
                fi
            done

            [ "$dias" == "0" ] && { clear; continue; }

            echo -ne " ${PROMPT_BASE} ${W}Límite de conexiones [Default 1]: ${N}"
            read -r limit
            if [[ "$limit" == "0" ]]; then
                echo -e "\n ${R}[!] Cancelado.${N}"
                sleep 1
                clear
                continue
            fi
            [ -z "$limit" ] && limit=1

            exp_date=$(date -d "+$dias days" +%Y-%m-%d 2>/dev/null)
            [ -z "$exp_date" ] && exp_date=$(date +%Y-%m-%d)

            useradd -M -s /bin/false "$user" 2>/dev/null
            echo "$user:$pass" | chpasswd 2>/dev/null
            passwd -u "$user" &>/dev/null
            chage -E "$exp_date" "$user" 2>/dev/null

            mkdir -p /etc/kira/limits /etc/kira/expire /etc/kira/pass
            echo "$limit" > /etc/kira/limits/$user
            echo "$exp_date" > /etc/kira/expire/$user
            echo "$pass" > /etc/kira/pass/$user

            IP=$(obtener_ip)
            PORT=$(obtener_puerto)

            directo="${IP}:${PORT}@${user}:${pass}"
            proxy="${IP}:80@${user}:${pass}"

            clear
            echo -e "${D}╔══════════════════════════════════════════════════╗${N}"
            echo -e "${D}║${G}        KIRA PANEL - USUARIO NORMAL               ${D}║${N}"
            echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
            printf "${D}║${N} ${R}Ip Server   :${N} %-35s ${D}║${N}\n" "$IP"
            printf "${D}║${N} ${R}Usuario     :${N} %-35s ${D}║${N}\n" "$user"
            printf "${D}║${N} ${R}Contraseña  :${N} ${W}%-35s${N} ${D}║${N}\n" "$pass"
            printf "${D}║${N} ${R}Puerto Ssh  :${N} %-35s ${D}║${N}\n" "$PORT"
            printf "${D}║${N} ${R}Límite Ssh  :${N} %-35s ${D}║${N}\n" "$limit conex."
            printf "${D}║${N} ${R}Validez     :${N} %-35s ${D}║${N}\n" "$dias días (Expira: $exp_date)"
            echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
            echo -e "${D}║${N} ${G}DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):${N}          ${D}║${N}"
            echo -e "${D}║${N}                                                  ${D}║${N}"
            printf "${D}║${N} Direc: ${Y}%-42s${N} ${D}║${N}\n" "$directo"
            printf "${D}║${N} Proxy: ${Y}%-42s${N} ${D}║${N}\n" "$proxy"
            echo -e "${D}╚══════════════════════════════════════════════════╝${N}"

            echo "$user $pass NORMAL $limit $(date)" >> /etc/kira/users.log

            echo ""
            echo -ne " ${PROMPT_BASE} ${W}Presiona Enter para continuar...${N}"
            read -r
            clear
            ;;

        0)
            clear
            exit 0
            ;;

        *)
            echo -e "\n ${R}[!] Opción no válida.${N}"
            sleep 1
            clear
            ;;
    esac
done