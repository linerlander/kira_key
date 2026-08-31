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
    # Busca puertos descomentados en sshd_config
    local ports
    ports=$(grep -E "^[[:space:]]*Port " "$CONFIG" | awk '{print $2}')
    
    # Si no encuentra ninguno (viene comentado por defecto), devuelve el 22
    if [ -z "$ports" ]; then
        echo "22"
    else
        echo "$ports"
    fi
}

port_in_use() {
    ss -tuln | grep -q ":$1 "
}

backup_config() {
    cp "$CONFIG" "$BACKUP"
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
    echo -e "${C}║${W}                🔐 SSH SECURITY PANEL                ${C}║${N}"
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
        if ss -tuln | grep -q ":$p "; then
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
            
            # Si el puerto 22 estaba implícito (comentado) y añaden otro, aseguramos que el 22 quede escrito explícitamente antes de agregar el nuevo
            if ! grep -q -E "^[[:space:]]*Port " "$CONFIG"; then
                echo "Port 22" >> "$CONFIG"
            fi

            echo "Port $PORT" >> "$CONFIG"
            open_firewall "$PORT"
            systemctl restart ssh

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

            # Si el 22 está por defecto (sin línea escrita) y quieren borrar el 22 teóricamente
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
            # Si el 22 no estaba escrito de forma explícita, lo escribimos antes de borrar el otro para no romper la config
            if ! grep -q -E "^[[:space:]]*Port 22" "$CONFIG"; then
                echo "Port 22" >> "$CONFIG"
            fi

            sed -i -E "/^[[:space:]]*Port $PORT/d" "$CONFIG"
            systemctl restart ssh

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