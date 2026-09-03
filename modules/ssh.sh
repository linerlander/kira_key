#!/bin/bash

# ========= COLORES Y ESTILOS =========
W='\033[1;37m'
D='\033[38;5;240m'
Y='\033[38;5;226m'
R='\033[38;5;196m'
C='\033[38;5;183m'
G='\033[38;5;46m'
N='\033[0m'

# ========= CONFIGURACIÓN =========
CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak"

get_ports() {
    local ports
    ports=$(grep -E "^[[:space:]]*Port " "$CONFIG" | awk '{print $2}')
    
    if [ -z "$ports" ]; then
        echo "22"
    else
        echo "$ports"
    fi
}

port_in_use() {
    ss -tuln | grep -E -q "(:$1\b|\[::\]:$1\b)"
}

backup_config() {
    cp "$CONFIG" "$BACKUP"
}

restart_ssh_service() {
    if systemctl list-units --full -all | grep -Fq "ssh.service"; then
        systemctl restart ssh
    else
        systemctl restart sshd
    fi
}

open_firewall() {
    if command -v ufw >/dev/null; then
        ufw allow "$1"/tcp >/dev/null 2>&1
    else
        iptables -A INPUT -p tcp --dport "$1" -j ACCEPT
    fi
}

while true; do
    clear

    # ========= BANNER ESTILIZADO =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}                    🔐 SSH SECURITY PANEL            ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""
    
    # ========= AVISO EN CAJA / LÍNEA =========
    echo -e " ${Y}⚠ Nota: El puerto 22 está protegido contra borrado${N}"
    echo -e "${D}─────────────────────────────────────────────────────${N}"

    # ========= LISTA DE PUERTOS =========
    echo -e " ${C}🔌 PUERTOS SSH ACTIVOS Y CONFIGURADOS${N}"
    echo -e "${D}─────────────────────────────────────────────────────${N}"

    PORTS=$(get_ports)

    for p in $PORTS; do
        if ss -tuln | grep -E -q "(:$p\b|\[::\]:$p\b)"; then
            STATUS="${G}● ACTIVO${N}"
        else
            STATUS="${R}● INACTIVO${N}"
        fi

        printf " ${D}├──${N} ${W}Puerto %-5s${N} %b\n" "$p" "$STATUS"
    done

    echo -e "${D}─────────────────────────────────────────────────────${N}"

    # ========= MENÚ DE OPCIONES =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    printf "${C}║${N} ${G}[1]${N} ${W}%-45s   ${C}║${N}\n" "Agregar nuevo puerto SSH"
    printf "${C}║${N} ${R}[2]${N} ${W}%-45s   ${C}║${N}\n" "Eliminar puerto SSH existente"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    printf "${C}║${N} ${R}[0]${N} ${W}%-45s    ${C}║${N}\n" "Regresar al menú principal"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    read -p " ► Selecciona una opción: " op
    echo ""

    case $op in

        1)
            read -p " ► Ingresa el nuevo puerto: " PORT
            echo ""

            if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
                echo -e "${R} ✘ Puerto inválido. Debe ser un número.${N}"
                read -p " Presiona Enter para continuar..."
                continue
            fi

            if grep -q -E "^[[:space:]]*Port $PORT" "$CONFIG" || ([ "$PORT" = "22" ] && ! grep -q -E "^[[:space:]]*Port " "$CONFIG"); then
                echo -e "${R} ✘ Ese puerto ya se encuentra registrado.${N}"
                read -p " Presiona Enter para continuar..."
                continue
            fi

            if port_in_use "$PORT"; then
                echo -e "${R} ✘ El puerto ya está en uso por otro servicio.${N}"
                read -p " Presiona Enter para continuar..."
                continue
            fi

            backup_config
            
            if ! grep -q -E "^[[:space:]]*Port " "$CONFIG"; then
                echo "Port 22" >> "$CONFIG"
            fi

            echo "Port $PORT" >> "$CONFIG"
            open_firewall "$PORT"
            restart_ssh_service

            echo -e "${G} ✔ Puerto agregado correctamente.${N}"
            read -p " Presiona Enter para continuar..."
            ;;

        2)
            read -p " ► Ingresa el puerto a eliminar: " PORT
            echo ""

            if [ "$PORT" = "22" ]; then
                echo -e "${R} ✘ Acción denegada: No puedes eliminar el puerto 22.${N}"
                read -p " Presiona Enter para continuar..."
                continue
            fi

            if ! grep -q -E "^[[:space:]]*Port $PORT" "$CONFIG"; then
                echo -e "${R} ✘ El puerto especificado no existe en la configuración.${N}"
                read -p " Presiona Enter para continuar..."
                continue
            fi

            TOTAL=$(get_ports | wc -l)

            if [ "$TOTAL" -le 1 ]; then
                echo -e "${R} ✘ Acción denegada: No puedes eliminar el último puerto activo.${N}"
                read -p " Presiona Enter para continuar..."
                continue
            fi

            backup_config
            
            if ! grep -q -E "^[[:space:]]*Port 22" "$CONFIG"; then
                echo "Port 22" >> "$CONFIG"
            fi

            sed -i -E "/^[[:space:]]*Port $PORT/d" "$CONFIG"
            restart_ssh_service

            echo -e "${G} ✔ Puerto eliminado correctamente.${N}"
            read -p " Presiona Enter para continuar..."
            ;;

        0)
            break
            ;;

        *)
            echo -e "${R} ✘ Opción inválida, intenta de nuevo.${N}"
            sleep 1
            ;;

    esac

done