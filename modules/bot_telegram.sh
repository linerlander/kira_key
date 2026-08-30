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

TOKEN=$(echo "$TOKEN" | tr -d '\r\n"')
ADMIN_IDS=$(echo "$ADMIN_IDS" | tr -d '\r\n"')

URL="https://api.telegram.org/bot$TOKEN"
OFFSET=0

send_message() {
    local chat_id="$1"
    local text="$2"
    curl -s -X POST "$URL/sendMessage" -d "chat_id=$chat_id" --data-urlencode "text=$text" -d "parse_mode=HTML" > /dev/null
}

is_authorized() {
    local target_id="$1"
    IFS=',' read -ra ADM_LIST <<< "$ADMIN_IDS"
    for id in "${ADM_LIST[@]}"; do
        clean_id=$(echo "$id" | tr -d ' ')
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
                    
                    CHAT_ID=$(echo "$UPDATES" | jq -r ".result[$i].message.chat.id")
                    TEXT=$(echo "$UPDATES" | jq -r ".result[$i].message.text")
                    
                    [ "$TEXT" == "null" ] && continue

                    CHAT_ID_CLEAN=$(echo "$CHAT_ID" | tr -d '\r\n ')

                    if ! is_authorized "$CHAT_ID_CLEAN"; then
                        send_message "$CHAT_ID" "⚠️ <b>Acceso Denegado.</b> Tu ID ($CHAT_ID_CLEAN) no está en la lista de administradores autorizados."
                        continue
                    fi

                    CMD=$(echo "$TEXT" | awk '{print $1}')
                    PARAM1=$(echo "$TEXT" | awk '{print $2}')
                    PARAM2=$(echo "$TEXT" | awk '{print $3}')
                    PARAM3=$(echo "$TEXT" | awk '{print $4}')
                    PARAM4=$(echo "$TEXT" | awk '{print $5}')

                    case "$CMD" in
                        /start|/menu)
                            MSG="🤖 <b>PANEL KIRA VIP DE TELEGRAM</b>

<b>Comandos disponibles:</b>
📊 /status - Estado del Servidor (RAM, CPU, Uptime)
👥 /online - Conexiones SSH activas
📋 /usuarios - Lista de usuarios SSH y fechas de vencimiento
➕ /crear [user] [pass] [dias] [limite] - Crear usuario SSH
❌ /eliminar [user] - Eliminar cuenta SSH
🔄 /renovar [user] [dias] - Extender vigencia de usuario
🔒 /bloquear [user] - Suspender acceso a usuario
🔓 /desbloquear [user] - Reactivar cuenta suspendida
⚡ /reiniciar - Reiniciar servicios SSH/WS"
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /status)
                            RAM_USED=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
                            UPTIME=$(uptime -p)
                            CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
                            MSG="📊 <b>ESTADO DEL VPS</b>

💾 <b>Uso de RAM:</b> $RAM_USED
⚡ <b>Carga CPU:</b> $CPU_LOAD%
⏱ <b>Uptime:</b> $UPTIME"
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /online)
                            ONLINE_COUNT=$(ps aux | grep sshd | grep -v root | grep -v grep | wc -l)
                            MSG="👥 <b>USUARIOS CONECTADOS</b>

🟢 <b>Conexiones activas:</b> $ONLINE_COUNT dispositivo(s)."
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /usuarios)
                            USERS_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
                            if [ -z "$USERS_LIST" ]; then
                                MSG="📋 <b>No hay usuarios SSH creados en el sistema.</b>"
                            else
                                MSG="📋 <b>LISTA DE USUARIOS SSH:</b>%0A"
                                for u in $USERS_LIST; do
                                    EXP=$(chage -l "$u" | grep "Account expires" | awk -F: '{print $2}')
                                    MSG+="👤 <code>$u</code> | Vence:$EXP%0A"
                                done
                            fi
                            send_message "$CHAT_ID" "$MSG"
                            ;;

                        /crear)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ] || [ -z "$PARAM3" ]; then
                                send_message "$CHAT_ID" "❌ <b>Sintaxis incorrecta.</b>
Uso: <code>/crear [usuario] [contraseña] [dias] [limite]</code>"
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
📱 <b>Límite:</b> $LIMIT dispositivo(s)"
                                    send_message "$CHAT_ID" "$MSG"
                                fi
                            fi
                            ;;

                        /eliminar)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID" "❌ <b>Sintaxis incorrecta.</b>
Uso: <code>/eliminar [usuario]</code>"
                            else
                                USERNAME="$PARAM1"
                                if id "$USERNAME" &>/dev/null; then
                                    userdel -f "$USERNAME" 2>/dev/null
                                    rm -f "/etc/kira/expire/$USERNAME" "/etc/kira/limits/$USERNAME"
                                    send_message "$CHAT_ID" "🗑️ El usuario <b>$USERNAME</b> fue eliminado correctamente."
                                else
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> no existe."
                                fi
                            fi
                            ;;

                        /renovar)
                            if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
                                send_message "$CHAT_ID" "❌ <b>Sintaxis incorrecta.</b>
Uso: <code>/renovar [usuario] [dias_adicionales]</code>"
                            else
                                USERNAME="$PARAM1"
                                DAYS="$PARAM2"
                                if id "$USERNAME" &>/dev/null; then
                                    EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)
                                    chage -E "$EXP_DATE" "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID" "🔄 Usuario <b>$USERNAME</b> renovado por $DAYS días más (Vence: $EXP_DATE)."
                                else
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> no existe."
                                fi
                            fi
                            ;;

                        /bloquear)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID" "❌ <b>Sintaxis incorrecta.</b>
Uso: <code>/bloquear [usuario]</code>"
                            else
                                USERNAME="$PARAM1"
                                if id "$USERNAME" &>/dev/null; then
                                    usermod -L "$USERNAME" 2>/dev/null
                                    pkill -u "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID" "🔒 El usuario <b>$USERNAME</b> ha sido bloqueado y desconectado."
                                else
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> no existe."
                                fi
                            fi
                            ;;

                        /desbloquear)
                            if [ -z "$PARAM1" ]; then
                                send_message "$CHAT_ID" "❌ <b>Sintaxis incorrecta.</b>
Uso: <code>/desbloquear [usuario]</code>"
                            else
                                USERNAME="$PARAM1"
                                if id "$USERNAME" &>/dev/null; then
                                    usermod -U "$USERNAME" 2>/dev/null
                                    send_message "$CHAT_ID" "🔓 El usuario <b>$USERNAME</b> ha sido desbloqueado exitosamente."
                                else
                                    send_message "$CHAT_ID" "⚠️ El usuario <b>$USERNAME</b> no existe."
                                fi
                            fi
                            ;;

                        /reiniciar)
                            systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
                            send_message "$CHAT_ID" "⚡ <b>Servicios SSH/WS reiniciados correctamente.</b>"
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
        echo -e "\n ${R}❌ Primero debes configurar el Bot Token y los Admins.${N}"
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
    echo -e " ${Y}Utiliza esto únicamente si deseas cambiar de Bot Token o crear uno nuevo.${N}"
    echo ""
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
    # Si ya existe configuración, exige matar el bot primero para crear otro
    if [ -f "$BOT_CONFIG" ]; then
        echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
        echo -e "${D}║${R}                   ⚠️  YA EXISTE UN BOT CONFIGURADO                    ${D}║${N}"
        echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
        echo ""
        echo -e " ${Y}Solo se permite un (1) Bot activo por servidor VPS.${N}"
        echo -e " ${W}Si deseas reemplazarlo o cambiar de Token, debes usar primero la:${N}"
        echo -e " ${R}Opción [5] MATAR Y RESTABLECER BOT${N}"
        echo ""
        read -p " Presiona ENTER para volver al menú principal..."
        return
    fi

    echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${D}║${Y}                  ⚙️  CONFIGURACIÓN INICIAL DEL BOT                     ${D}║${N}"
    echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e " ${C}📌 PASO 1: OBTIENE TU TOKEN DE BOT${N}"
    echo -e "    1. Abre Telegram, busca a ${Y}@BotFather${N} y envíale ${W}/newbot${N}"
    echo -e "    2. Copia el TOKEN recibido (ejemplo: 123456789:ABCdef...)"
    echo ""
    echo -e " ${C}📌 PASO 2: OBTIENE TU TELEGRAM ID (NUMÉRICO)${N}"
    echo -e "    1. En Telegram, busca a ${Y}@userinfobot${N} y presiona 'Iniciar'."
    echo -e "    2. Copia la numeración que aparece en ${W}Id:${N} (Solo números)."
    echo ""
    echo -e " ${Y}💡 NOTA (MULTI-ADMINISTRADOR):${N}"
    echo -e "    Puedes ingresar varios IDs separados por comas. Ej: ${W}8526723207, 987654321${N}"
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
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
        echo -e " ${R}❌ Datos inválidos. Debes completar ambos campos.${N}"
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
    echo -e " 👑 ${W}Admins Autorizados Actualmente:${N} ${Y}$ADMIN_IDS${N}"
    echo ""
    echo -e " Ingresa el nuevo o nuevos Telegram ID numéricos que deseas autorizar."
    echo -e " (Si son varios, sepáralos por comas. Ej: 1122334455, 6677889900)"
    echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo ""

    read -p " ► Ingresar nuevo(s) ID(s): " new_ids_input
    new_ids_clean=$(echo "$new_ids_input" | tr -d '\r\n ')

    if [ -n "$new_ids_clean" ]; then
        UPDATED_IDS="$ADMIN_IDS, $new_ids_clean"
        echo "TOKEN=\"$TOKEN\"" > "$BOT_CONFIG"
        echo "ADMIN_IDS=\"$UPDATED_IDS\"" >> "$BOT_CONFIG"
        
        # Reiniciar bot para aplicar cambios si estaba activo
        if [ -f "$BOT_PID_FILE" ] && kill -0 $(cat "$BOT_PID_FILE") 2>/dev/null; then
            start_bot
        fi

        echo ""
        echo -e " ${G}✔ Nuevos administradores agregados exitosamente.${N}"
    else
        echo ""
        echo -e " ${R}❌ Entrada vacía. Operación cancelada.${N}"
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