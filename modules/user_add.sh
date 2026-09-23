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

    # Redibujar interfaz del encabezado
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
    printf " [%b02%b] 🙋‍♂️ CREAR USUARIO NORMAL                       🙋‍♂️ %b(OFICIAL)%b\033[K\n" "$Y" "$N" "$G" "$N"
    echo ""
    printf "%b─────────────────────────────────────────────────────────────────────────────%b\033[K\n" "$D" "$N"
    printf " [%b0%b] %b►%b [ REGRESAR ]                                 %bÚLTIMO REFRESH: %s%b\033[K\n" "$R" "$N" "$R" "$N" "$D" "$HORA" "$N"
    printf "%b─────────────────────────────────────────────────────────────────────────────%b\033[K\n" "$D" "$N"
    echo ""

    # Captura de opción con refresco de 1 segundo
    read -t 1 -p "$(echo -e " ${C}KIRA@Servidor:~/Usuarios$ ${N}${W}► Opción: ${N}\033[K")" opcion_sub

    if [ -n "$opcion_sub" ]; then
        case $opcion_sub in
            1|01)
                clear
                echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
                echo -e " ${Y}⚡ CREAR CUENTA DEMO TEMPORAL${N}"
                echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

                # Autogeneración de usuario y contraseña
                rand=$(shuf -i 100-999 -n 1)
                user="Kira-2025$rand"
                pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)

                echo -e " ${C}▶ Usuario autogenerado:${N} ${W}$user${N}\n"

                # Validación de tiempo ingresado
                while true; do
                    read -p " ► Tiempo de duración (Ej: 30m / 2h / 1d): " tiempo
                    if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
                        break
                    else
                        echo -e " ${R}❌ Formato inválido. Usa m (minutos), h (horas), d (días).${N}"
                    fi
                done

                read -p " ► Límite de conexiones (Default 1): " limit
                [ -z "$limit" ] && limit=1

                # Conversión de tiempo para date
                cantidad=$(echo "$tiempo" | grep -oE '[0-9]+')
                unidad=$(echo "$tiempo" | grep -oE '[smhd]')

                case "$unidad" in
                    m) tipo_tiempo="$cantidad minutes" ;;
                    h) tipo_tiempo="$cantidad hours" ;;
                    d) tipo_tiempo="$cantidad days" ;;
                    *) tipo_tiempo="1 days" ;;
                esac

                # Creación en sistema operativo
                exp_date=$(date -d "+$tipo_tiempo" +%Y-%m-%d)
                useradd -M -s /bin/false "$user" 2>/dev/null
                echo "$user:$pass" | chpasswd 2>/dev/null
                passwd -u "$user" &>/dev/null
                chage -E "$exp_date" "$user" 2>/dev/null

                # Persistencia en base de datos KIRA
                mkdir -p /etc/kira/limits /etc/kira/expire /etc/kira/pass
                echo "$limit" > /etc/kira/limits/$user
                echo "$exp_date" > /etc/kira/expire/$user
                echo "$pass" > /etc/kira/pass/$user

                # Obtención de IP y Puerto SSH
                IP=$(curl -s ifconfig.me)
                PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
                [ -z "$PORT" ] && PORT=22

                directo="${IP}:${PORT}@${user}:${pass}"
                proxy="${IP}:80@${user}:${pass}"

                clear
                echo -e "${D}╔══════════════════════════════════════════════════╗${N}"
                echo -e "${D}║${Y}          ⚡ KIRA PANEL - CUENTA DEMO ⚡          ${D}║${N}"
                echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
                printf "${D}║${N} ${R}🖥️ Ip Server   :${N} %-31s ${D}║${N}\n" "$IP"
                printf "${D}║${N} ${R}👤 Usuario     :${N} %-31s ${D}║${N}\n" "$user"
                printf "${D}║${N} ${R}🔑 Contraseña  :${N} ${W}%-31s${N} ${D}║${N}\n" "$pass"
                printf "${D}║${N} ${R}📡 Puerto Ssh  :${N} %-31s ${D}║${N}\n" "$PORT"
                printf "${D}║${N} ${R}📊 Límite Ssh  :${N} %-31s ${D}║${N}\n" "$limit dispo..."
                printf "${D}║${N} ${R}⏳ Validez     :${N} %-31s ${D}║${N}\n" "$tiempo (Expira: $exp_date)"
                echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
                echo -e "${D}║${N} ${G}📋 DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):${N}       ${D}║${N}"
                echo -e "${D}║${N}                                                  ${D}║${N}"
                printf "${D}║${N} 🔗 Direc: ${Y}%-38s${N} ${D}║${N}\n" "$directo"
                printf "${D}║${N} 🖥️ Proxy: ${Y}%-38s${N} ${D}║${N}\n" "$proxy"
                echo -e "${D}╚══════════════════════════════════════════════════╝${N}"

                echo "$user $pass DEMO $limit $(date)" >> /etc/kira/users.log

                echo ""
                read -p "Presiona Enter para continuar..."
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