#!/bin/bash

# ============================================================
#       PANEL DE EDICIÓN Y RENOVACIÓN - KIRA SSH
# ============================================================

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

PINK='\033[38;5;218m'
BLUE='\033[38;5;75m'

# ============================================================
# COMPROBAR BASH
# ============================================================

if [ -z "$BASH_VERSION" ]; then
    echo "Este script debe ejecutarse con Bash."
    echo "Usa: bash $0"
    exit 1
fi

# ============================================================
# OBTENER PUERTO SSH
# ============================================================

PORT=$(grep -iE '^[[:space:]]*Port[[:space:]]+' /etc/ssh/sshd_config 2>/dev/null \
    | awk '{print $2}' \
    | head -n1)

[ -z "$PORT" ] && PORT=22

# ============================================================
# CREAR DIRECTORIOS NECESARIOS
# ============================================================

mkdir -p /etc/kira/pass
mkdir -p /etc/kira/limits
mkdir -p /etc/kira/expire

# ============================================================
# FUNCIONES
# ============================================================

obtener_password() {
    local username="$1"
    local pass=""

    if [ -f "/etc/kira/pass/$username" ]; then
        pass=$(cat "/etc/kira/pass/$username" 2>/dev/null)
    fi

    if [ -z "$pass" ] && [ -f "/etc/kira/users.log" ]; then
        pass=$(awk -v u="$username" '$1 == u {print $2; exit}' /etc/kira/users.log 2>/dev/null)
    fi

    [ -z "$pass" ] && pass="---"

    echo "$pass"
}

obtener_limite() {
    local username="$1"
    local limit=""

    if [ -f "/etc/kira/limits/$username" ]; then
        limit=$(cat "/etc/kira/limits/$username" 2>/dev/null)
    fi

    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        limit=1
    fi

    echo "$limit"
}

obtener_validez() {

    local username="$1"
    local now_sec
    local validez_txt
    local validez_color

    now_sec=$(date +%s)

    # --------------------------------------------------------
    # SISTEMA KIRA
    # --------------------------------------------------------

    if [ -f "/etc/kira/expire/$username" ]; then

        local created_sec=""
        local duration=""

        read -r created_sec duration < "/etc/kira/expire/$username" 2>/dev/null

        # Formato antiguo basado en fecha YYYY-MM-DD
        if [[ "$created_sec" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then

            local exp_sec

            exp_sec=$(date -d "$created_sec" +%s 2>/dev/null)

            if [ -n "$exp_sec" ]; then

                local diff_sec=$((exp_sec - now_sec))

                if [ "$diff_sec" -le 0 ]; then
                    echo "Expirado|$PINK"
                    return
                fi

                local dias=$((diff_sec / 86400))
                local horas=$(((diff_sec % 86400) / 3600))
                local mins=$(((diff_sec % 3600) / 60))

                if [ "$dias" -gt 0 ]; then
                    validez_txt="${dias}d ${horas}h"
                elif [ "$horas" -gt 0 ]; then
                    validez_txt="${horas}h ${mins}m"
                else
                    validez_txt="${mins}m"
                fi

                echo "$validez_txt|$BLUE"
                return
            fi
        fi

        # ----------------------------------------------------
        # FORMATO TIMESTAMP + DURACIÓN
        # ----------------------------------------------------

        if [[ "$created_sec" =~ ^[0-9]+$ ]] &&
           [[ "$duration" =~ ^[0-9]+[smhd]$ ]]; then

            local num="${duration%[smhd]}"
            local unit="${duration: -1}"
            local seconds_add=0

            case "$unit" in
                s)
                    seconds_add=$num
                    ;;
                m)
                    seconds_add=$((num * 60))
                    ;;
                h)
                    seconds_add=$((num * 3600))
                    ;;
                d)
                    seconds_add=$((num * 86400))
                    ;;
            esac

            local exp_sec=$((created_sec + seconds_add))
            local diff_sec=$((exp_sec - now_sec))

            if [ "$diff_sec" -le 0 ]; then
                echo "Expirado|$PINK"
                return
            fi

            local dias=$((diff_sec / 86400))
            local horas=$(((diff_sec % 86400) / 3600))
            local mins=$(((diff_sec % 3600) / 60))

            if [ "$dias" -gt 0 ]; then
                validez_txt="${dias}d ${horas}h"
            elif [ "$horas" -gt 0 ]; then
                validez_txt="${horas}h ${mins}m"
            else
                validez_txt="${mins}m"
            fi

            echo "$validez_txt|$BLUE"
            return
        fi
    fi

    # --------------------------------------------------------
    # VALIDEZ DEL SISTEMA LINUX
    # --------------------------------------------------------

    local exp_date=""
    exp_date=$(chage -l "$username" 2>/dev/null \
        | awk -F': ' '/Account expires/ {print $2}')

    if [ -z "$exp_date" ] || [[ "$exp_date" == *"never"* ]]; then
        echo "Ilimitado|$BLUE"
        return
    fi

    local exp_sec=""
    exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)

    if [ -n "$exp_sec" ] && [ "$exp_sec" -ge "$now_sec" ]; then

        local diff_days=$(( (exp_sec - now_sec) / 86400 ))

        if [ "$diff_days" -lt 1 ]; then
            echo "Menos de 1d|$BLUE"
        else
            echo "${diff_days}d|$BLUE"
        fi

    else
        echo "Expirado|$PINK"
    fi
}

# ============================================================
# PANEL PRINCIPAL
# ============================================================

while true; do

    clear

    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${Y}                 🔄  PANEL DE EDICIÓN Y RENOVACIÓN                 ${D}║${N}"
    echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

    printf "${D}║${N} ${C}%-4s %-16s %-12s %-8s %-9s %-15s${N}${D} ║${N}\n" \
        "ID" "USUARIO" "PASS" "PUERTO" "LÍMITE" "EXPIRACIÓN"

    echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

    declare -A usernames_arr
    usernames_arr=()

    i=1

    # ========================================================
    # LEER USUARIOS
    # ========================================================

    while IFS=: read -r username _ uid _ _ _ _; do

        # Usuarios normales UID >= 1000
        if [ "$uid" -ge 1000 ] 2>/dev/null &&
           [ "$username" != "nobody" ]; then

            pass=$(obtener_password "$username")
            limit=$(obtener_limite "$username")

            limit_txt="${limit} disp."

            validez_data=$(obtener_validez "$username")

            validez_txt="${validez_data%%|*}"
            validez_color="${validez_data#*|}"

            usernames_arr[$i]="$username"

            id_str=$(printf "%02d" "$i")

            printf "${D}║${N} ${Y}%-4s${N} %-16s %-12s %-8s %-9s ${validez_color}%-15s${N}${D} ║${N}\n" \
                "[$id_str]" \
                "$username" \
                "$pass" \
                "$PORT" \
                "$limit_txt" \
                "$validez_txt"

            ((i++))
        fi

    done < /etc/passwd

    # ========================================================
    # SIN USUARIOS
    # ========================================================

    if [ "$i" -eq 1 ]; then

        echo -e "${D}║${N} ${R}                    No hay usuarios SSH registrados.                   ${D}║${N}"

    fi

    # ========================================================
    # MENÚ INFERIOR
    # ========================================================

    echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
    echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                    ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"

    echo ""

    read -r -p " ► Selecciona el ID del usuario a editar: " selection

    # ========================================================
    # REGRESAR
    # ========================================================

    if [[ "$selection" == "0" || "$selection" == "00" || -z "$selection" ]]; then

        # IMPORTANTE:
        # No usar exit 0 aquí si este script es llamado desde
        # otro menú mediante source.
        return 0 2>/dev/null || exit 0

    fi

    # ========================================================
    # VALIDAR ID
    # ========================================================

    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then

        echo ""
        echo -e " ${R}❌ Selección inválida.${N}"
        sleep 1.5
        continue

    fi

    # ========================================================
    # BUSCAR USUARIO
    # ========================================================

    user_to_edit="${usernames_arr[$selection]}"

    if [ -z "$user_to_edit" ]; then

        echo ""
        echo -e " ${R}❌ No existe un usuario con ese ID.${N}"
        sleep 1.5
        continue

    fi

    # ========================================================
    # DATOS ACTUALES
    # ========================================================

    current_pass=$(obtener_password "$user_to_edit")
    current_limit=$(obtener_limite "$user_to_edit")

    echo ""
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e " ${Y}EDITANDO USUARIO:${N} ${W}$user_to_edit${N}"
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

    # ========================================================
    # CAMBIAR CONTRASEÑA
    # ========================================================

    read -r -p " ► Nueva Contraseña (Enter para mantener '$current_pass'): " new_pass

    if [ -n "$new_pass" ]; then

        if echo "$user_to_edit:$new_pass" | chpasswd 2>/dev/null; then

            mkdir -p /etc/kira/pass
            printf '%s\n' "$new_pass" > "/etc/kira/pass/$user_to_edit"

            chmod 600 "/etc/kira/pass/$user_to_edit"

            if [ -f /etc/kira/users.log ] &&
               grep -q "^${user_to_edit} " /etc/kira/users.log 2>/dev/null; then

                sed -i "s|^${user_to_edit} [^ ]*|${user_to_edit} ${new_pass}|" \
                    /etc/kira/users.log

            else

                echo "$user_to_edit $new_pass 30d $current_limit $(date)" \
                    >> /etc/kira/users.log

            fi

            echo -e " ${G}✔ Contraseña actualizada.${N}"

        else

            echo -e " ${R}❌ No se pudo cambiar la contraseña.${N}"

        fi
    fi

    # ========================================================
    # CAMBIAR LÍMITE
    # ========================================================

    read -r -p " ► Nuevo Límite SSH (Enter para mantener '$current_limit'): " new_limit

    if [ -n "$new_limit" ]; then

        if [[ "$new_limit" =~ ^[0-9]+$ ]] &&
           [ "$new_limit" -gt 0 ]; then

            mkdir -p /etc/kira/limits

            printf '%s\n' "$new_limit" \
                > "/etc/kira/limits/$user_to_edit"

            echo -e " ${G}✔ Límite actualizado a $new_limit.${N}"

        else

            echo -e " ${R}❌ El límite debe ser un número mayor que 0.${N}"

        fi
    fi

    # ========================================================
    # RENOVAR VALIDEZ
    # ========================================================

    read -r -p " ► Días / Tiempo de validez (Ej: 30d / 2h / 30m - Enter para no cambiar): " new_time

    if [ -n "$new_time" ]; then

        mkdir -p /etc/kira/expire

        # ----------------------------------------------------
        # FORMATO: 30d / 2h / 30m / 30s
        # ----------------------------------------------------

        if [[ "$new_time" =~ ^[0-9]+[smhd]$ ]]; then

            printf '%s %s\n' "$(date +%s)" "$new_time" \
                > "/etc/kira/expire/$user_to_edit"

            # ------------------------------------------------
            # SI SON DÍAS, ACTUALIZAR CHAGE
            # ------------------------------------------------

            if [[ "$new_time" =~ d$ ]]; then

                days_num="${new_time%d}"

                exp_date=$(date -d "+$days_num days" +%Y-%m-%d 2>/dev/null)

                if [ -n "$exp_date" ]; then
                    chage -E "$exp_date" "$user_to_edit" 2>/dev/null
                fi

            else

                # Para horas/minutos/segundos usamos el
                # archivo Kira como fuente de expiración.
                chage -E -1 "$user_to_edit" 2>/dev/null

            fi

            echo -e " ${G}✔ Validez renovada correctamente por $new_time.${N}"

        # ----------------------------------------------------
        # FORMATO SOLO NÚMERO = DÍAS
        # ----------------------------------------------------

        elif [[ "$new_time" =~ ^[0-9]+$ ]]; then

            printf '%s %sd\n' "$(date +%s)" "$new_time" \
                > "/etc/kira/expire/$user_to_edit"

            exp_date=$(date -d "+$new_time days" +%Y-%m-%d 2>/dev/null)

            if [ -n "$exp_date" ]; then
                chage -E "$exp_date" "$user_to_edit" 2>/dev/null
            fi

            echo -e " ${G}✔ Validez renovada correctamente por ${new_time} días.${N}"

        else

            echo -e " ${R}❌ Formato de tiempo inválido.${N}"
            echo -e " ${Y}Ejemplos: 30d, 7d, 12h, 30m${N}"

        fi
    fi

    # ========================================================
    # FINAL
    # ========================================================

    echo ""
    echo -e " ${G}✔ Cambios guardados en '$user_to_edit'.${N}"
    echo ""

    read -r -p " Presiona Enter para continuar..." _

done