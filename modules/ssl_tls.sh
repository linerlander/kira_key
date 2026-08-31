#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

clear
echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                   🔒 INSTALACIÓN Y CONFIGURACIÓN SSL / TLS            ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

# PASO 1: INSTALAR PAQUETES
echo -e "${D}║${N} ${C}[1/5] Instalando Stunnel4 y OpenSSL...${N}"
apt-get update -y >/dev/null 2>&1
apt-get install stunnel4 openssl -y >/dev/null 2>&1

# PASO 2: LIBERAR PUERTO 443 EN SSH (DESALOJAR SSH DEL 443)
echo -e "${D}║${N} ${C}[2/5] Liberando puerto 443 de OpenSSH...${N}"
if grep -qE "^Port 443" /etc/ssh/sshd_config; then
    sed -i '/^Port 443/d' /etc/ssh/sshd_config
    systemctl restart ssh >/dev/null 2>&1
fi
if systemctl is-active --quiet ssh.socket 2>/dev/null; then
    systemctl stop ssh.socket >/dev/null 2>&1
    systemctl disable ssh.socket >/dev/null 2>&1
fi

# PASO 3: GENERAR CERTIFICADO SSL
echo -e "${D}║${N} ${C}[3/5] Generando certificado de seguridad (.pem)...${N}"
mkdir -p /etc/stunnel
openssl req -new -x509 -days 365 -nodes \
    -out /etc/stunnel/stunnel.pem \
    -keyout /etc/stunnel/stunnel.pem \
    -subj "/C=PE/ST=Lima/L=Lima/O=Kira/CN=lander.linerlander.space" >/dev/null 2>&1
chmod 600 /etc/stunnel/stunnel.pem

# PASO 4: ASIGNAR EL PUERTO 443 A STUNNEL
echo -e "${D}║${N} ${C}[4/5] Asignando puerto 443 libre a Stunnel...${N}"
cat << 'EOF' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel4.pid
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
echo -e "${D}║${N} ${C}[5/5] Iniciando servicio SSL/TLS...${N}"
killall -9 stunnel4 stunnel 2>/dev/null
systemctl daemon-reload
systemctl enable stunnel4 >/dev/null 2>&1
systemctl restart stunnel4 >/dev/null 2>&1

echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"

if systemctl is-active --quiet stunnel4 || pgrep -x "stunnel" >/dev/null; then
    echo -e "${D}║${N} Status: ${G}[ONLINE]${N} - Puerto ${Y}443${N} asignado a SSL/TLS exitosamente. ${D}║${N}"
else
    echo -e "${D}║${N} Status: ${R}[ERROR]${N} - No se pudo levantar Stunnel.                      ${D}║${N}"
fi

echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p "Presiona Enter para continuar..."