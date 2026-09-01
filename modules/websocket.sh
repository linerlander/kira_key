#!/bin/bash

# ========= PALETA DE COLORES (ESTILO NEÓN / MORADO) =========
W='\033[1;37m'
D='\033[38;5;183m'
M='\033[38;5;129m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[1;36m'
G='\033[38;5;82m'
N='\033[0m'

BOX_WIDTH=69

draw_top()    { echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"; }
draw_mid()    { echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"; }
draw_bot()    { echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"; }

draw_title()  {
    printf "${D}║${M} %-${BOX_WIDTH}s ${D}║${N}\n" "          ⚡ MÓDULO OVER WEBSOCKET ( WSTUNNEL / SSL )"
}

draw_step_line() {
    local text="$1"
    local raw_len=${#text}
    local pad=$(( BOX_WIDTH - raw_len ))
    printf "${D}║${N} ${C}%s${N}%*s ${D}║${N}\n" "$text" "$pad" ""
}

CONFIG="/etc/kira/domain"
WS_PORT=8888
SOCKS_PORT=1080

mkdir -p /etc/kira
DOMAIN=$(cat $CONFIG 2>/dev/null)
[ -z "$DOMAIN" ] && DOMAIN="--"

install_all() {
    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "[1/3] Actualizando paquetes y dependencias..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -y >/dev/null 2>&1
    apt install -y wget tar nginx certbot python3-certbot-nginx >/dev/null 2>&1

    draw_step_line "[2/3] Descargando wstunnel optimizado..."
    rm -f /usr/bin/wstunnel
    wget -q -O /tmp/ws.tar.gz https://github.com/erebe/wstunnel/releases/download/v10.5.3/wstunnel_10.5.3_linux_amd64.tar.gz
    tar -xzf /tmp/ws.tar.gz -C /tmp >/dev/null 2>&1
    mv /tmp/wstunnel /usr/bin/
    chmod +x /usr/bin/wstunnel

    systemctl stop kira-ws 2>/dev/null
    killall wstunnel 2>/dev/null
    fuser -k ${WS_PORT}/tcp 2>/dev/null

    cat > /etc/systemd/system/kira-ws.service <<EOF
[Unit]
Description=KIRA WS SERVER High Performance
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel server ws://127.0.0.1:${WS_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable kira-ws >/dev/null 2>&1
    systemctl restart kira-ws

    draw_mid
    ok_msg=" ✔ Servidor wstunnel activo en puerto interno ${WS_PORT}."
    pad_ok=$(( BOX_WIDTH - ${#ok_msg} ))
    printf "${D}║${N} ${G}%s${N}%*s ${D}║${N}\n" "$ok_msg" "$pad_ok" ""
    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

setup_domain() {
    clear
    draw_top
    draw_title
    draw_mid

    prompt_d=" Ingresa tu dominio enlazado (Ej: vps.tudominio.com):"
    pad_d=$(( BOX_WIDTH - ${#prompt_d} ))
    printf "${D}║${N} %s%*s ${D}║${N}\n" "$prompt_d" "$pad_d" ""
    draw_mid

    lbl_in=" ➜ Dominio: "
    echo -ne "${D}║${N}${Y}${lbl_in}${N}"
    read DOMAIN
    draw_bot

    DOMAIN=$(echo "$DOMAIN" | xargs)
    [ -z "$DOMAIN" ] && return

    echo "$DOMAIN" > $CONFIG

    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "[1/3] Deteniendo servicios web para certificado..."
    systemctl stop nginx 2>/dev/null
    fuser -k 80/tcp 2>/dev/null
    fuser -k 443/tcp 2>/dev/null

    draw_step_line "[2/3] Solicitando certificado SSL (Certbot)..."
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN >/dev/null 2>&1

    draw_step_line "[3/3] Aplicando configuración Nginx (SNI + 101)..."
    
    cat > /etc/nginx/conf.d/kira.conf <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

    systemctl restart nginx

    draw_mid
    if systemctl is-active --quiet nginx; then
        ok_ssl=" ✔ Dominio y Certificado SSL configurados con éxito."
    else
        ok_ssl=" ⚠ Certificado listo, revisa configuración de Nginx."
    fi
    pad_ssl=$(( BOX_WIDTH - ${#ok_ssl} ))
    printf "${D}║${N} ${G}%s${N}%*s ${D}║${N}\n" "$ok_ssl" "$pad_ssl" ""
    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

install_client() {
    DOMAIN=$(cat $CONFIG 2>/dev/null)

    if [ -z "$DOMAIN" ] || [ "$DOMAIN" == "--" ]; then
        clear
        draw_top
        draw_title
        draw_mid
        err_c=" ✘ Debes configurar el dominio y SSL primero (Opción 2)."
        pad_errc=$(( BOX_WIDTH - ${#err_c} ))
        printf "${D}║${N} ${R}%s${N}%*s ${D}║${N}\n" "$err_c" "$pad_errc" ""
        draw_bot
        echo ""
        read -p " Presiona Enter para continuar..."
        return
    fi

    clear
    draw_top
    draw_title
    draw_mid

    draw_step_line "Activando túnel cliente SOCKS5 local..."

    systemctl stop kira-client 2>/dev/null
    killall wstunnel 2>/dev/null
    fuser -k ${SOCKS_PORT}/tcp 2>/dev/null

    cat > /etc/systemd/system/kira-client.service <<EOF
[Unit]
Description=KIRA CLIENT SOCKS5
After=network.target

[Service]
ExecStart=/usr/bin/wstunnel client -L socks5://127.0.0.1:${SOCKS_PORT} wss://${DOMAIN}/
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable kira-client >/dev/null 2>&1
    systemctl restart kira-client
    sleep 2

    draw_mid
    if ss -tuln | grep -q "${SOCKS_PORT}"; then
        st_ok=" ✔ Cliente SOCKS5 activo en puerto ${SOCKS_PORT}."
        pad_stok=$(( BOX_WIDTH - ${#st_ok} ))
        printf "${D}║${N} ${G}%s${N}%*s ${D}║${N}\n" "$st_ok" "$pad_stok" ""
    else
        st_er=" ✖ Error al iniciar el cliente SOCKS5."
        pad_ster=$(( BOX_WIDTH - ${#st_er} ))
        printf "${D}║${N} ${R}%s${N}%*s ${D}║${N}\n" "$st_er" "$pad_ster" ""
    fi

    draw_bot
    echo ""
    read -p " Presiona Enter para continuar..."
}

status_all() {
    clear
    draw_top
    draw_title
    draw_mid

    if systemctl is-active --quiet kira-ws; then
        ws_st="ACTIVO (ON)"
        ws_col="${G}"
    else
        ws_st="DETENIDO (OFF)"
        ws_col="${R}"
    fi

    if systemctl is-active --quiet kira-client; then
        cl_st="ACTIVO (ON)"
        cl_col="${G}"
    else
        cl_st="DETENIDO (OFF)"
        cl_col="${R}"
    fi

    r1=" Servidor WS (wstunnel) : $ws_st"
    p1=$(( BOX_WIDTH - ${#r1} ))
    printf "${D}║${N} ${W}Servidor WS (wstunnel) :${N} ${ws_col}%s${N}%*s ${D}║${N}\n" "$ws_st" "$p1" ""

    r2=" Cliente SOCKS5         : $cl_st"
    p2=$(( BOX_WIDTH - ${#r2} ))
    printf "${D}║${N} ${W}Cliente SOCKS5         :${N} ${cl_col}%s${N}%*s ${D}║${N}\n" "$cl_st" "$p2" ""

    r3=" Dominio enlazado       : $DOMAIN"
    p3=$(( BOX_WIDTH - ${#r3} ))
    printf "${D}║${N} ${W}Dominio enlazado       :${N} ${C}%s${N}%*s ${D}║${N}\n" "$DOMAIN" "$p3" ""

    draw_bot
    echo ""
    read -p " Presiona Enter para volver..."
}

while true; do
    clear
    draw_top
    draw_title
    draw_mid

    opt1=" [1] Instalar / Actualizar wstunnel y Servidor"
    opt2=" [2] Configurar Dominio y Certificado SSL (SNI)"
    opt3=" [3] Activar Cliente SOCKS5 Local"
    opt4=" [4] Ver Estado de los Servicios WS"
    opt0=" [0] Salir del Módulo"

    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt1"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt2"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt3"
    printf "${D}║${N} ${W}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt4"
    printf "${D}║${N} ${R}%-${BOX_WIDTH}s${N} ${D}║${N}\n" "$opt0"

    draw_bot
    echo ""
    read -p " ➤ Opción: " op

    case $op in
        1) install_all ;;
        2) setup_domain ;;
        3) install_client ;;
        4) status_all ;;
        0) break ;;
        *) 
           echo -e "\n ${R}Opción inválida.${N}"
           sleep 1 
           ;;
    esac
done