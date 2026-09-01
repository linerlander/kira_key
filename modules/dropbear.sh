#!/bin/bash

# ========= COLORES Y ESTILOS =========
W='\033[1;37m'
D='\033[38;5;240m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;183m' # Morado suave y elegante
G='\033[38;5;46m'
N='\033[0m'

SERVICE="dropbear"
CONFIG="/etc/default/dropbear"

# ===== ESTADO =====
status_dropbear() {
    if pgrep -x "dropbear" >/dev/null; then
        echo "ACTIVO"
    else
        echo "DETENIDO"
    fi
}

# ===== OBTENER PUERTO ACTUAL =====
get_dropbear_port() {
    if [ -f "$CONFIG" ]; then
        grep -E "^DROPBEAR_PORT=" "$CONFIG" | cut -d'=' -f2 | tr -d '"'
    else
        echo "22"
    fi
}

# ===== INSTALAR / CONFIGURAR =====
install_dropbear() {
    echo -e "${Y} ⚙️ Instalando Dropbear SSH...${N}"
    echo ""

    apt update -y
    apt install -y dropbear >/dev/null 2>&1

    if ! command -v dropbear >/dev/null 2>&1; then
        echo -e "${R} ✘ Error al instalar Dropbear${N}"
        return
    fi

    # Configurar para permitir arranque y asignar puerto 443 por defecto si está en 22
    if [ -f "$CONFIG" ]; then
        sed -i 's/NO_START=1/NO_START=0/g' "$CONFIG"
        sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=443/g' "$CONFIG"
    fi

    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear

    sleep 2
    echo -e "${G} ✔ Dropbear instalado y configurado correctamente${N}"
}

# ===== CAMBIAR PUERTO =====
change_port() {
    read -p " ► Ingresa el nuevo puerto para Dropbear: " NEWPORT
    echo ""

    if ! [[ "$NEWPORT" =~ ^[0-9]+$ ]]; then
        echo -e "${R} ✘ Puerto inválido. Debe ser un número.${N}"
        return
    fi

    if ss -tuln | grep -q ":$NEWPORT "; then
        echo -e "${R} ✘ El puerto ya está en uso por otro servicio.${N}"
        return
    fi

    if [ -f "$CONFIG" ]; then
        sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$NEWPORT/" "$CONFIG"
        systemctl restart dropbear
        echo -e "${G} ✔ Puerto de Dropbear cambiado a $NEWPORT con éxito.${N}"
    else
        echo -e "${R} ✘ No se encontró el archivo de configuración.${N}"
    fi
}

# ===== TOGGLE ENCENDIDO / APAGADO =====
toggle_service() {
    if pgrep -x "dropbear" >/dev/null; then
        systemctl stop dropbear
        echo -e "${R} ✔ Dropbear detenido.${N}"
    else
        systemctl start dropbear
        echo -e "${G} ✔ Dropbear iniciado.${N}"
    fi
}

# ===== MENÚ PRINCIPAL =====
while true; do
    clear

    # Obtenemos el texto puro sin colores para poder contar sus caracteres
    RAW_STATE=$(status_dropbear)
    if [ "$RAW_STATE" = "ACTIVO" ]; then
        STATE_COLOR="${G}"
    else
        STATE_COLOR="${R}"
    fi

    DPORT=$(get_dropbear_port)

    # ========= BANNER ESTILIZADO =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}               🪶 DROPBEAR SSH - KIRA                ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    # ========= CÁLCULO DINÁMICO DE ESPACIOS =========
    # El ancho interno exacto de nuestra caja es de 53 caracteres.
    # Restamos los textos fijos ("Estado: ● ") y la longitud del resultado dinámico.
    
    PAD_STATE=$(( 53 - 11 - ${#RAW_STATE} ))
    PAD_PORT=$(( 53 - 9 - ${#DPORT} ))

    # ========= INFO DE ESTADO Y PUERTO EN CAJA =========
    echo -e "${C}┌─────────────────────────────────────────────────────┐${N}"
    echo -e "${C}│${N} ${W}Estado:${N} ${STATE_COLOR}● ${RAW_STATE}${N}$(printf '%*s' "$PAD_STATE" "")${C}│${N}"
    echo -e "${C}│${N} ${W}Puerto:${N} ${C}${DPORT}${N}$(printf '%*s' "$PAD_PORT" "")${C}│${N}"
    echo -e "${C}└─────────────────────────────────────────────────────┘${N}"
    echo ""

    # ========= DESCRIPCIÓN =========
    echo -e " ${W}💡 Servidor SSH ultraligero optimizado para túneles.${N}"
    echo -e "${D}─────────────────────────────────────────────────────${N}"

    # ========= MENÚ DE OPCIONES =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    printf "${C}║${N} ${W}[1]${N} ${W}%-45s   ${C}║${N}\n" "Instalar o Reinstalar Dropbear"
    printf "${C}║${N} ${W}[2]${N} ${W}%-45s   ${C}║${N}\n" "Cambiar puerto de escucha"
    printf "${C}║${N} ${W}[3]${N} ${W}%-45s   ${C}║${N}\n" "Alternar Encendido / Apagado"
    printf "${C}║${N} ${W}[4]${N} ${W}%-45s   ${C}║${N}\n" "Reiniciar servicio"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    printf "${C}║${N} ${R}[0]${N} ${W}%-45s    ${C}║${N}\n" "Volver al menú principal"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    read -p " ► Selecciona una opción: " op
    echo ""

    case $op in
        1)
            install_dropbear
            read -p " Presiona Enter para continuar..."
            ;;
        2)
            change_port
            sleep 2
            ;;
        3)
            toggle_service
            sleep 2
            ;;
        4)
            systemctl restart dropbear
            echo -e "${G} ✔ Servicio reiniciado correctamente.${N}"
            sleep 2
            ;;
        0)
            break
            ;;
        *)
            echo -e "${R} ✘ Opción inválida, intenta de nuevo.${N}"
            sleep 1
            ;;
    esac
done