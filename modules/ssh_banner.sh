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

while true; do
clear
STATUS=$(check_status)

echo -e "${D}╔═══════════════════════════════════════════════════════════════════════╗${N}"
echo -e "${D}║${Y}                 🎭   GESTIÓN DE BANNER SSH                            ${D}║${N}"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
printf "${D}║${N} ${W}ESTADO DEL BANNER:${N} %-52b ${D}║${N}\n" "$STATUS"
echo -e "${D}╠═══════════════════════════════════════════════════════════════════════╣${N}"
echo -e "${D}║${N} ${C}[1]${N} VER BANNER ACTUAL                                                 ${D}║${N}"
echo -e "${D}║${N} ${C}[2]${N} CREAR / EDITAR BANNER (Editor Nano)                                ${D}║${N}"
echo -e "${D}║${N} ${C}[3]${N} ACTIVAR BANNER EN SSH                                              ${D}║${N}"
echo -e "${D}║${N} ${C}[4]${N} DESACTIVAR BANNER                                                 ${D}║${N}"
echo -e "${D}║${N} ${C}[5]${N} BORRAR BANNER (Limpiar contenido)                                 ${D}║${N}"
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
        read -p "Presiona Enter para continuar..."
        ;;
    2)
        nano "$BANNER_FILE"
        ;;
    3)
        echo ""
        # Asegurar que la directiva Banner esté activa en sshd_config
        sed -i '/^#Banner/d' "$SSHD_CONFIG"
        sed -i '/^Banner/d' "$SSHD_CONFIG"
        echo "Banner /etc/issue.net" >> "$SSHD_CONFIG"

        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
        echo -e " ${G}✔ Banner activado y servicio SSH reiniciado.${N}"
        sleep 2
        ;;
    4)
        echo ""
        sed -i '/^Banner /d' "$SSHD_CONFIG"
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
        echo -e " ${R}✖ Banner desactivado.${N}"
        sleep 2
        ;;
    5)
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
        echo -e " ${R}❌ Opción inválida.${N}"
        sleep 1.5
        ;;
esac

done