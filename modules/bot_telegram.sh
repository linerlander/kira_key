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

mkdir -p "$BOT_DIR" /etc/kira/pass /etc/kira/expire /etc/kira/limits

# ========= SCRIPT PARA CREAR USUARIO DESDE TERMINAL O BOT =========
cat << 'EOF' > /usr/local/bin/crearuser
#!/bin/bash
USERNAME="$1"
PASSWORD="$2"
DAYS_INPUT="$3"
LIMIT="${4:-1}"

# Limpiar parámetro de días (eliminar letras como 'd')
DAYS=$(echo "$DAYS_INPUT" | grep -oE '[0-9]+')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$DAYS" ]; then
    echo -e "\033[1;31mUso: crearuser <usuario> <contraseña> <días> [límite]\033[0m"
    exit 1
fi

if id "$USERNAME" &>/dev/null; then
    echo -e "\033[1;33mEl usuario $USERNAME ya existe.\033[0m"
    exit 1
fi

useradd -M -s /bin/false "$USERNAME" 2>/dev/null
echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null

mkdir -p /etc/kira/pass /etc/kira/expire /etc/kira/limits
echo "$PASSWORD" > "/etc/kira/pass/$USERNAME"
echo "$LIMIT" > "/etc/kira/limits/$USERNAME"

# Calcular fecha exacta y guardarla en archivo de control
EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)
echo "$EXP_DATE" > "/etc/kira/expire/$USERNAME"

# Aplicar chage con la fecha exacta en formato YYYY-MM-DD
chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null

echo -e "\033[1;32m✔ Usuario $USERNAME creado exitosamente con clave '$PASSWORD' por $DAYS días (Expira: $EXP_DATE).\033[0m"
EOF
chmod +x /usr/local/bin/crearuser

# ========= SCRIPT PARA LISTAR USUARIOS DESDE TERMINAL =========
cat << 'EOF' > /usr/local/bin/verusers
#!/bin/bash
USERS_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

if [ -z "$USERS_LIST" ]; then
    echo -e "\033[1;31mNo hay usuarios SSH creados.\033[0m"
    exit 1
fi

echo "=========================================="
echo "      LISTA DE USUARIOS CREADOS           "
echo "=========================================="

count=1
for u in $USERS_LIST; do
    if [ -f "/etc/kira/pass/$u" ]; then
        PASS_VAL=$(cat "/etc/kira/pass/$u")
    else
        PASS_VAL="Encriptado / Creado fuera de Kira"
    fi
    
    # Leer directamente del archivo de expiración seguro
    if [ -f "/etc/kira/expire/$u" ]; then
        EXP_FMT=$(cat "/etc/kira/expire/$u")
    else
        EXP_FMT="NUNCA / SIN EXPIRACION"
    fi

    [ -f "/etc/kira/limits/$u" ] && LIM_VAL=$(cat "/etc/kira/limits/$u") || LIM_VAL="1"

    echo "USER ($count) : $u"
    echo "PASSWD   : $PASS_VAL"
    echo "EXPIRA   : $EXP_FMT"
    echo "LIMITE   : $LIM_VAL"
    echo "------------------------------------------"
    count=$((count+1))
done
EOF
chmod +x /usr/local/bin/verusers

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
[ -f "$BOT_DIR/bot.conf" ] && source "$BOT_DIR/bot.conf"

TOKEN=$(echo "$TOKEN" | tr -d '\r\n "')
URL="https://api.telegram.org/bot$TOKEN"
OFFSET=0
VPS_IP=$(curl -s --max-time 3 https://api.ipify.org || echo "VPS_IP")

send_message() {
    local chat_id="$1"
    local text="$2"
    curl -s -X POST "$URL/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=$text" > /dev/null
}

is_authorized() {
    local target_id="$1"
    source "$BOT_DIR/bot.conf"
    IFS=',' read -ra ADM_LIST <<< "$ADMIN_IDS"
    for id in "${ADM_LIST[@]}"; do
        clean_id=$(echo "$id" | tr -d ' "\r\n')
        if [ "$clean_id" == "$target_id" ]; then
            return 0
        fi
    done
    return 1
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
                    
                    CHAT_ID=$(echo "$UPDATES" | jq -r ".result[$i].message.chat.id // empty")
                    TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text // empty")
                    
                    [ -z "$TEXT" ] || [ "$TEXT" == "null" ] && continue
                    CHAT_ID_CLEAN=$(echo "$CHAT_ID" | tr -d '\r\n "')

                    if ! is_authorized "$CHAT_ID_CLEAN"; then
                        send_message "$CHAT_ID_CLEAN" "⚠️ <b>Acceso Denegado.</b> Tu ID (<code>$CHAT_ID_CLEAN</code>) no está autorizado."
                        continue
                    fi

                    CMD=$(echo "$TEXT" | awk '{print $1}')
                    PARAM1=$(echo "$TEXT" | awk '{print $2}')
                    PARAM2=$(echo "$TEXT" | awk '{print $3}')
                    PARAM3=$(echo "$TEXT" | awk '{print $4}')
                    PARAM4=$(echo "$TEXT" | awk '{print $5}')

                    case "$CMD" in
                        /start|/menu)
                            MSG="✨━━━━━━━━━━━━━━━━━━━━━✨
👑 <b>BIENVENIDO SUPER ADMIN PREMIUM</b>
✨━━━━━━━━━━━━━━━━━━━━━✨
😃 <i>MENU DE ACCIONES RÁPIDAS</i> 😃
✨━━━━━━━━━━━━━━━━━━━━━✨
🌐 <b>IP Asignada:</b> <code>$VPS_IP</code>
✨━━━━━━━━━━━━━━━━━━━━━✨

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

✨━━━━━━━━━━━━━━━━━━━━━✨"
                            send_message "$CHAT_ID_CLEAN" "$MSG"
                            ;;

                        /agregar|/crear)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ] || [ -z "$PARAM3" ]; then
                                MSG="✨━━━━━━━━━━━━━━━━━━━━━✨
<b>FORMA DE USAR ESTA OPCIÓN</b>
✨━━━━━━━━━━━━━━━━━━━━━✨

<i>DEBES ENVIAR EL COMANDO:</i>
<code>/agregar Nombre_User Clave Tiempo Limite</code>
✨━━━━━━━━━━━━━━━━━━━━━✨
<code>/agregar admin admin 30 1</code>
✨━━━━━━━━━━━━━━━━━━━━━✨"
                                send_message "$CHAT_ID_CLEAN" "$MSG"
                            else
                                USERNAME="$PARAM1"
                                PASSWORD="$PARAM2"
                                DAYS=$(echo "$PARAM3" | grep -oE '[0-9]+')
                                LIMIT="${PARAM4:-1}"

                                /usr/local/bin/crearuser "$USERNAME" "$PASSWORD" "$DAYS" "$LIMIT" > /dev/null 2>&1
                                EXP_DATE=$(cat "/etc/kira/expire/$USERNAME" 2>/dev/null || date -d "+$DAYS days" +%Y-%m-%d)

                                MSG="✅ <b>USUARIO CREADO CON ÉXITO</b>

👤 <b>Usuario:</b> <code>$USERNAME</code>
🔑 <b>Contraseña:</b> <code>$PASSWORD</code>
📅 <b>Días:</b> $DAYS días
📆 <b>Expiración:</b> <code>$EXP_DATE</code>
📱 <b>Límite:</b> $LIMIT dispositivo(s)
🌐 <b>IP:</b> <code>$VPS_IP</code>"
                                send_message "$CHAT_ID_CLEAN" "$MSG"
                            fi
                            ;;

                        /demo)
                            RAND_ID=$((RANDOM % 899999 + 100000))
                            DEMO_USER="Kira-$RAND_ID"
                            DEMO_PASS="123456"
                            DAYS=$(echo "${PARAM1:-1}" | grep -oE '[0-9]+')
                            [ -z "$DAYS" ] && DAYS=1

                            SSH_PORT=$(grep -i "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -n 1)
                            [ -z "$SSH_PORT" ] && SSH_PORT="22"

                            /usr/local/bin/crearuser "$DEMO_USER" "$DEMO_PASS" "$DAYS" "1" > /dev/null 2>&1
                            EXP_DATE=$(cat "/etc/kira/expire/$DEMO_USER" 2>/dev/null || date -d "+$DAYS days" +%Y-%m-%d)

                            MSG="✨━━━━━━━━━━━━━━━━━━━━━✨
🎁 <b>GENERAR CUENTA DEMO</b>
✨━━━━━━━━━━━━━━━━━━━━━✨
▶ <b>Usuario autogenerado:</b> <code>$DEMO_USER</code>
🔑 <b>Contraseña:</b> <code>$DEMO_PASS</code>
🔌 <b>Puerto SSH:</b> <code>$SSH_PORT</code>
► <b>Duración:</b> $DAYS día(s)
📆 <b>Expiración:</b> <code>$EXP_DATE</code>
📱 <b>Límite:</b> 1 Dispositivo
🌐 <b>IP VPS:</b> <code>$VPS_IP</code>
✨━━━━━━━━━━━━━━━━━━━━━✨"
                            send_message "$CHAT_ID_CLEAN" "$MSG"
                            ;;

                        /usuarios)
                            USERS_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
                            if [ -z "$USERS_LIST" ]; then
                                send_message "$CHAT_ID_CLEAN" "📋 <b>No hay usuarios SSH creados.</b>"
                            else
                                MSG=""
                                count=1
                                for u in $USERS_LIST; do
                                    if [ -f "/etc/kira/pass/$u" ]; then
                                        PASS_VAL=$(cat "/etc/kira/pass/$u")
                                    else
                                        PASS_VAL="Encriptado"
                                    fi
                                    
                                    if [ -f "/etc/kira/expire/$u" ]; then
                                        EXP_FMT=$(cat "/etc/kira/expire/$u")
                                    else
                                        EXP_FMT="NUNCA"
                                    fi

                                    [ -f "/etc/kira/limits/$u" ] && LIM_VAL=$(cat "/etc/kira/limits/$u") || LIM_VAL="1"

                                    MSG+="===========================
USER ($count) : <b>$u</b>
PASSWD : <code>$PASS_VAL</code>
EXPIRA : <code>$EXP_FMT</code>
LIMITE : <code>$LIM_VAL</code>
"
                                    count=$((count+1))
                                done
                                MSG+="==========================="
                                send_message "$CHAT_ID_CLEAN" "$MSG"
                            fi
                            ;;

                        /renovar)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID_CLEAN" "🔄 <b>Sintaxis:</b> <code>/renovar Usuario Días</code>"
                            else
                                USERNAME="$PARAM1"
                                DAYS=$(echo "$PARAM2" | grep -oE '[0-9]+')
                                if id "$USERNAME" &>/dev/null && [ -n "$DAYS" ]; then
                                    EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)
                                    echo "$EXP_DATE" > "/etc/kira/expire/$USERNAME"
                                    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID_CLEAN" "🔄 Usuario <b>$USERNAME</b> renovado a <b>$DAYS días</b> (F. Expiración: <code>$EXP_DATE</code>)."
                                else
                                    send_message "$CHAT_ID_CLEAN" "⚠️ El usuario <b>$USERNAME</b> no existe o los días son inválidos."
                                fi
                            fi
                            ;;

                        /renovarM)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID_CLEAN" "➕ <b>Sintaxis:</b> <code>/renovarM Usuario Días_Añadir</code>"
                            else
                                USERNAME="$PARAM1"
                                ADD_DAYS=$(echo "$PARAM2" | grep -oE '[0-9]+')
                                if id "$USERNAME" &>/dev/null && [ -n "$ADD_DAYS" ]; then
                                    if [ -f "/etc/kira/expire/$USERNAME" ]; then
                                        CURR_EXP=$(cat "/etc/kira/expire/$USERNAME")
                                        NEW_EXP=$(date -d "$CURR_EXP + $ADD_DAYS days" +%Y-%m-%d 2>/dev/null || date -d "+$ADD_DAYS days" +%Y-%m-%d)
                                    else
                                        NEW_EXP=$(date -d "+$ADD_DAYS days" +%Y-%m-%d)
                                    fi
                                    echo "$NEW_EXP" > "/etc/kira/expire/$USERNAME"
                                    chage -E "$NEW_EXP" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID_CLEAN" "➕ <b>+$ADD_DAYS Días añadidos a $USERNAME</b>. Nueva Expiración: <code>$NEW_EXP</code>"
                                else
                                    send_message "$CHAT_ID_CLEAN" "⚠️ Usuario no encontrado o días inválidos."
                                fi
                            fi
                            ;;

                        /renovarQ)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID_CLEAN" "➖ <b>Sintaxis:</b> <code>/renovarQ Usuario Días_Restar</code>"
                            else
                                USERNAME="$PARAM1"
                                SUB_DAYS=$(echo "$PARAM2" | grep -oE '[0-9]+')
                                if id "$USERNAME" &>/dev/null && [ -n "$SUB_DAYS" ]; then
                                    if [ -f "/etc/kira/expire/$USERNAME" ]; then
                                        CURR_EXP=$(cat "/etc/kira/expire/$USERNAME")
                                        NEW_EXP=$(date -d "$CURR_EXP - $SUB_DAYS days" +%Y-%m-%d 2>/dev/null || date -d "+1 days" +%Y-%m-%d)
                                    else
                                        NEW_EXP=$(date -d "+1 days" +%Y-%m-%d)
                                    fi
                                    echo "$NEW_EXP" > "/etc/kira/expire/$USERNAME"
                                    chage -E "$NEW_EXP" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID_CLEAN" "➖ <b>-$SUB_DAYS Días restados a $USERNAME</b>. Nueva Expiración: <code>$NEW_EXP</code>"
                                else
                                    send_message "$CHAT_ID_CLEAN" "⚠️ Usuario no encontrado o días inválidos."
                                fi
                            fi
                            ;;

                        /aggADM)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID_CLEAN" "🔐 <b>Sintaxis:</b> <code>/aggADM TELEGRAM_ID</code>"
                            else
                                NEW_ADM="$PARAM1"
                                source "$BOT_CONFIG"
                                if [[ "$ADMIN_IDS" == *"$NEW_ADM"* ]]; then
                                    send_message "$CHAT_ID_CLEAN" "⚠️ El ID <code>$NEW_ADM</code> ya es Administrador."
                                else
                                    UPDATED_IDS="$ADMIN_IDS, $NEW_ADM"
                                    echo "TOKEN=\"$TOKEN\"" > "$BOT_CONFIG"
                                    echo "ADMIN_IDS=\"$UPDATED_IDS\"" >> "$BOT_CONFIG"
                                    send_message "$CHAT_ID_CLEAN" "✅ <b>Nuevo Admin Autorizado:</b> <code>$NEW_ADM</code>"
                                fi
                            fi
                            ;;

                        /creditos)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID_CLEAN" "💳 <b>Sintaxis:</b> <code>/creditos TELEGRAM_ID Cantidad_Días</code>"
                            else
                                TARGET_ADM="$PARAM1"
                                CRED_VAL="$PARAM2"
                                echo "$CRED_VAL" > "/etc/kira/bot/credits_$TARGET_ADM"
                                send_message "$CHAT_ID_CLEAN" "💳 <b>Créditos/Días autorizados:</b> <code>$CRED_VAL</code> al Admin ID: <code>$TARGET_ADM</code>"
                            fi
                            ;;

                        /admkill)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID_CLEAN" "🚫 <b>Sintaxis:</b> <code>/admkill TELEGRAM_ID</code>"
                            else
                                TARGET_ADM="$PARAM1"
                                source "$BOT_CONFIG"
                                NEW_LIST=$(echo "$ADMIN_IDS" | sed "s/$TARGET_ADM//g" | sed 's/,,/,/g' | sed 's/^,//g' | sed 's/,$//g')
                                echo "TOKEN=\"$TOKEN\"" > "$BOT_CONFIG"
                                echo "ADMIN_IDS=\"$NEW_LIST\"" >> "$BOT_CONFIG"
                                send_message "$CHAT_ID_CLEAN" "🚫 <b>Autorización revocada exitosamente para el ID:</b> <code>$TARGET_ADM</code>"
                            fi
                            ;;

                        /conectados|/online)
                            TOTAL_CONN=0
                            ONLINE_USERS=$(ps aux | grep sshd | grep -v root | grep -v grep | awk '{print $1}' | sort | uniq)

                            if [ -z "$ONLINE_USERS" ]; then
                                MSG="✨━━━━━━━━━━━━━━━━━━━━━✨
👥 <b>USUARIOS CONECTADOS SSH</b>
✨━━━━━━━━━━━━━━━━━━━━━✨
🟢 <b>No hay usuarios conectados actualmente.</b>
✨━━━━━━━━━━━━━━━━━━━━━━━━━✨"
                            else
                                MSG="✨━━━━━━━━━━━━━━━━━━━━━✨
👥 <b>USUARIOS CONECTADOS SSH</b>
✨━━━━━━━━━━━━━━━━━━━━━✨

"
                                for u in $ONLINE_USERS; do
                                    COUNT=$(ps aux | grep sshd | grep "$u" | grep -v grep | wc -l)
                                    TIME_ONLINE=$(who | grep "$u" | awk '{print $4}' | head -n 1)
                                    [ -z "$TIME_ONLINE" ] && TIME_ONLINE="Activo"

                                    [ -f "/etc/kira/limits/$u" ] && MAX_LIM=$(cat "/etc/kira/limits/$u") || MAX_LIM="1"

                                    MSG+="👤 <b>Usuario:</b> <code>$u</code>
"
                                    MSG+="📱 <b>Dispositivos activos:</b> $COUNT / $MAX_LIM
"
                                    MSG+="⏱ <b>Hora conexión:</b> $TIME_ONLINE
"
                                    MSG+="--------------------------------
"
                                    TOTAL_CONN=$((TOTAL_CONN + COUNT))
                                done
                                MSG+="🌐 <b>Total Conexiones Activas:</b> <code>$TOTAL_CONN</code>
✨━━━━━━━━━━━━━━━━━━━━━✨"
                            fi
                            send_message "$CHAT_ID_CLEAN" "$MSG"
                            ;;

                        /borrar|/eliminar)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID_CLEAN" "🗑️ <b>Sintaxis:</b> <code>/borrar Nombre_User</code>"
                            else
                                USERNAME="$PARAM1"
                                if id "$USERNAME" &>/dev/null; then
                                    userdel -f "$USERNAME" 2>/dev/null
                                    rm -f "/etc/kira/expire/$USERNAME" "/etc/kira/limits/$USERNAME" "/etc/kira/pass/$USERNAME"
                                    send_message "$CHAT_ID_CLEAN" "🗑️ El usuario <b>$USERNAME</b> fue eliminado correctamente."
                                else
                                    send_message "$CHAT_ID_CLEAN" "⚠️ El usuario <b>$USERNAME</b> no existe."
                                fi
                            fi
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
                            send_message "$CHAT_ID_CLEAN" "$MSG"
                            ;;

                        /liberados)
                            USERS_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
                            LIBERADOS=""
                            for u in $USERS_LIST; do
                                if [ -f "/etc/kira/limits/$u" ]; then
                                    lim=$(cat "/etc/kira/limits/$u")
                                    [ "$lim" -ge 99 ] 2>/dev/null && LIBERADOS+=" • <code>$u</code> (Límite: $lim)\n"
                                fi
                            done
                            if [ -z "$LIBERADOS" ]; then
                                send_message "$CHAT_ID_CLEAN" "🔓 <b>No hay usuarios liberados en este VPS.</b>"
                            else
                                send_message "$CHAT_ID_CLEAN" "🔓 <b>USUARIOS LIBERADOS:</b>\n$LIBERADOS"
                            fi
                            ;;

                        /reiniciar)
                            systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
                            send_message "$CHAT_ID_CLEAN" "⚡ <b>Servicios SSH/WS reiniciados correctamente.</b>"
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
    echo -e " ${W}Esta opción matará el proceso activo y eliminará la configuración actual.${N}"
    read -p " ► ¿Estás seguro de continuar? (s/n): " confirm
    
    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        stop_bot_process
        rm -rf "$BOT_DIR"
        mkdir -p "$BOT_DIR"
        echo ""
        echo -e " ${G}✔ Bot destruido y sistema listo para configurar un nuevo bot.${N}"
    else
        echo ""
        echo -e " ${C}Operación cancelada.${N}"
    fi
    sleep 2.5
}

config_bot() {
    clear
    if [ -f "$BOT_CONFIG" ]; then
        echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
        echo -e "${D}║${R}                   ⚠️  YA EXISTE UN BOT CONFIGURADO                    ${D}║${N}"
        echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
        echo ""
        echo -e " ${Y}Solo se permite un (1) Bot activo por servidor VPS.${N}"
        echo -e " ${W}Si deseas reemplazarlo, usa primero la Opción [6] MATAR Y RESTABLECER.${N}"
        echo ""
        read -p " Presiona ENTER para volver..."
        return
    fi

    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${Y}                   ⚙️  CONFIGURACIÓN INICIAL DEL BOT                    ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
    echo ""
    read -p " ► Pegar BOT TOKEN: " token_input
    read -p " ► Pegar TELEGRAM ID(s) ADMIN: " admin_input

    token_clean=$(echo "$token_input" | tr -d '\r\n ')
    admin_clean=$(echo "$admin_input" | tr -d '\r\n ')

    if [ -n "$token_clean" ] && [ -n "$admin_clean" ]; then
        echo "TOKEN=\"$token_clean\"" > "$BOT_CONFIG"
        echo "ADMIN_IDS=\"$admin_clean\"" >> "$BOT_CONFIG"
        echo ""
        echo -e " ${G}✔ Configuración guardada exitosamente.${N}"
    else
        echo ""
        echo -e " ${R}❌ Datos inválidos.${N}"
    fi
    sleep 3
}

add_admins() {
    clear
    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${Y}                👥  AÑADIR ADMINISTRADORES AL BOT                     ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
    echo ""

    if [ ! -f "$BOT_CONFIG" ]; then
        echo -e " ${R}❌ El bot debe estar configurado primero (Opción 1).${N}"
        sleep 2.5
        return
    fi

    source "$BOT_CONFIG"
    echo -e " 👑 ${W}Admins Autorizados Activos:${N} ${Y}$ADMIN_IDS${N}"
    echo ""

    read -p " ► Ingresar nuevo(s) ID(s) separados por comas: " new_ids_input
    new_ids_clean=$(echo "$new_ids_input" | tr -d '\r\n ')

    if [ -n "$new_ids_clean" ]; then
        UPDATED_IDS="$ADMIN_IDS, $new_ids_clean"
        echo "TOKEN=\"$TOKEN\"" > "$BOT_CONFIG"
        echo "ADMIN_IDS=\"$UPDATED_IDS\"" >> "$BOT_CONFIG"
        
        if [ -f "$BOT_PID_FILE" ] && kill -0 $(cat "$BOT_PID_FILE") 2>/dev/null; then
            start_bot
        fi

        echo ""
        echo -e " ${G}✔ Nuevos administradores agregados exitosamente.${N}"
    else
        echo ""
        echo -e " ${R}❌ Entrada vacía.${N}"
    fi
    sleep 2.5
}

show_bot_info() {
    clear
    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${Y}                     ℹ️  INFORMACIÓN DEL BOT                           ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
    echo ""

    if [ ! -f "$BOT_CONFIG" ]; then
        echo -e " ${R}❌ El bot no ha sido configurado aún.${N}"
    else
        source "$BOT_CONFIG"
        TOKEN_CLEAN=$(echo "$TOKEN" | tr -d '\r\n"')
        
        command -v jq &>/dev/null || apt-get install jq -y &>/dev/null
        ME_RESPONSE=$(curl -s "https://api.telegram.org/bot$TOKEN_CLEAN/getMe")
        
        IS_OK=$(echo "$ME_RESPONSE" | jq -r '.ok' 2>/dev/null)

        if [ "$IS_OK" == "true" ]; then
            BOT_NAME=$(echo "$ME_RESPONSE" | jq -r '.result.first_name')
            BOT_USER=$(echo "$ME_RESPONSE" | jq -r '.result.username')

            echo -e " 🤖 ${W}Nombre Bot:${N} $BOT_NAME"
            echo -e " 🔗 ${W}Username:${N} @$BOT_USER"
            echo -e " 🔑 ${W}Token:${N} ${TOKEN_CLEAN:0:10}...${TOKEN_CLEAN:-5}"
            echo -e " 👑 ${W}Admins Permitidos:${N} $ADMIN_IDS"
            
            if [ -f "$BOT_PID_FILE" ]; then
                PID_VAL=$(cat "$BOT_PID_FILE")
                echo -e " ⚙️  ${W}PID en Proceso:${N} $PID_VAL"
            fi
            
            echo -e " 🟢 ${W}Estado API:${N} ${G}Conexión Exitosa con Telegram${N}"
        else
            echo -e " 🔴 ${W}Estado API:${N} ${R}Token Inválido o Error de Conexión${N}"
        fi
    fi

    echo ""
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    read -p " Presiona ENTER para volver al menú..."
}

while true; do
clear
STATUS=$(check_bot_status)

echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 🤖   BOT DE TELEGRAM (GESTIÓN SSH)                     ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}ESTADO DEL BOT:${N} %-55b ${D}║${N}\n" "$STATUS"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${Y}[1]${N} CREAR / CONFIGURAR NUEVO BOT (Solo 1 Bot por VPS)                  ${D}║${N}"
echo -e "${D}║${N} ${Y}[2]${N} AÑADIR NUEVOS ADMINS (Agregar IDs a la lista existente)             ${D}║${N}"
echo -e "${D}║${N} ${Y}[3]${N} INICIAR BOT                                                        ${D}║${N}"
echo -e "${D}║${N} ${Y}[4]${N} DETENER BOT                                                        ${D}║${N}"
echo -e "${D}║${N} ${Y}[5]${N} MOSTRAR INFORMACIÓN DEL BOT                                        ${D}║${N}"
echo -e "${D}║${N} ${R}[6] MATAR Y RESTABLECER BOT (Eliminar bot actual para crear uno nuevo)${N} ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                       ${D}║${N}"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona una opción: " option

case $option in
    1) config_bot ;;
    2) add_admins ;;
    3) start_bot ;;
    4) stop_bot ;;
    5) show_bot_info ;;
    6) kill_and_reset_bot ;;
    0|00) exit 0 ;;
    *)
        echo -e " ${R}❌ Selección inválida.${N}"
        sleep 1.5
        ;;
esac

done