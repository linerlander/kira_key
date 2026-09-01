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

clear
echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 👥   USUARIOS SSH CONECTADOS                          ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${C}%-4s %-16s %-12s %-10s %-10s %-11s${N}   ${D}║${N}\n" "ID" "USUARIO" "PASS" "PUERTO" "CONEXIÓN" "ESTADO"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

i=1
total_online=0

while IFS=: read -u 3 -r username _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        
        # Conexiones reales contando procesos sshd del usuario
        online_count=$(ps -u "$username" 2>/dev/null | grep -c sshd)
        
        # Solo mostrar si tiene al menos 1 conexión activa
        if [ "$online_count" -gt 0 ]; then
            
            # 1. Obtener Contraseña (Prioriza /etc/kira/pass/)
            if [ -f "/etc/kira/pass/$username" ]; then
                pass=$(cat "/etc/kira/pass/$username")
            else
                pass=$(grep -w "^$username" /etc/kira/users.log 2>/dev/null | awk '{print $2}')
                [ -z "$pass" ] && pass="---"
            fi

            # 2. Obtener Límite
            limit=$(cat "/etc/kira/limits/$username" 2>/dev/null)
            [ -z "$limit" ] && limit="1"
            
            conn_txt="${online_count}/${limit}"
            estado_txt="ONLINE"
            estado_color="$G"

            id_str="[$i]"
            [ $i -lt 10 ] && id_str="[0$i]"

            printf "${D}║${N} ${Y}%-4s${N} %-16s %-12s %-10s %-10s ${estado_color}%-11s${N}  ${D}║${N}\n" \
                   "$id_str" "$username" "$pass" "$PORT" "$conn_txt" "$estado_txt"

            ((i++))
            total_online=$((total_online + online_count))
        fi
    fi
done 3< /etc/passwd

total_users_online=$((i - 1))

if [ $total_users_online -eq 0 ]; then
    echo -e "${D}║${N} ${R}               No hay usuarios conectados en este momento.            ${D}║${N}"
fi

echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}USUARIOS ONLINE:${N} %-10s ${C}TOTAL CONEXIONES:${N} %-17s ${D}      ║${N}\n" "$total_users_online" "$total_online"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"

echo ""
read -p "Presiona Enter para continuar..."