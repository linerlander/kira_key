#!/bin/bash

# ========= PALETA DE COLORES (ESTILO NEÓN / MORADO) =========
W='\033[1;37m'          # Blanco brillante
D='\033[38;5;183m'         # Morado vibrante (Bordes)
M='\033[38;5;129m'         # Magenta neón (Secciones)
Y='\033[38;5;220m'         # Amarillo (Puertos/Avisos)
R='\033[38;5;196m'         # Rojo (Errores)
C='\033[38;5;51m'          # Cyan (Subtítulos/Texto)
G='\033[38;5;82m'          # Verde neón (Exito/ONLINE)
N='\033[0m'                # Reset

clear
echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${M}                  🔒 INSTALACIÓN Y CONFIGURACIÓN SSL / TLS             ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

# SOLICITAR DOMINIO DE FORMA OBLIGATORIA
DOMAIN=""
while [ -z "$DOMAIN" ]; do
    echo -ne "${D}║${N} ${C}Ingresa tu Dominio / SNI:                        ${N}${D}║${N}"
    read DOMAIN
    if [ -z "$DOMAIN" ]; then
        printf "${D}║${N} ${R}✘ El dominio no puede estar vacío. Intenta de nuevo.${N}%-19s${D}║${N}\n" " "
    fi
done

echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}Dominio a configurar:${N} ${Y}%-48s${N}${D}║${N}\n" "$DOMAIN"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

# PASO 1: INSTALAR PAQUETES
printf "${D}║${N} ${C}[1/5] Instalando Stunnel4, OpenSSL y dependencias...${N}%-18s${D}║${N}\n" " "
apt-get update -y >/dev/null 2>&1
apt-get install stunnel4 openssl psmisc net-tools -y >/dev/null 2>&1

# PASO 2: LIBERAR PUERTO 443 DE FORMA FORZADA
printf "${D}║${N} ${C}[2/5] Desalojando puerto 443 de SSH y sockets activos...${N}%-11s   ${D}║${N}\n" " "

if grep -qE "^Port 443" /etc/ssh/sshd_config; then
    sed -i '/^Port 443/d' /etc/ssh/sshd_config
    systemctl restart ssh >/dev/null 2>&1
fi

if systemctl is-active --quiet ssh.socket 2>/dev/null; then
    systemctl stop ssh.socket >/dev/null 2>&1
    systemctl disable ssh.socket >/dev/null 2>&1
fi

fuser -k 443/tcp >/dev/null 2>&1 || true

# PASO 3: LIMPIAR Y GENERAR NUEVO CERTIFICADO SSL
printf "${D}║${N} ${C}[3/5] Generando nuevo certificado SSL/TLS (.pem)...${N}%-13s      ${D}║${N}\n" " "
rm -f /etc/stunnel/stunnel.pem
mkdir -p /etc/stunnel

openssl req -new -x509 -days 365 -nodes \
    -out /etc/stunnel/stunnel.pem \
    -keyout /etc/stunnel/stunnel.pem \
    -subj "/C=PE/ST=Lima/L=Lima/O=Kira/CN=${DOMAIN}" >/dev/null 2>&1
chmod 600 /etc/stunnel/stunnel.pem

# PASO 4: CONFIGURACIÓN OPTIMIZADA DE STUNNEL
printf "${D}║${N} ${C}[4/5] Aplicando reglas de enrutamiento en Stunnel...${N}%-14s${D}    ║${N}\n" " "
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

# PASO 5: ENCENDER SERVICIO Y VERIFICAR
printf "${D}║${N} ${C}[5/5] Reiniciando y activando servicio Stunnel4...${N}%-16s    ${D}║${N}\n" " "
killall -9 stunnel4 stunnel 2>/dev/null || true
systemctl daemon-reload
systemctl enable stunnel4 >/dev/null 2>&1
systemctl restart stunnel4 >/dev/null 2>&1

if ! systemctl is-active --quiet stunnel4; then
    stunnel4 /etc/stunnel/stunnel.conf >/dev/null 2>&1
fi

echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

# COMPROBACIÓN FINAL DE ESTADO Y PUERTOS
if systemctl is-active --quiet stunnel4 || pgrep -x "stunnel4" >/dev/null || pgrep -x "stunnel" >/dev/null; then
    printf "${D}║${N} Status: ${G}[ONLINE]${N} - Puerto ${Y}443${N} asignado a SSL/TLS con éxito.           ${D}║${N}\n"
    printf "${D}║${N} Puertos activos: ${Y}443 (SSL->WS)${N} | ${Y}444 (SSL->SSH)${N}%-21s  ${D}║${N}\n" " "
else
    printf "${D}║${N} Status: ${R}[ERROR]${N} - Fallo al iniciar el puerto 443.                   ${D}║${N}\n"
fi

echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p "Presiona Enter para continuar..."