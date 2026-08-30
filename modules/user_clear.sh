#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
[ -z "$PORT" ] && PORT=22

while true; do
clear
echo -e "${D}╔══════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 🗑️  PANEL DE ELIMINACIÓN DE USUARIOS            ${D}║${N}"
echo -e "${D}╠══════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${C}%-3s %-12s %-10s %-8s %-8s %-14s${N} ${D}║${N}\n" "ID" "USUARIO" "PASS" "PUERTO" "LÍMITE" "EXPIRACIÓN"
echo -e "${D}╠══════════════════════════════════════════════════════════════════╣${N}"

# Array para almacenar los usuarios detectados
declare -A users_list
i=1

# Lectura de usuarios del sistema (UID >= 1000)
while IFS=: read -u 3 -r username _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        
        # Obtener Contraseña desde /etc/kira/users.log o shadowed pass
        pass=$(grep -w "^$username" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
        [ -z "$pass" ] && pass="---"

        # Obtener Límite de Conexiones
        limit=$(cat /etc/kira/limits/$username 2>/dev/null)
        [ -z "$limit" ] && limit="1"

        # Calcular Días / Expiración
        exp_date=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2)
        if [[ "$exp_date" == *"never"* ]] || [ -z "$exp_date" ]; then
            validez="Ilimitado"
        else
            exp_sec=$(date -d "$exp_date" +%s 2>/dev/null)
            now_sec=$(date +%s)
            if [ -n "$exp_sec" ]; then
                diff_days=$(( (exp_sec - now_sec) / 86400 ))
                if [ $diff_days -le 0 ]; then
                    validez="Expirado"
                else
                    validez="${diff_days} días"
                fi
            else
                validez="---"
            fi
        fi

        users_list[$i]="$username"
        printf "${D}║${N} ${Y}[%02d]${N} %-12s %-10s %-8s %-8s %-14s ${D}║${N}\n" "$i" "$username" "$pass" "$PORT" "$limit disp." "$validez"
        ((i++))
    fi
done 3< /etc/passwd

if [ $i -eq 1 ]; then
    echo -e "${D}║${N} ${R}               No hay usuarios SSH registrados.                  ${D}║${N}"
fi

echo -e "${D}╠══════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[00] REGRESAR AL MENÚ PRINCIPAL${N}                                   ${D}║${N}"
echo -e "${D}╚══════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona el ID del usuario a eliminar: " selection

if [[ "$selection" == "0" || "$selection" == "00" ]]; then
    exit 0
fi

if [[ -n "${users_list[$selection]}" ]]; then
    user_to_delete="${users_list[$selection]}"
    
    # Proceso de Eliminación
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