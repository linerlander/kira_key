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

# Función que genera el ejecutable del bot
create_bot_daemon() {
    cat << 'EOF' > "$BOT_SCRIPT"
#!/bin/bash

BOT_DIR="/etc/kira/bot"
source "$BOT_DIR/bot.conf"

URL="https://api.telegram.org/bot$TOKEN"
OFFSET=0

send_message() {
    local chat_id="$1"
    local text="$2"
    curl -s -X POST "$URL/sendMessage" -d "chat_id=$chat_id" -d "text=$text" -d "parse_mode=HTML" > /dev/null
}

while true; do
    UPDATES=$(curl -s "$URL/getUpdates?offset=$OFFSET&timeout=10")
    
    # Procesar actualizaciones
    echo "$UPDATES" | grep -q '"ok":true' || { sleep 3; continue; }

    # Extraer el ID de actualización más alto
    UPDATE_IDS=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | cut -d: -f2)
    
    for update_id in $UPDATE_IDS; do
        OFFSET=$((update_id + 1))
        
        # Extraer datos del mensaje
        CHAT_ID=$(echo "$UPDATES" | grep -A 10 "$update_id" | grep -o '"chat":{"id":[0-9]*' | head -n1 | cut -d: -f3)
        TEXT=$(echo "$UPDATES" | grep -A 10 "$update_id" | grep -o '"text":"[^"]*' | head -n1 | cut -d'"' -f4)
        
        # Verificar que el mensaje venga del ADMIN
        if [ "$CHAT_ID" != "$ADMIN_ID" ]; then
            send_message "$CHAT_ID" "⚠️ <b>Acceso Denegado.</b> No estás autorizado para usar este bot."
            continue
        fi

        CMD=$(echo "$TEXT" | awk '{print $1}')
        PARAM1=$(echo "$TEXT" | awk '{print $2}')
        PARAM2=$(echo "$TEXT" | awk '{print $3}')
        PARAM3=$(echo "$TEXT" | awk '{print $4}')
        PARAM4=$(echo "$TEXT" | awk '{print $5}')

        case "$CMD" in
            /start|/menu)
                MSG="🤖 <b>PANEL KIRA BOT DE TELEGRAM</b>%0A%0A"
                MSG+="<b>Comandos disponibles:</b>%0A"
                MSG+="📊 /status - Estado del Servidor%0A"
                MSG+="👥 /online - Usuarios SSH conectados%0A"
                MSG+="➕ /crear [user] [pass] [dias] [limite] - Crear SSH%0A"
                send_message "$CHAT_ID" "$MSG"
                ;;
            /status)
                RAM_USED=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
                UPTIME=$(uptime -p)
                MSG="📊 <b>ESTADO DEL VPS</b>%0A%0A"
                MSG+="💾 <b>RAM:</b> $RAM_USED%0A"
                MSG+="⏱ <b>Uptime:</b> $UPTIME"
                send_message "$CHAT_ID" "$MSG"
                ;;
            /online)
                ONLINE_COUNT=$(ps aux | grep sshd | grep -v root | grep -v grep | wc -l)
                MSG="👥 <b>USUARIOS CONECTADOS</b>%0A%0A"
                MSG+="🟢 <b>Conexiones activas:</b> $ONLINE_COUNT"
                send_message "$CHAT_ID" "$MSG"
                ;;
            /crear)
                if [ -z "$PARAM1" ] || [ -z "$PARAM2" ] || [ -z "$PARAM3" ]; then
                    send_message "$CHAT_ID" "❌ <b>Uso correcto:</b>%0A<code>/crear [usuario] [pass] [dias] [limite]</code>"
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

                        MSG="✅ <b>USUARIO CREADO CON ÉXITO</b>%0A%0A"
                        MSG+="👤 <b>Usuario:</b> <code>$USERNAME</code>%0A"
                        MSG+="🔑 <b>Contraseña:</b> <code>$PASSWORD</code>%0A"
                        MSG+="📅 <b>Días:</b> $DAYS días%0A"
                        MSG+="📱 <b>Límite:</b> $LIMIT disps."
                        send_message "$CHAT_ID" "$MSG"
                    fi
                fi
                ;;
        esac
    done
    sleep 2
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

    if [ -n "$token_input" ] && [ -n "$admin_input" ]; then
        echo "TOKEN=\"$token_input\"" > "$BOT_CONFIG"
        echo "ADMIN_ID=\"$admin_input\"" >> "$BOT_CONFIG"
        echo -e " ${G}✔ Datos guardados con éxito.${N}"
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