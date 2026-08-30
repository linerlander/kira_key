#!/bin/bash

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

PORT=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

while true; do
clear
echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                     🔄   PANEL DE EDICIÓN Y RENOVACIÓN                  ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${C}%-4s %-16s %-12s %-8s %-9s %-15s${N}  ${D} ║${N}\n" "ID" "USUARIO" "PASS" "PUERTO" "LÍMITE" "EXPIRACIÓN"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

usernames_arr=()
i=1

while IFS=: read -r username _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        
        if [ -f "/etc/kira/pass/$username" ]; then
            pass=$(cat "/etc/kira/pass/$username")
        else
            pass=$(grep -w "^$username" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
            [ -z "$pass" ] && pass="---"
        fi

        limit=$(cat /etc/kira/limits/$username 2>/dev/null)
        [ -z "$limit" ] && limit="1"
        limit_txt="${limit} disp."

        validez_txt=""
        validez_color=""
        now_sec=$(date +%s)

        if [ -f "/etc/kira/expire/$username" ]; then
            read -r created_sec duration < "/etc/kira/expire/$username" 2>/dev/null
            
            num="${duration//[!0-9]/}"
            unit="${duration//[0-9]/}"

            case "$unit" in
                m) seconds_add=$((num * 60)) ;;
                h) seconds_add=$((num * 3600)) ;;
                d) seconds_add=$((num * 86400)) ;;
                *) seconds_add=0 ;;
            esac

            exp_sec=$((created_sec + seconds_add))
            diff_sec=$((exp_sec - now_sec))

            if [ $diff_sec -le 0 ]; then
                validez_txt="Expirado"
                validez_color="$PINK"
            else
                dias=$((diff_sec / 86400))
                horas=$(( (diff_sec % 86400) / 3600 ))
                mins=$(( (diff_sec % 3600) / 60 ))

                if [ $dias -gt 0 ]; then
                    validez_txt="${dias}d ${horas}h"
                elif [ $horas -gt 0 ]; then
                    validez_txt="${horas}h ${mins}m"
                else
                    validez_txt="${mins}m"
                fi
                validez_color="$BLUE"
            fi
        else
            exp_date=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2)
            if [[ "$exp_date" == *"never"* ]] || [ -z "$exp_date" ]; then
                validez_txt="Ilimitado"
                validez_color="$BLUE"
            else
                exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
                if [ -n "$exp_sec" ] && [ $exp_sec -ge $now_sec ]; then
                    diff_days=$(( (exp_sec - now_sec) / 86400 ))
                    validez_txt="${diff_days}d"
                    validez_color="$BLUE"
                else
                    validez_txt="Expirado"
                    validez_color="$PINK"
                fi
            fi
        fi

        usernames_arr[$i]="$username"
        id_str="[$i]"
        [ $i -lt 10 ] && id_str="[0$i]"

        printf "${D}║${N} ${Y}%-4s${N} %-16s %-12s %-8s %-9s ${validez_color}%-15s${N} ${D}║${N}\n" \
               "$id_str" "$username" "$pass" "$PORT" "$limit_txt" "$validez_txt"

        ((i++))
    fi
done < /etc/passwd

if [ $i -eq 1 ]; then
    echo -e "${D}║${N} ${R}                    No hay usuarios SSH registrados.                   ${D}║${N}"
fi

echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                    ${D}║${N}"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona el ID del usuario a editar: " selection

if [[ "$selection" == "0" || "$selection" == "00" || -z "$selection" ]]; then
    return 2>/dev/null || exit 0
fi

if [[ "$selection" =~ ^[0-9]+$ ]] && [ -n "${usernames_arr[$selection]}" ]; then
    user_to_edit="${usernames_arr[$selection]}"
    
    if [ -f "/etc/kira/pass/$user_to_edit" ]; then
        current_pass=$(cat "/etc/kira/pass/$user_to_edit")
    else
        current_pass=$(grep -w "^$user_to_edit" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
    fi
    [ -z "$current_pass" ] && current_pass="---"

    current_limit=$(cat /etc/kira/limits/$user_to_edit 2>/dev/null)
    [ -z "$current_limit" ] && current_limit=1

    echo ""
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e " ${Y}EDITANDO USUARIO:${N} ${W}$user_to_edit${N}"
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    
    read -p " ► Nueva Contraseña (Enter para mantener '$current_pass'): " new_pass
    if [ -n "$new_pass" ]; then
        echo "$user_to_edit:$new_pass" | chpasswd 2>/dev/null
        mkdir -p /etc/kira/pass
        echo "$new_pass" > "/etc/kira/pass/$user_to_edit"
        
        if grep -q "^$user_to_edit " /etc/kira/users.log 2>/dev/null; then
            sed -i "s/^$user_to_edit [^ ]*/$user_to_edit $new_pass/" /etc/kira/users.log
        else
            echo "$user_to_edit $new_pass 30d $current_limit $(date)" >> /etc/kira/users.log
        fi
        echo -e " ${G}✔ Contraseña actualizada.${N}"
    fi

    read -p " ► Nuevo Límite SSH (Enter para mantener '$current_limit'): " new_limit
    if [ -n "$new_limit" ] && [[ "$new_limit" =~ ^[0-9]+$ ]]; then
        mkdir -p /etc/kira/limits
        echo "$new_limit" > "/etc/kira/limits/$user_to_edit"
        echo -e " ${G}✔ Límite actualizado a $new_limit.${N}"
    fi

    read -p " ► Días / Tiempo de validez a añadir (Ej: 30d / 2h / 30m - Enter para no cambiar): " new_time
    if [ -n "$new_time" ]; then
        mkdir -p /etc/kira/expire
        if [[ "$new_time" =~ ^[0-9]+[smhd]$ ]]; then
            echo "$(date +%s) $new_time" > "/etc/kira/expire/$user_to_edit"
            if [[ "$new_time" =~ d$ ]]; then
                days_num="${new_time//d/}"
                exp_date=$(date -d "+$days_num days" +%Y-%m-%d 2>/dev/null)
                chage -E "$exp_date" "$user_to_edit" 2>/dev/null
            else
                chage -E -1 "$user_to_edit" 2>/dev/null
            fi
            echo -e " ${G}✔ Validez renovada correctamente por $new_time.${N}"
        elif [[ "$new_time" =~ ^[0-9]+$ ]]; then
            echo "$(date +%s) ${new_time}d" > "/etc/kira/expire/$user_to_edit"
            exp_date=$(date -d "+$new_time days" +%Y-%m-%d 2>/dev/null)
            chage -E "$exp_date" "$user_to_edit" 2>/dev/null
            echo -e " ${G}✔ Validez renovada correctamente por ${new_time} días.${N}"
        else
            echo -e " ${R}❌ Formato de tiempo inválido.${N}"
        fi
    fi

    echo ""
    echo -e " ${G}✔ Cambios guardados en '$user_to_edit'.${N}"
    sleep 2
else
    echo ""
    echo -e " ${R}❌ Selección inválida.${N}"
    sleep 1.5
fi

done