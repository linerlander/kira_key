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
echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                     🗑️   PANEL DE ELIMINACIÓN DE USUARIOS             ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${C}%-4s %-16s %-12s %-8s %-9s %-15s${N} ${D}  ║${N}\n" "ID" "USUARIO" "PASS" "PUERTO" "LÍMITE" "EXPIRACIÓN"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

declare -A users_list
i=1

while IFS=: read -r username _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        
        # 1. Obtener Contraseña (Prioriza /etc/kira/pass/)
        if [ -f "/etc/kira/pass/$username" ]; then
            pass=$(cat "/etc/kira/pass/$username")
        else
            pass=$(grep -w "^$username" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
            [ -z "$pass" ] && pass="---"
        fi

        # 2. Obtener Límite
        limit=$(cat /etc/kira/limits/$username 2>/dev/null)
        [ -z "$limit" ] && limit="1"
        limit_txt="${limit} disp."

        # 3. CÁLCULO DE VALIDEZ
        validez_txt=""
        validez_color=""
        now_sec=$(date +%s)

        if [ -f "/etc/kira/expire/$username" ]; then
            read -r created_sec duration < "/etc/kira/expire/$username" 2>/dev/null
            
            # Si el archivo tiene formato de fecha simple (YYYY-MM-DD) en lugar de epoch + duración
            if [[ "$created_sec" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                exp_sec=$(date -d "$created_sec" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$created_sec" +%s 2>/dev/null)
                [ -z "$exp_sec" ] && exp_sec=$now_sec
            else
                num="${duration//[!0-9]/}"
                unit="${duration//[0-9]/}"

                case "$unit" in
                    m) seconds_add=$((num * 60)) ;;
                    h) seconds_add=$((num * 3600)) ;;
                    d) seconds_add=$((num * 86400)) ;;
                    *) seconds_add=0 ;;
                esac
                
                exp_sec=$((created_sec + seconds_add))
            fi

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

        users_list[$i]="$username"
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
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                        ${D}║${N}"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona el ID del usuario a eliminar: " selection

if [[ "$selection" == "0" || "$selection" == "00" ]]; then
    exit 0
fi

if [[ -n "${users_list[$selection]}" ]]; then
    user_to_delete="${users_list[$selection]}"
    
    # Detener procesos activos del usuario y borrar del sistema
    pkill -u "$user_to_delete" 2>/dev/null
    userdel -f "$user_to_delete" 2>/dev/null
    rm -rf /home/"$user_to_delete" 2>/dev/null
    
    # Limpieza completa de base de datos Kira
    rm -f /etc/kira/pass/"$user_to_delete"
    rm -f /etc/kira/limits/"$user_to_delete"
    rm -f /etc/kira/expire/"$user_to_delete"
    sed -i "/^$user_to_delete /d" /etc/kira/users.log 2>/dev/null

    echo ""
    echo -e " ${G}✔ Usuario '${W}$user_to_delete${G}' borrado exitosamente de todo el sistema.${N}"
    sleep 2
else
    echo ""
    echo -e " ${R}❌ Selección inválida.${N}"
    sleep 1.5
fi

done