#!/bin/bash

# ========== PALETA DE COLORES ANSI EXACTA ==========
Y=$'\033[1;33m' # Amarillo
C=$'\033[1;36m' # Cian / Azul claro
W=$'\033[1;37m' # Blanco brillante
D=$'\033[0;90m' # Gris (bordes y textos secundarios)
G=$'\033[1;32m' # Verde
R=$'\033[1;31m' # Rojo
N=$'\033[0m'    # Reset

# Obtención rápida de IP sin bloqueos
obtener_ip() {
    IP=$(timeout 2 curl -s ifconfig.me 2>/dev/null)
    [ -z "$IP" ] && IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$IP" ] && IP="127.0.0.1"
    echo "$IP"
}

# Obtención rápida de Puerto SSH
obtener_puerto() {
    PORT=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    [ -z "$PORT" ] && PORT=22
    echo "$PORT"
}

# Encabezado principal del sistema
dibujar_encabezado() {
    RAM=$(free -m 2>/dev/null | awk '/Mem:/ {print $4}')
    [ -z "$RAM" ] && RAM="0"

    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2+$4)}')
    [ -z "$CPU" ] && CPU="0"

    HORA=$(date +'%H:%M:%S')
    LATENCIA="30ms"

    printf "\033[1;1H\033[J"
    printf "%b┌───────────────────────────────────────────────────────────────────────────┐%b\n" "$D" "$N"
    printf "%b│%b  %b[ %b⚡ KIRA-SSH%b ]%b  🔐 %bCREADOR DE CUENTAS SSH | KIRA VIP%b                    %b│%b\n" "$D" "$N" "$D" "$C" "$D" "$N" "$Y" "$N" "$D" "$N"
    printf "%b│%b  %bVERSIÓN 2.5 (Premium) | LICENCIA: %bACTIVA%b %b(Expiración: 2026-12-31)%b        %b│%b\n" "$D" "$N" "$D" "$G" "$D" "$D" "$N" "$D" "$N"
    printf "%b├───────────────────────────────────────────────────────────────────────────┤%b\n" "$D" "$N"
    printf "%b│%b %b▶ M LIBRE:%b %b%-4s%b %b|%b %b▶ CPU:%b %b%-3s%%%b %b|%b %b▶ HORA:%b %b%-8s%b %b|%b %b▶ LATENCIA:%b %b%-5s%b      %b│%b\n" \
      "$D" "$N" "$C" "$N" "$W" "${RAM}M" "$N" "$D" "$N" "$C" "$N" "$W" "$CPU" "$N" "$D" "$N" "$C" "$N" "$W" "$HORA" "$N" "$D" "$N" "$C" "$N" "$W" "$LATENCIA" "$N" "$D" "$N"
    printf "%b└───────────────────────────────────────────────────────────────────────────┘%b\n" "$D" "$N"
    echo ""
}

# ===== BUCLE PRINCIPAL =====
while true; do
    clear
    dibujar_encabezado

    printf " [%b01%b] 🚀 GENERAR CUENTA DEMO                        🚀 %b(TEMPORAL)%b\n" "$Y" "$N" "$C" "$N"
    printf " [%b02%b] 🙋‍♂️ CREAR USUARIO NORMAL                       🙋‍♂️\n" "$Y" "$N"
    echo ""
    printf "%b─────────────────────────────────────────────────────────────────────────────%b\n" "$D" "$N"
    printf " [%b0%b] %b►%b [ REGRESAR ]\n" "$R" "$N" "$R" "$N"
    printf "%b─────────────────────────────────────────────────────────────────────────────%b\n" "$D" "$N"
    echo ""

    read -r -p "$(echo -e " ${C}KIRA@Servidor:~/Usuarios$ ${N}${W}► Opción: ${N}")" opcion_sub

    case $opcion_sub in
        1|01)
            # =========================================================
            # 1. FLUJO GENERAR CUENTA DEMO
            # =========================================================
            clear
            dibujar_encabezado

            echo -e "${D}┌─────────────────────────────────────────────────────────┐${N}"
            echo -e "${D}│${Y}                🚀 GENERAR CUENTA DEMO                   ${D}│${N}"
            echo -e "${D}└─────────────────────────────────────────────────────────┘${N}"
            echo -e " ${D}(Presiona 0 para cancelar en cualquier momento)${N}\n"

            rand=$(shuf -i 100-999 -n 1)
            user="Kira-2025$rand"
            pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)

            echo -e " ${C}👤 Usuario autogenerado:${N} ${W}$user${N}\n"

            # Duración demo
            while true; do
                read -r -p "$(echo -e " ${C}⏳ Tiempo de duración (Ej: 30m / 2h / 1d):${N} ")" tiempo
                
                if [[ "$tiempo" == "0" ]]; then
                    echo -e "\n ${R}❌ Operación cancelada.${N}"
                    sleep 1
                    break
                fi

                if [[ "$tiempo" =~ ^[0-9]+[smhd]$ ]]; then
                    break
                else
                    echo -e " ${R}❌ Usa m (minutos), h (horas) o d (días).${N}"
                fi
            done

            [ "$tiempo" == "0" ] && continue

            # Límite de conexiones demo
            read -r -p "$(echo -e " ${C}📊 Límite de conexiones (Por defecto 1):${N} ")" limit
            if [[ "$limit" == "0" ]]; then
                echo -e "\n ${R}❌ Operación cancelada.${N}"
                sleep 1
                continue
            fi
            [ -z "$limit" ] && limit=1

            # Conversión de tiempo
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
            dibujar_encabezado

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
            read -r -p "Presiona Enter para continuar..."
            ;;

        2|02)
            # =========================================================
            # 2. FLUJO CREAR USUARIO NORMAL
            # =========================================================
            clear
            dibujar_encabezado

            echo -e "${D}┌─────────────────────────────────────────────────────────┐${N}"
            echo -e "${D}│${G}                🙋‍♂️ CREAR USUARIO NORMAL                   ${D}│${N}"
            echo -e "${D}└─────────────────────────────────────────────────────────┘${N}"
            echo -e " ${D}(Presiona 0 para cancelar en cualquier momento)${N}\n"

            # 1. Nombre de Usuario
            while true; do
                read -r -p "$(echo -e " ${C}👤 Nombre de usuario:${N} ")" user

                if [[ "$user" == "0" ]]; then
                    echo -e "\n ${R}❌ Operación cancelada.${N}"
                    sleep 1
                    break
                fi

                if [[ -z "$user" ]]; then
                    echo -e " ${R}❌ El usuario no puede estar vacío.${N}"
                elif id "$user" &>/dev/null; then
                    echo -e " ${R}❌ El usuario '$user' ya existe en el sistema.${N}"
                elif [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    echo -e " ${R}❌ Nombre inválido. Usa letras, números, _ o -.${N}"
                else
                    break
                fi
            done

            [ "$user" == "0" ] && continue

            # 2. Contraseña
            read -r -p "$(echo -e " ${C}🔑 Contraseña (Enter = autogenerar):${N} ")" pass
            if [[ "$pass" == "0" ]]; then
                echo -e "\n ${R}❌ Operación cancelada.${N}"
                sleep 1
                continue
            fi

            if [[ -z "$pass" ]]; then
                pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c8)
                echo -e " ${C}▶ Contraseña generada:${N} ${W}$pass${N}"
            fi

            # 3. Días de Validez
            while true; do
                read -r -p "$(echo -e " ${C}⏳ Días de validez (Ej: 30):${N} ")" dias

                if [[ "$dias" == "0" ]]; then
                    echo -e "\n ${R}❌ Operación cancelada.${N}"
                    sleep 1
                    break
                fi

                if [[ "$dias" =~ ^[0-9]+$ ]] && [ "$dias" -gt 0 ]; then
                    break
                else
                    echo -e " ${R}❌ Ingresa un número de días válido.${N}"
                fi
            done

            [ "$dias" == "0" ] && continue

            # 4. Límite de conexiones
            read -r -p "$(echo -e " ${C}📊 Límite de conexiones (Por defecto 1):${N} ")" limit
            if [[ "$limit" == "0" ]]; then
                echo -e "\n ${R}❌ Operación cancelada.${N}"
                sleep 1
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
            dibujar_encabezado

            echo -e "${D}╔══════════════════════════════════════════════════╗${N}"
            echo -e "${D}║${G}        🙋‍♂️ KIRA PANEL - USUARIO NORMAL 🙋‍♂️        ${D}║${N}"
            echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
            printf "${D}║${N} ${R}🖥️ Ip Server   :${N} %-31s ${D}║${N}\n" "$IP"
            printf "${D}║${N} ${R}👤 Usuario     :${N} %-31s ${D}║${N}\n" "$user"
            printf "${D}║${N} ${R}🔑 Contraseña  :${N} ${W}%-31s${N} ${D}║${N}\n" "$pass"
            printf "${D}║${N} ${R}📡 Puerto Ssh  :${N} %-31s ${D}║${N}\n" "$PORT"
            printf "${D}║${N} ${R}📊 Límite Ssh  :${N} %-31s ${D}║${N}\n" "$limit conex."
            printf "${D}║${N} ${R}⏳ Validez     :${N} %-31s ${D}║${N}\n" "$dias días (Expira: $exp_date)"
            echo -e "${D}╠══════════════════════════════════════════════════╣${N}"
            echo -e "${D}║${N} ${G}📋 DATOS DE CONEXIÓN RÁPIDA (PAYLOAD/SSH):${N}       ${D}║${N}"
            echo -e "${D}║${N}                                                  ${D}║${N}"
            printf "${D}║${N} 🔗 Direc: ${Y}%-38s${N} ${D}║${N}\n" "$directo"
            printf "${D}║${N} 🖥️ Proxy: ${Y}%-38s${N} ${D}║${N}\n" "$proxy"
            echo -e "${D}╚══════════════════════════════════════════════════╝${N}"

            echo "$user $pass NORMAL $limit $(date)" >> /etc/kira/users.log

            echo ""
            read -r -p "Presiona Enter para continuar..."
            ;;

        0)
            clear
            break
            ;;

        *)
            echo -e "\n${R}[!] Opción no válida.${N}"
            sleep 1
            ;;
    esac
done