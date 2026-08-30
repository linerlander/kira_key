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

clear
echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 📋   LISTA DE USUARIOS REGISTRADOS                  ${D}  ║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${C}%-4s %-16s %-12s %-8s %-9s %-15s${N} ${D}  ║${N}\n" "ID" "USUARIO" "PASS" "PUERTO" "LÍMITE" "EXPIRACIÓN"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

i=1
activos=0
expirados=0

while IFS=: read -u 3 -r username _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        
        # 1. Obtener Contraseña (Prioriza /etc/kira/pass/ y luego users.log)
        if [ -f "/etc/kira/pass/$username" ]; then
            pass=$(cat "/etc/kira/pass/$username")
        else
            pass=$(grep -w "^$username" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
            [ -z "$pass" ] && pass="---"
        fi

        # 2. Obtener Límite
        limit=$(cat "/etc/kira/limits/$username" 2>/dev/null)
        [ -z "$limit" ] && limit="1"
        limit_txt="${limit} disp."

        # 3. CÁLCULO DE VALIDEZ
        validez_txt=""
        validez_color=""
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
                validez_txt="Expirado"
                validez_color="$PINK"
                ((expirados++))
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
                ((activos++))
            fi
        else
            # Fallback en caso de no tener registro en /etc/kira/expire
            exp_date=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2)
            if [[ "$exp_date" == *"never"* ]] || [ -z "$exp_date" ]; then
                validez_txt="Ilimitado"
                validez_color="$BLUE"
                ((activos++))
            else
                exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
                if [ -n "$exp_sec" ] && [ $exp_sec -ge $now_sec ]; then
                    diff_days=$(( (exp_sec - now_sec) / 86400 ))
                    validez_txt="${diff_days}d"
                    validez_color="$BLUE"
                    ((activos++))
                else
                    validez_txt="Expirado"
                    validez_color="$PINK"
                    ((expirados++))
                fi
            fi
        fi

        id_str="[$i]"
        [ $i -lt 10 ] && id_str="[0$i]"

        printf "${D}║${N} ${Y}%-4s${N} %-16s %-12s %-8s %-9s ${validez_color}%-15s${N} ${D}║${N}\n" \
               "$id_str" "$username" "$pass" "$PORT" "$limit_txt" "$validez_txt"

        ((i++))
    fi
done 3< /etc/passwd

total_users=$((i - 1))

if [ $total_users -eq 0 ]; then
    echo -e "${D}║${N} ${R}               No hay usuarios SSH registrados.                  ${D}    ║${N}"
fi

echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}TOTAL:${N} %-10s ${G}ACTIVOS:${N} %-10s ${PINK}EXPIRADOS:${N} %-15s ${D}     ║${N}\n" "$total_users" "$activos" "$expirados"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"

echo ""
read -p "Presiona Enter para continuar..."