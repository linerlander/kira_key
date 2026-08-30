#!/bin/bash

# ========= COLORES DE CONSOLA =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

BOT_DIR="/etc/kira/bot"
BOT_CONFIG="$BOT_DIR/bot.conf"
BOT_SCRIPT="$BOT_DIR/telegram_bot.sh"
BOT_PID_FILE="$BOT_DIR/bot.pid"

# Crear estructura de directorios necesaria
mkdir -p "$BOT_DIR"
mkdir -p /etc/kira/pass /etc/kira/limits

check_bot_status() {
    if [ -f "$BOT_PID_FILE" ] && kill -0 $(cat "$BOT_PID_FILE") 2>/dev/null; then
        echo -e "${G}ONLINE (Activo)${N}"
    else
        echo -e "${R}OFFLINE (Inactivo)${N}"
    fi
}

create_bot_daemon() {
    cat << 'EOF' > "$BOT_SCRIPT"
#!/bin/bash

BOT_DIR="/etc/kira/bot"
source "$BOT_DIR/bot.conf"

TOKEN=$(echo "$TOKEN" | tr -d '\r\n"')

URL="https://api.telegram.org/bot$TOKEN"
OFFSET=0
VPS_IP=$(curl -s https://api.ipify.org || echo "VPS_IP")

send_message() {
    local chat_id="$1"
    local text="$2"
    curl -s -X POST "$URL/sendMessage" \
        -d "chat_id=$chat_id" \
        --data-urlencode "text=$text" \
        -d "parse_mode=HTML" > /dev/null
}

is_authorized() {
    local target_id="$1"
    source "$BOT_DIR/bot.conf"
    IFS=',' read -ra ADM_LIST <<< "$ADMIN_IDS"
    for id in "${ADM_LIST[@]}"; do
        clean_id=$(echo "$id" | tr -d ' ')
        if [ "$clean_id" == "$target_id" ]; then
            return 0
        fi
    done
    return 1
}

# Obtiene la fecha real de expiración del sistema Linux
get_user_expiration() {
    local user="$1"
    local exp_raw
    exp_raw=$(chage -l "$user" 2>/dev/null | grep "Account expires" | awk -F: '{print $2}')
    
    if [ -z "$exp_raw" ] || [[ "$exp_raw" == *"never"* ]]; then
        echo "NUNCA / ILIMITADO"
    else
        # Formatear la fecha obtenida del sistema
        date -d "$exp_raw" "+%Y-%m-%d" 2>/dev/null || echo "CADUCADO"
    fi
}

while true; do
    UPDATES=$(curl -s "$URL/getUpdates?offset=$OFFSET&timeout=10")
    
    if [[ "$UPDATES" =~ "\"ok\":true" ]]; then
        if command -v jq &>/dev/null; then
            UPDATES_QTY=$(echo "$UPDATES" | jq '.result | length' 2>/dev/null)
            if [ -n "$UPDATES_QTY" ] && [ "$UPDATES_QTY" -gt 0 ]; then
                for (( i=0; i<$UPDATES_QTY; i++ )); do
                    UPDATE_ID=$(echo "$UPDATES" | jq ".result[$i].update_id")
                    OFFSET=$((UPDATE_ID + 1))
                    
                    CHAT_ID=$(echo "$UPDATES" | jq -r ".result[$i].message.chat.id")
                    TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text")
                    
                    [ "$TEXT" == "null" ] && continue
                    CHAT_ID_CLEAN=$(echo "$CHAT_ID" | tr -d '\r\n ')

                    if ! is_authorized "$CHAT_ID_CLEAN"; then
                        send_message "$CHAT_ID" "⚠️ <b>Acceso Denegado.</b> Tu ID (<code>$CHAT_ID_CLEAN</code>) no está autorizado."
                        continue
                    fi

                    CMD=$(echo "$TEXT" | awk '{print $1}')
                    PARAM1=$(echo "$TEXT" | awk '{print $2}')
                    PARAM2=$(echo "$TEXT" | awk '{print $3}')
                    PARAM3=$(echo "$TEXT" | awk '{print $4}')
                    PARAM4=$(echo "$TEXT" | awk '{print $5}')

                    case "$CMD" in
                        /start|/menu)
                            MSG="✨━━━━━━━━━━━━━━━━━━━━━━✨
👑 <b>BIENVENIDO SUPER ADMIN PREMIUM</b>
✨━━━━━━━━━━━━━━━━━━━━━━✨
😃 <i>MENU DE ACCIONES RÁPIDAS</i> 😃
✨━━━━━━━━━━━━━━━━━━━━━━✨
🌐 <b>IP Asignada:</b> <code>$VPS_IP</code>
✨━━━━━━━━━━━━━━━━━━━━━━✨

👥 <b>Usuarios</b>
 • /agregar → <i>Agregar usuario SSH</i>
 • /demo → <i>Crear usuario demo</i>
 • /usuarios → <i>Lista de usuarios</i>
 • /conectados → <i>Usuarios conectados</i>
 • /borrar → <i>Eliminar usuario</i>

⌛ <b>Renovaciones</b>
 • /renovar → <i>Renovación directa</i>
 • /renovarM → <i>Renovación + días ➕</i>
 • /renovarQ → <i>Renovación - días ➖</i>

⚙️ <b>VPS</b>
 • /infovps → <i>Información del VPS</i>
 • /liberados → <i>Usuarios liberados</i>
 • /reiniciar → <i>Reiniciar servicios</i>

🔐 <b>Gestión de Admin</b>
 • /aggADM → <i>Agregar admin</i>
 • /creditos → <i>Autorizar créditos</i>
 • /admkill → <i>Quitar autorización</i>

✨━━━━━━━━━━━━━━━━━━━━━━✨"
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /agregar|/crear)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ] || [ -z "$PARAM3" ]; then
                                MSG="✨━━━━━━━━━━━━━━━━━━━━━━✨
<b>FORMA DE USAR ESTA OPCIÓN</b>
✨━━━━━━━━━━━━━━━━━━━━━━✨

<i>DEBES ENVIAR EL COMANDO:</i>
<code>/agregar Nombre_User Clave Tiempo Limite</code>
✨━━━━━━━━━━━━━━━━━━━━━━✨
<code>/agregar usuario1 123456 30 1</code>
✨━━━━━━━━━━━━━━━━━━━━━━✨"
                                send_message "$CHAT_ID" "$MSG"
                            else
                                USERNAME="$PARAM1"
                                PASSWORD="$PARAM2"
                                DAYS="$PARAM3"
                                LIMIT="${PARAM4:-1}"

                                if id "$USERNAME" &>/dev/null; then
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> ya existe."
                                else
                                    useradd -M -s /bin/false "$USERNAME" 2>/dev/null
                                    echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null
                                    
                                    # Guarda la contraseña para consulta en panel/bot
                                    echo "$PASSWORD" > "/etc/kira/pass/$USERNAME"
                                    echo "$LIMIT" > "/etc/kira/limits/$USERNAME"

                                    # Aplicar expiración nativa al usuario SSH
                                    EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)
                                    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null

                                    MSG="✅ <b>USUARIO CREADO CON ÉXITO</b>

👤 <b>Usuario:</b> <code>$USERNAME</code>
🔑 <b>Contraseña:</b> <code>$PASSWORD</code>
📅 <b>Vencimiento:</b> <code>$EXP_DATE</code> ($DAYS días)
📱 <b>Límite:</b> $LIMIT dispositivo(s)
🌐 <b>IP:</b> <code>$VPS_IP</code>"
                                    send_message "$CHAT_ID" "$MSG"
                                fi
                            fi
                            ;;

                        /usuarios)
                            # Filtra usuarios del sistema (UID >= 1000)
                            USERS_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
                            if [ -z "$USERS_LIST" ]; then
                                send_message "$CHAT_ID" "📋 <b>No hay usuarios SSH creados en el sistema.</b>"
                            else
                                MSG=""
                                count=1
                                for u in $USERS_LIST; do
                                    # Lee la contraseña del registro
                                    if [ -f "/etc/kira/pass/$u" ]; then
                                        PASS_VAL=$(cat "/etc/kira/pass/$u")
                                    else
                                        PASS_VAL="<i>[Creado desde SSH terminal]</i>"
                                    fi
                                    
                                    # Consulta la fecha REAL en el sistema Linux
                                    EXP_FMT=$(get_user_expiration "$u")

                                    [ -f "/etc/kira/limits/$u" ] && LIM_VAL=$(cat "/etc/kira/limits/$u") || LIM_VAL="1"

                                    MSG+="============================
USER ($count) : <b>$u</b>
PASSWD : <code>$PASS_VAL</code>
EXPIRA : <code>$EXP_FMT</code>
LIMITE : <code>$LIM_VAL</code>
"
                                    count=$((count+1))
                                done
                                MSG+="============================"
                                send_message "$CHAT_ID" "$MSG"
                            fi
                            ;;

                        /renovar)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID" "🔄 <b>Sintaxis:</b> <code>/renovar Usuario Días</code>"
                            else
                                USERNAME="$PARAM1"
                                DAYS="$PARAM2"
                                if id "$USERNAME" &>/dev/null; then
                                    EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)
                                    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID" "🔄 Usuario <b>$USERNAME</b> renovado a <b>$DAYS días</b> (Nueva Expiración real: <code>$EXP_DATE</code>)."
                                else
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> no existe en el VPS."
                                fi
                            fi
                            ;;

                        /renovarM)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID" "➕ <b>Sintaxis:</b> <code>/renovarM Usuario Días_Añadir</code>"
                            else
                                USERNAME="$PARAM1"
                                ADD_DAYS="$PARAM2"
                                if id "$USERNAME" &>/dev/null; then
                                    CURR_EXP=$(chage -l "$USERNAME" | grep "Account expires" | awk -F: '{print $2}')
                                    if [[ "$CURR_EXP" == *"never"* ]] || [ -z "$CURR_EXP" ]; then
                                        NEW_EXP=$(date -d "+$ADD_DAYS days" +%Y-%m-%d)
                                    else
                                        NEW_EXP=$(date -d "$CURR_EXP + $ADD_DAYS days" +%Y-%m-%d 2>/dev/null || date -d "+$ADD_DAYS days" +%Y-%m-%d)
                                    fi
                                    chage -E "$NEW_EXP" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID" "➕ <b>+$ADD_DAYS Días añadidos a $USERNAME</b>.\nNueva Expiración: <code>$NEW_EXP</code>"
                                else
                                    send_message "$CHAT_ID" "⚠️ Usuario no encontrado."
                                fi
                            fi
                            ;;

                        /renovarQ)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID" "➖ <b>Sintaxis:</b> <code>/renovarQ Usuario Días_Restar</code>"
                            else
                                USERNAME="$PARAM1"
                                SUB_DAYS="$PARAM2"
                                if id "$USERNAME" &>/dev/null; then
                                    CURR_EXP=$(chage -l "$USERNAME" | grep "Account expires" | awk -F: '{print $2}')
                                    if [[ "$CURR_EXP" == *"never"* ]] || [ -z "$CURR_EXP" ]; then
                                        NEW_EXP=$(date -d "+1 days" +%Y-%m-%d)
                                    else
                                        NEW_EXP=$(date -d "$CURR_EXP - $SUB_DAYS days" +%Y-%m-%d 2>/dev/null || date -d "+1 days" +%Y-%m-%d)
                                    fi
                                    chage -E "$NEW_EXP" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID" "➖ <b>-$SUB_DAYS Días restados a $USERNAME</b>.\nNueva Expiración: <code>$NEW_EXP</code>"
                                else
                                    send_message "$CHAT_ID" "⚠️ Usuario no encontrado."
                                fi
                            fi
                            ;;

                        /borrar|/eliminar)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID" "🗑️ <b>Sintaxis:</b> <code>/borrar Nombre_User</code>"
                            else
                                USERNAME="$PARAM1"
                                if id "$USERNAME" &>/dev/null; then
                                    userdel -f "$USERNAME" 2>/dev/null
                                    rm -f "/etc/kira/pass/$USERNAME" "/etc/kira/limits/$USERNAME"
                                    send_message "$CHAT_ID" "🗑️ El usuario <b>$USERNAME</b> fue eliminado correctamente del sistema VPS."
                                else
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> no existe."
                                fi
                            fi
                            ;;

                        /conectados|/online)
                            ONLINE_USERS=$(ps aux | grep sshd | grep -v root | grep -v grep | awk '{print $1}' | sort | uniq)

                            if [ -z "$ONLINE_USERS" ]; then
                                MSG="✨━━━━━━━━━━━━━━━━━━━━━━✨
👥 <b>USUARIOS CONECTADOS SSH</b>
✨━━━━━━━━━━━━━━━━━━━━━━✨
🟢 <b>No hay usuarios conectados actualmente.</b>
✨━━━━━━━━━━━━━━━━━━━━━━━━━━✨"
                            else
                                MSG="✨━━━━━━━━━━━━━━━━━━━━━━✨
👥 <b>USUARIOS CONECTADOS SSH</b>
✨━━━━━━━━━━━━━━━━━━━━━━✨\n"
                                TOTAL_CONN=0
                                for u in $ONLINE_USERS; do
                                    COUNT=$(ps aux | grep sshd | grep "$u" | grep -v grep | wc -l)
                                    [ -f "/etc/kira/limits/$u" ] && MAX_LIM=$(cat "/etc/kira/limits/$u") || MAX_LIM="1"

                                    MSG+="👤 <b>Usuario:</b> <code>$u</code>\n"
                                    MSG+="📱 <b>Dispositivos activos:</b> $COUNT / $MAX_LIM\n"
                                    MSG+="--------------------------------\n"
                                    TOTAL_CONN=$((TOTAL_CONN + COUNT))
                                done
                                MSG+="🌐 <b>Total Conexiones Activas:</b> <code>$TOTAL_CONN</code>
✨━━━━━━━━━━━━━━━━━━━━━━✨"
                            fi
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /infovps)
                            RAM_USED=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
                            UPTIME=$(uptime -p)
                            CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
                            MSG="⚙️ <b>INFORMACIÓN DEL VPS</b>

🌐 <b>IP VPS:</b> <code>$VPS_IP</code>
💾 <b>Uso RAM:</b> $RAM_USED
⚡ <b>Carga CPU:</b> $CPU_LOAD%
⏱ <b>Uptime:</b> $UPTIME"
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /reiniciar)
                            systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
                            send_message "$CHAT_ID" "⚡ <b>Servicios SSH reiniciados correctamente.</b>"
                            ;;
                    esac
                done
            fi
        fi
    fi
    sleep 1
done
EOF
    chmod +x "$BOT_SCRIPT"
}

start_bot() {
    if [ ! -f "$BOT_CONFIG" ]; then
        echo -e "\n ${R}❌ Primero debes configurar el Bot Token y los Admins (Opción 1).${N}"
        sleep 2.5
        return
    fi

    command -v jq &>/dev/null || apt-get install jq -y &>/dev/null

    stop_bot_process
    create_bot_daemon
    nohup bash "$BOT_SCRIPT" > /dev/null 2>&1 &
    echo $! > "$BOT_PID_FILE"
    echo -e "\n ${G}✔ Bot de Telegram iniciado correctamente.${N}"
    sleep 2
}

stop_bot_process() {
    if [ -f "$BOT_PID_FILE" ]; then
        kill -9 $(cat "$BOT_PID_FILE") 2>/dev/null
        rm -f "$BOT_PID_FILE"
    fi
    pkill -f "$BOT_SCRIPT" 2>/dev/null
}

stop_bot() {
    stop_bot_process
    echo -e "\n ${R}✖ Bot detenido exitosamente.${N}"
    sleep 1.5
}

kill_and_reset_bot() {
    clear
    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${R}              ⚠️  MATAR BOT Y BORRAR CONFIGURACIÓN                     ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
    echo ""
    read -p " ► ¿Estás seguro de continuar? (s/n): " confirm
    
    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        stop_bot_process
        rm -rf "$BOT_DIR"
        mkdir -p "$BOT_DIR"
        echo ""
        echo -e " ${G}✔ Bot destruido y sistema listo para configurar uno nuevo.${N}"
    else
        echo ""
        echo -e " ${C}Operación cancelada.${N}"
    fi
    sleep 2.5
}

config_bot() {
    clear
    if [ -f "$BOT_CONFIG" ]; then
        echo -e " ${Y}Ya existe un bot configurado. Usa la Opción [6] si deseas reemplazarlo.${N}"
        read -p " Presiona ENTER para volver..."
        return
    fi

    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${Y}                  ⚙️  CONFIGURACIÓN INICIAL DEL BOT                     ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
    echo ""
    read -p " ► Pegar BOT TOKEN: " token_input
    read -p " ► Pegar TELEGRAM ID(s) ADMIN: " admin_input

    token_clean=$(echo "$token_input" | tr -d '\r\n ')
    admin_clean=$(echo "$admin_input" | tr -d '\r\n ')

    if [ -n "$token_clean" ] && [ -n "$admin_clean" ]; then
        echo "TOKEN=\"$token_clean\"" > "$BOT_CONFIG"
        echo "ADMIN_IDS=\"$admin_clean\"" >> "$BOT_CONFIG"
        echo -e " ${G}✔ Configuración guardada exitosamente.${N}"
    else
        echo -e " ${R}❌ Datos inválidos.${N}"
    fi
    sleep 3
}

while true; do
clear
STATUS=$(check_bot_status)

echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 🤖   BOT DE TELEGRAM (GESTIÓN SSH)                     ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}ESTADO DEL BOT:${N} %-55b ${D}║${N}\n" "$STATUS"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${Y}[1]${N} CREAR / CONFIGURAR NUEVO BOT                                       ${D}║${N}"
echo -e "${D}║${N} ${Y}[2]${N} INICIAR BOT                                                        ${D}║${N}"
echo -e "${D}║${N} ${Y}[3]${N} DETENER BOT                                                        ${D}║${N}"
echo -e "${D}║${N} ${R}[6] MATAR Y RESTABLECER BOT${N}                                         ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                       ${D}║${N}"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona una opción: " option

case $option in
    1) config_bot ;;
    2) start_bot ;;
    3) stop_bot ;;
    6) kill_and_reset_bot ;;
    0|00) exit 0 ;;
    *)
        echo -e " ${R}❌ Selección inválida.${N}"
        sleep 1.5
        ;;
esac

done