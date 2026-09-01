#!/bin/bash

# ========= PALETA DE COLORES (ESTILO NEÓN / MORADO) =========
W='\033[1;37m'
D='\033[38;5;183m'
M='\033[38;5;129m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;39m'
G='\033[38;5;82m'
N='\033[0m'

# FUNCIONES DE DIBUJO (Garantizan exactamente 71 caracteres internos)
draw_top()    { echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"; }
draw_mid()    { echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"; }
draw_bot()    { echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"; }
draw_title()  { printf "${D}║${M} %-69s ${D}║${N}\n" "                 🔒 SERVICIO SSL / TLS ( STUNNEL4 )"; }
draw_step()   { printf "${D}║${N} ${C}%-70s${N}${D}║${N}\n" "$1"; }

# ================= VERIFICAR ESTADO ACTUAL =================
if systemctl is-active --quiet stunnel4 2>/dev/null || pgrep -x "stunnel4" >/dev/null || pgrep -x "stunnel" >/dev/null; then
    STATUS_TEXT="ACTIVO (ON)"
    STATUS_COLOR="${G}"
    IS_ACTIVE=true
else
    STATUS_TEXT="DETENIDO (OFF)"
    STATUS_COLOR="${R}"
    IS_ACTIVE=false
fi

# Cálculo dinámico de espacios para que el borde cierre perfecto
PAD_LEN=$(( 71 - 15 - ${#STATUS_TEXT} ))

clear
draw_top
draw_title
draw_mid
printf "${D}║${N} ${W}Estado actual:${N} ${STATUS_COLOR}%b${N}$(printf '%*s' "$PAD_LEN" "") ${D}║${N}\n" "$STATUS_TEXT"
draw_mid

# ================= LÓGICA DE INTERRUPTOR (ON/OFF) =================
if [ "$IS_ACTIVE" = true ]; then
    printf "${D}║${N} ${W}[1]${N} ${C}%-66s${N}${D}║${N}\n" "Detener Servicio SSL/TLS (Apagar)"
    printf "${D}║${N} ${W}[2]${N} ${C}%-66s${N}${D}║${N}\n" "Reinstalar / Actualizar Dominio"
    printf "${D}║${N} ${W}[0]${N} ${R}%-66s${N}${D}║${N}\n" "Regresar al menú principal"
    draw_bot
    echo ""
    read -p " ➤ Opción: " opc

    case $opc in
        1)
            echo -e "\n ${C}Deteniendo Stunnel4 y liberando puerto 443...${N}"
            systemctl stop stunnel4 >/dev/null 2>&1
            systemctl disable stunnel4 >/dev/null 2>&1
            killall -9 stunnel4 stunnel >/dev/null 2>&1
            echo -e " ${G}✔ Servicio apagado correctamente.${N}"
            sleep 2
            exit 0
            ;;
        2)
            # Continúa con la instalación normal abajo
            ;;
        0) exit 0 ;;
        *) echo -e " ${R}✘ Opción inválida.${N}"; sleep 1; exit 0 ;;
    esac
else
    printf "${D}║${N} ${W}[1]${N} ${C}%-66s${N}${D}║${N}\n" "Instalar / Encender SSL/TLS"
    printf "${D}║${N} ${W}[0]${N} ${R}%-66s${N}${D}║${N}\n" "Regresar al menú principal"
    draw_bot
    echo ""
    read -p " ➤ Opción: " opc

    case $opc in
        1)
            # Continúa con la instalación normal abajo
            ;;
        0) exit 0 ;;
        *) echo -e " ${R}✘ Opción inválida.${N}"; sleep 1; exit 0 ;;
    esac
fi

# ================= INSTALACIÓN Y CONFIGURACIÓN =================
clear
draw_top
draw_title
draw_mid

# SOLICITAR DOMINIO
DOMAIN=""
while [ -z "$DOMAIN" ]; do
    printf "${D}║${N} ${C}%-70s${N}${D}║${N}\n" "Ingresa tu Dominio / SNI:"
    echo -ne "${D}║${N} ${Y}➤ ${N}"
    read DOMAIN
    
    DOMAIN=$(echo "$DOMAIN" | xargs) # Limpia espacios accidentales
    
    if [ -z "$DOMAIN" ]; then
        echo -e "\033[1A\033[K${D}║${N} ${R}✘ El dominio no puede estar vacío.${N}$(printf '%*s' "36" "")${D}║${N}"
    else
        PAD_DOMAIN=$(( 68 - ${#DOMAIN} ))
        echo -e "\033[1A\033[K${D}║${N} ${Y}➤ ${W}${DOMAIN}${N}$(printf '%*s' "$PAD_DOMAIN" "")${D}║${N}"
    fi
done

draw_mid
printf "${D}║${N} ${W}Dominio configurado:${N} ${Y}%s${N}$(printf '%*s' "$(( 50 - ${#DOMAIN} ))" "")${D}║${N}\n" "$DOMAIN"
draw_mid

# PASO 1
draw_step "[1/5] Instalando Stunnel4, OpenSSL y dependencias..."
apt-get update -y >/dev/null 2>&1
apt-get install stunnel4 openssl psmisc net-tools -y >/dev/null 2>&1

# PASO 2
draw_step "[2/5] Desalojando puerto 443 de SSH y sockets activos..."
if grep -qE "^Port 443" /etc/ssh/sshd_config; then
    sed -i '/^Port 443/d' /etc/ssh/sshd_config
    systemctl restart ssh >/dev/null 2>&1
fi
if systemctl is-active --quiet ssh.socket 2>/dev/null; then
    systemctl stop ssh.socket >/dev/null 2>&1
    systemctl disable ssh.socket >/dev/null 2>&1
fi
fuser -k 443/tcp >/dev/null 2>&1 || true

# PASO 3
draw_step "[3/5] Generando nuevo certificado SSL/TLS (.pem)..."
rm -f /etc/stunnel/stunnel.pem
mkdir -p /etc/stunnel

openssl req -new -x509 -days 365 -nodes \
    -out /etc/stunnel/stunnel.pem \
    -keyout /etc/stunnel/stunnel.pem \
    -subj "/C=PE/ST=Lima/L=Lima/O=Kira/CN=${DOMAIN}" >/dev/null 2>&1
chmod 600 /etc/stunnel/stunnel.pem

# PASO 4
draw_step "[4/5] Aplicando reglas de enrutamiento en Stunnel..."
rm -f /etc/stunnel/stunnel.conf
mkdir -p /var/run/stunnel4
chown -R stunnel4:stunnel4 /var/run/stunnel4 2>/dev/null

cat << EOF > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel4/stunnel4.pid
cert = /etc/stunnel/stunnel.pem
client = no

[SSL_WS]
accept = 443
connect = 127.0.0.1:80

[SSL_SSH]
accept = 444
connect = 127.0.0.1:22
EOF

sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4 2>/dev/null

# PASO 5
draw_step "[5/5] Reiniciando y activando servicio Stunnel4..."
killall -9 stunnel4 stunnel 2>/dev/null || true
systemctl daemon-reload
systemctl enable stunnel4 >/dev/null 2>&1
systemctl restart stunnel4 >/dev/null 2>&1

if ! systemctl is-active --quiet stunnel4; then
    stunnel4 /etc/stunnel/stunnel.conf >/dev/null 2>&1
fi

draw_mid

# ================= COMPROBACIÓN FINAL =================
if systemctl is-active --quiet stunnel4 || pgrep -x "stunnel4" >/dev/null || pgrep -x "stunnel" >/dev/null; then
    printf "${D}║${N} Status: ${G}[ONLINE]${N} - Puerto ${Y}443${N} asignado con éxito.                ${D}║${N}\n"
    printf "${D}║${N} Puertos activos: ${Y}443 (SSL->WS)${N} | ${Y}444 (SSL->SSH)${N}                   ${D}║${N}\n"
else
    printf "${D}║${N} Status: ${R}[ERROR]${N} - Fallo al iniciar el puerto 443.                 ${D}║${N}\n"
fi

draw_bot
echo ""
read -p " Presiona Enter para continuar..."