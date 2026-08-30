#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

PINK='\033[38;5;218m' # Rosado bebé (Expirado)
BLUE='\033[38;5;75m'  # Azul claro (Vigente)

PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

while true; do
clear
echo -e "${D}╔═════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}               🗑️   PANEL DE ELIMINACIÓN DE USUARIOS                 ${D}║${N}"
echo -e "${D}╠═════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${C}%-4s %-13s %-11s %-8s %-9s %-16s${N} ${D}║${N}\n" "ID" "USUARIO" "PASS" "PUERTO" "LÍMITE" "EXPIRACIÓN"
echo -e "${D}╠═════════════════════════════════════════════════════════════════════╣${N}"

declare -A users_list
i=1

while IFS=: read -u 3 -r username _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        
        # Obtener Contraseña
        pass=$(grep -w "^$username" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
        [ -z "$pass" ] && pass="---"

        # Obtener Límite
        limit=$(cat /etc/kira/limits/$username 2>/dev/null)
        [ -z "$limit" ] && limit="1"
        limit_txt="${limit} disp."

        # CÁLCULO DE VALIDEZ MEJORADO
        validez=""
        now_sec=$(date +%s)

        if [ -f "/etc/kira/expire/$username" ]; then
            read -r created_sec duration < "/etc/kira/expire/$username"
            
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
                validez="${PINK}Expirado${N}"
            else
                dias=$((diff_sec / 86400))
                horas=$(( (diff_sec % 86400) / 3600 ))
                mins=$(( (diff_sec % 3600) / 60 ))

                if [ $dias -gt 0 ]; then
                    validez="${BLUE}${dias}d ${horas}h${N}"
                elif [ $horas -gt 0 ]; then
                    validez="${BLUE}${horas}h ${mins}m${N}"
                else
                    validez="${BLUE}${mins}m${N}"
                fi
            fi
        else
            exp_date=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2)
            if [[ "$exp_date" == *"never"* ]] || [ -z "$exp_date" ]; then
                validez="${BLUE}Ilimitado${N}"
            else
                exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
                if [ -n "$exp_sec" ] && [ $exp_sec -ge $now_sec ]; then
                    diff_days=$(( (exp_sec - now_sec) / 86400 ))
                    validez="${BLUE}${diff_days}d${N}"
                else
                    validez="${PINK}Expirado${N}"
                fi
            fi
        fi

        users_list[$i]="$username"
        id_str="[$i]"
        [ $i -lt 10 ] && id_str="[0$i]"

        # Formateo sin colores para calcular longitud exacta del borde
        raw_validez=$(echo -e "$validez" | sed 's/\x1b\[[0-9;]*m//g')
        printf -v row_text "%-4s %-13s %-11s %-8s %-9s %-16s" "$id_str" "$username" "$pass" "$PORT" "$limit_txt" "$raw_validez"
        
        # Impresión final alineada aplicando los colores reales
        printf "${D}║${N} ${Y}%-4s${N} %-13s %-11s %-8s %-9s %b" "$id_str" "$username" "$pass" "$PORT" "$limit_txt" "$validez"
        
        # Relleno de espacios exactos antes del borde derecho ║
        pad=$((67 - ${#row_text}))
        printf "%${pad}s${D}║${N}\n" ""

        ((i++))
    fi
done 3< /etc/passwd

if [ $i -eq 1 ]; then
    echo -e "${D}║${N} ${R}               No hay usuarios SSH registrados.                  ${D}║${N}"
fi

echo -e "${D}╠═════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                       ${D}║${N}"
echo -e "${D}╚═════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona el ID del usuario a eliminar: " selection

if [[ "$selection" == "0" || "$selection" == "00" ]]; then
    exit 0
fi

if [[ -n "${users_list[$selection]}" ]]; then
    user_to_delete="${users_list[$selection]}"
    
    userdel -f "$user_to_delete" 2>/dev/null
    rm -rf /home/"$user_to_delete" 2>/dev/null
    rm -f /etc/kira/limits/"$user_to_delete" /etc/kira/expire/"$user_to_delete"
    sed -i "/^$user_to_delete /d" /etc/kira/users.log 2>/dev/null

    echo ""
    echo -e " ${G}✔ Usuario '${W}$user_to_delete${G}' borrado exitosamente.${N}"
    sleep 2
else
    echo ""
    echo -e " ${R}❌ Selección inválida.${N}"
    sleep 1.5
fi

done