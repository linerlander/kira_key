#!/bin/bash

# ========= COLORES =========
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

mkdir -p "$BOT_DIR"

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

# Limpieza estricta de variables de entorno
TOKEN=$(echo "$TOKEN" | tr -d '\r\n"')
ADMIN_ID=$(echo "$ADMIN_ID" | tr -d '\r\n"')

URL="https://api.telegram.org/bot$TOKEN"
OFFSET=0

send_message() {
    local chat_id="$1"
    local text="$2"
    curl -s -X POST "$URL/sendMessage" -d "chat_id=$chat_id" --data-urlencode "text=$text" -d "parse_mode=HTML" > /dev/null
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

                    # Comparación limpia sin caracteres extraños
                    CHAT_ID_CLEAN=$(echo "$CHAT_ID" | tr -d '\r\n ')
                    ADMIN_ID_CLEAN=$(echo "$ADMIN_ID" | tr -d '\r\n ')

                    if [ "$CHAT_ID_CLEAN" != "$ADMIN_ID_CLEAN" ]; then
                        send_message "$CHAT_ID" "⚠️ <b>Acceso Denegado.</b> Tu ID ($CHAT_ID_CLEAN) no está autorizado."
                        continue
                    fi

                    CMD=$(echo "$TEXT" | awk '{print $1}')
                    PARAM1=$(echo "$TEXT" | awk '{print $2}')
                    PARAM2=$(echo "$TEXT" | awk '{print $3}')
                    PARAM3=$(echo "$TEXT" | awk '{print $4}')
                    PARAM4=$(echo "$TEXT" | awk '{print $5}')

                    case "$CMD" in
                        /start|/menu)
                            MSG="🤖 <b>PANEL KIRA BOT DE TELEGRAM</b>

<b>Comandos disponibles:</b>
📊 /status - Estado del VPS
👥 /online - Usuarios SSH conectados
➕ /crear [user] [pass] [dias] [limite] - Crear SSH"
                            send_message "$CHAT_ID" "$MSG"
                            ;;
                        /status)
                            RAM_USED=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
                            UPTIME=$(uptime -p)
                            MSG="📊 <b>ESTADO DEL VPS</b>

💾 <b>RAM:</b> $RAM_USED
⏱ <b>Uptime:</b> $UPTIME"
                            send_message "$CHAT_ID" "$MSG"
                            ;;
                        /online)
                            ONLINE_COUNT=$(ps aux | grep sshd | grep -v root | grep -v grep | wc -l)
                            MSG="👥 <b>USUARIOS CONECTADOS</b>

🟢 <b>Conexiones activas:</b> $ONLINE_COUNT"
                            send_message "$CHAT_ID" "$MSG"
                            ;;
                        /crear)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ] || [ -z "$PARAM3" ]; then
                                send_message "$CHAT_ID" "❌ <b>Uso correcto:</b>
<code>/crear [usuario] [pass] [dias] [limite]</code>"
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
                                    
                                    echo "$(date +%s) ${DAYS}d" > "/etc/kira/expire/$USERNAME"
                                    echo "$LIMIT" > "/etc/kira/limits/$USERNAME"
                                    echo "$USERNAME $PASSWORD ${DAYS}d $LIMIT $(date)" >> /etc/kira/users.log

                                    EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)
                                    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null

                                    MSG="✅ <b>USUARIO CREADO CON ÉXITO</b>

👤 <b>Usuario:</b> <code>$USERNAME</code>
🔑 <b>Contraseña:</b> <code>$PASSWORD</code>
📅 <b>Días:</b> $DAYS días
📱 <b>Límite:</b> $LIMIT disps."
                                    send_message "$CHAT_ID" "$MSG"
                                fi
                            fi
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
        echo -e " ${R}❌ Primero debes configurar el Token y ID del Admin (Opción 1).${N}"
        sleep 2
        return
    fi

    command -v jq &>/dev/null || apt-get install jq -y &>/dev/null

    stop_bot
    create_bot_daemon
    nohup bash "$BOT_SCRIPT" > /dev/null 2>&1 &
    echo $! > "$BOT_PID_FILE"
    echo -e " ${G}✔ Bot de Telegram iniciado correctamente.${N}"
    sleep 2
}

stop_bot() {
    if [ -f "$BOT_PID_FILE" ]; then
        kill -9 $(cat "$BOT_PID_FILE") 2>/dev/null
        rm -f "$BOT_PID_FILE"
    fi
    pkill -f "$BOT_SCRIPT" 2>/dev/null
    echo -e " ${R}✖ Bot detenido.${N}"
    sleep 1.5
}

config_bot() {
    echo ""
    echo -e "${D}━━━━━━━━━━━━ CONFIGURACIÓN DE TELEGRAM ━━━━━━━━━━━━${N}"
    read -p " ► Ingresa el BOT TOKEN (de @BotFather): " token_input
    read -p " ► Ingresa tu TELEGRAM ID (de @userinfobot): " admin_input

    # Depuración automática de la entrada del usuario en el menú
    token_clean=$(echo "$token_input" | tr -d '\r\n ')
    admin_clean=$(echo "$admin_input" | tr -d '\r\n ')

    if [ -n "$token_clean" ] && [ -n "$admin_clean" ]; then
        echo "TOKEN=\"$token_clean\"" > "$BOT_CONFIG"
        echo "ADMIN_ID=\"$admin_clean\"" >> "$BOT_CONFIG"
        echo -e " ${G}✔ Datos guardados y depurados con éxito.${N}"
    else
        echo -e " ${R}❌ Los datos ingresados no son válidos.${N}"
    fi
    sleep 2
}

while true; do
clear
STATUS=$(check_bot_status)

echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 🤖   BOT DE TELEGRAM (GESTIÓN SSH)                     ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}ESTADO DEL BOT:${N} %-55b ${D}║${N}\n" "$STATUS"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${Y}[1]${N} CONFIGURAR TOKEN & ID ADMIN                                       ${D}║${N}"
echo -e "${D}║${N} ${Y}[2]${N} INICIAR BOT                                                        ${D}║${N}"
echo -e "${D}║${N} ${Y}[3]${N} DETENER BOT                                                        ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                       ${D}║${N}"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona una opción: " option

case $option in
    1) config_bot ;;
    2) start_bot ;;
    3) stop_bot ;;
    0|00) exit 0 ;;
    *)
        echo -e " ${R}❌ Selección inválida.${N}"
        sleep 1.5
        ;;
esac

done