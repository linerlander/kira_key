#!/bin/bash

# ========= COLORES =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

BANNER_FILE="/etc/issue.net"
SSHD_CONFIG="/etc/ssh/sshd_config"

check_status() {
    if grep -q "^Banner /etc/issue.net" "$SSHD_CONFIG"; then
        echo -e "${G}ACTIVADO${N}"
    else
        echo -e "${R}DESACTIVADO${N}"
    fi
}

apply_preset() {
    case $1 in
        1)
            cat << 'EOF' > "$BANNER_FILE"
<br>
<font color="#00FF00">=================================</font><br>
<font color="#FFFF00"><b>      🚀 SERVER PREMIUM VIP 🚀   </b></font><br>
<font color="#00FF00">=================================</font><br>
<font color="#FFFFFF">✔ Conexión Estable & Alta Velocidad</font><br>
<font color="#FFFFFF">✔ Prohibido Torrent / SPAM / DDOS</font><br>
<font color="#00FFFF"><i>¡Gracias por preferir nuestro servicio!</i></font><br>
<font color="#00FF00">=================================</font><br>
EOF
            ;;
        2)
            cat << 'EOF' > "$BANNER_FILE"
<br>
<font color="#FF0000"><b>⚠️ REGLAS DEL SERVIDOR ⚠️</b></font><br>
<font color="#FFFF00">---------------------------------</font><br>
<font color="#FFFFFF">❌ NO Multi-login no autorizado</font><br>
<font color="#FFFFFF">❌ NO Actividades ilícitas</font><br>
<font color="#FFFFFF">❌ NO Torrent ni Carding</font><br>
<font color="#FF0055"><b>El incumplimiento causará BAN permanente.</b></font><br>
<font color="#FFFF00">---------------------------------</font><br>
EOF
            ;;
        3)
            cat << 'EOF' > "$BANNER_FILE"
<br>
<font color="#00FFFF">╔════════════════════════════════╗</font><br>
<font color="#FF00FF"><b>       ⚡ POWER NETWORK SSH ⚡     </b></font><br>
<font color="#00FFFF">╠════════════════════════════════╣</font><br>
<font color="#FFFFFF"> ✦ Estado: <font color="#00FF00">ONLINE</font></font><br>
<font color="#FFFFFF"> ✦ Soporte: @loki_oficial</font><br>
<font color="#00FFFF">╚════════════════════════════════╝</font><br>
EOF
            ;;
    esac
}

while true; do
clear
STATUS=$(check_status)

echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 🎭   GESTIÓN DE BANNER SSH                            ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}ESTADO DEL BANNER:${N} %-52b ${D}║${N}\n" "$STATUS"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${Y}[1]${N} VER BANNER ACTUAL                                                 ${D}║${N}"
echo -e "${D}║${N} ${Y}[2]${N} CREAR / EDITAR BANNER (Código HTML / Manual)                      ${D}║${N}"
echo -e "${D}║${N} ${Y}[3]${N} USAR BANNERS PREDEFINIDOS (3 Plantillas)                           ${D}║${N}"
echo -e "${D}║${N} ${Y}[4]${N} ACTIVAR BANNER EN SSH                                              ${D}║${N}"
echo -e "${D}║${N} ${Y}[5]${N} DESACTIVAR BANNER                                                 ${D}║${N}"
echo -e "${D}║${N} ${Y}[6]${N} BORRAR BANNER (Limpiar contenido)                                 ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${R}[0] REGRESAR AL MENÚ PRINCIPAL${N}                                       ${D}║${N}"
echo -e "${D}╚═══════════════════════════════════════════════════════════════════════╝${N}"
echo ""
read -p " ► Selecciona una opción: " option

case $option in
    1)
        echo ""
        echo -e "${D}━━━━━━━━━━━━━━ CONTENIDO DE $BANNER_FILE ━━━━━━━━━━━━━━${N}"
        if [ -s "$BANNER_FILE" ]; then
            echo -e "${W}"
            cat "$BANNER_FILE"
            echo -e "${N}"
        else
            echo -e " ${R}El archivo de Banner está vacío o no existe.${N}"
        fi
        echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
        echo ""
        read -p "Presiona Enter para continuar..."
        ;;
    2)
        nano "$BANNER_FILE"
        ;;
    3)
        echo ""
        echo -e "${D}━━━━━━━━━━━━━━ PLANTILLAS PREDEFINIDAS ━━━━━━━━━━━━━━${N}"
        echo -e " ${Y}[1]${N} Plantilla Estándar Premium (Verde / Amarillo)"
        echo -e " ${Y}[2]${N} Plantilla de Reglas y Advertencias (Rojo / Amarillo)"
        echo -e " ${Y}[3]${N} Plantilla Minimalista Neón (Cian / Magenta)"
        echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
        echo ""
        read -p " ► Selecciona la plantilla a aplicar [1-3]: " preset_choice
        if [[ "$preset_choice" =~ ^[1-3]$ ]]; then
            apply_preset "$preset_choice"
            echo ""
            echo -e " ${G}✔ Plantilla #$preset_choice aplicada en $BANNER_FILE.${N}"
            echo -e " ${Y}Recuerda activar el banner (Opción 4) si aún no está activo.${N}"
            sleep 2.5
        else
            echo ""
            echo -e " ${R}❌ Selección inválida.${N}"
            sleep 1.5
        fi
        ;;
    4)
        echo ""
        sed -i '/^#Banner/d' "$SSHD_CONFIG"
        sed -i '/^Banner/d' "$SSHD_CONFIG"
        echo "Banner /etc/issue.net" >> "$SSHD_CONFIG"

        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
        echo -e " ${G}✔ Banner activado y servicio SSH reiniciado.${N}"
        sleep 2
        ;;
    5)
        echo ""
        sed -i '/^Banner /d' "$SSHD_CONFIG"
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
        echo -e " ${R}✖ Banner desactivado.${N}"
        sleep 2
        ;;
    6)
        echo ""
        > "$BANNER_FILE"
        echo -e " ${G}✔ Contenido del banner borrado correctamente.${N}"
        sleep 2
        ;;
    0|00)
        exit 0
        ;;
    *)
        echo ""
        echo -e " ${R}❌ Selección inválida.${N}"
        sleep 1.5
        ;;
esac

done