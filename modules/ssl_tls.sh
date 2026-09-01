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

# Ancho interno fijo: exactamente 69 caracteres de contenido útil
BOX_WIDTH=69

draw_top()    { echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"; }
draw_mid()    { echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"; }
draw_bot()    { echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"; }

draw_title()  {
    printf "${D}║${M} %-${BOX_WIDTH}s   ${D}║${N}\n" "           🔒 SERVICIO SSL / TLS ( STUNNEL4 )"
}

draw_step_line() {
    local text="$1"
    local raw_len=${#text}
    local pad=$(( BOX_WIDTH - raw_len ))
    printf "${D}║${N} ${C}%s${N}%*s ${D}║${N}\n" "$text" "$pad" ""
}

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

clear
draw_top
draw_title
draw_mid

# Línea de estado con cálculo exacto de caracteres visibles
RAW_STATUS_CONTENT=" Estado actual: $STATUS_TEXT"
PAD_STATUS=$(( BOX_WIDTH - ${#RAW_STATUS_CONTENT} ))
printf "${D}║${N} ${W}Estado actual:${N} ${STATUS_COLOR}%s${N}%*s  ${D}║${N}\n" "$STATUS_TEXT" "$PAD_STATUS" ""

draw_mid

# ================= LÓGICA DE INTERRUPTOR (ON/OFF) =================
if [ "$IS_ACTIVE" = true ]; then
    opt1=" [1] Detener Servicio SSL/TLS (Apagar)"
    opt2=" [2] Reinstalar / Actualizar Dominio"
    opt3=" [0] Regresar al menú principal"
    
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt1"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt2"
    printf "${D}║${N} ${R}%-${BOX_WIDTH}s${N}  ${D}║${N}\n" "$opt3"
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
        2) ;;
        0) exit 0 ;;
        *) echo -e " ${R}✘ Opción inválida.${N}"; sleep 1; exit 0 ;;
    esac
else
    opt1=" [1] Instalar / Encender SSL/TLS"
    opt3=" [0] Regresar al menú principal"
    
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt1"
    printf "${D}║${N} ${R}%-${BOX_WIDTH}s${N}  ${D}║${N}\n" "$opt3"
    draw_bot
    echo ""
    read -p " ➤ Opción: " opc

    case $opc in
        1) ;;
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
    prompt_text=" Ingresa tu Dominio / SNI:"
    printf "${D}║${N} %-${BOX_WIDTH}s ${D}║${N}\n" "$prompt_text"
    echo -ne "${D}║${N} ${Y}➤ ${N}"
    read DOMAIN
    
    DOMAIN=$(echo "$DOMAIN" | xargs)
    
    if [ -z "$DOMAIN" ]; then
        err_text=" ✘ El dominio no puede estar vacío."
        echo -e "\033[1A\033[K${D}║${N} ${R}%-${BOX_WIDTH}s${N} ${D}║${N}" "$err_text"
    else
        dom_display=" ➤ $DOMAIN"
        pad_dom=$(( BOX_WIDTH - ${#dom_display} ))
        echo -e "\033[1A\033[K${D}║${N} ${Y}➤ ${W}%s${N}%*s ${D}║${N}" "$DOMAIN" "$pad_dom" ""
    fi
done

draw_mid
raw_info=" Dominio configurado: $DOMAIN"
pad_info=$(( BOX_WIDTH - ${#raw_info} ))
printf "${D}║${N} ${W}Dominio configurado:${N} ${Y}%s${N}%*s  ${D}║${N}\n" "$DOMAIN" "$pad_info" ""
draw_mid

# PASO 1
draw_step_line "[1/5] Instalando Stunnel4, OpenSSL y dependencias..."
apt-get update -y >/dev/null 2>&1
apt-get install stunnel4 openssl psmisc net-tools -y >/dev/null 2>&1

# PASO 2
draw_step_line "[2/5] Desalojando puerto 443 de SSH y sockets activos..."
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
draw_step_line "[3/5] Generando nuevo certificado SSL/TLS (.pem)..."
rm -f /etc/stunnel/stunnel.pem
mkdir -p /etc/stunnel

openssl req -new -x509 -days 365 -nodes \
    -out /etc/stunnel/stunnel.pem \
    -keyout /etc/stunnel/stunnel.pem \
    -subj "/C=PE/ST=Lima/L=Lima/O=Kira/CN=${DOMAIN}" >/dev/null 2>&1
chmod 600 /etc/stunnel/stunnel.pem

# PASO 4
draw_step_line "[4/5] Aplicando reglas de enrutamiento en Stunnel..."
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
draw_step_line "[5/5] Reiniciando y activando servicio Stunnel4..."
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
    raw_l1=" Status: [ONLINE] - Puerto 443 asignado con éxito."
    raw_l2=" Puertos activos: 443 (SSL->WS) | 444 (SSL->SSH)"
    
    pad1=$(( BOX_WIDTH - ${#raw_l1} ))
    pad2=$(( BOX_WIDTH - ${#raw_l2} ))
    
    printf "${D}║${N} Status: ${G}[ONLINE]${N} - Puerto ${Y}443${N} asignado con éxito.%*s  ${D}║${N}\n" "$pad1" ""
    printf "${D}║${N} Puertos activos: ${Y}443 (SSL->WS)${N} | ${Y}444 (SSL->SSH)${N}%*s  ${D}║${N}\n" "$pad2" ""
else
    raw_err=" Status: [ERROR] - Fallo al iniciar el puerto 443."
    pad_err=$(( BOX_WIDTH - ${#raw_err} ))
    printf "${D}║${N} Status: ${R}[ERROR]${N} - Fallo al iniciar el puerto 443.%*s ${D}║${N}\n" "$pad_err" ""
fi

draw_bot
echo ""
read -p " Presiona Enter para continuar..."