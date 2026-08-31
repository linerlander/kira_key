#!/bin/bash

# ========= COLORES Y ESTILOS =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[1;33m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;46m'
N='\033[0m'

# ========= CONFIGURACIÓN =========
REPO="linerlander/kira_key"
BRANCH="main"
INSTALL_DIR="$HOME/kira_key"
RAW_VERSION="https://raw.githubusercontent.com/$REPO/$BRANCH/version.txt"

# ========= IR AL DIRECTORIO =========
cd "$INSTALL_DIR" 2>/dev/null || {
    clear
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${R}              ❌ ERROR DE DIRECTORIO                 ${C}║${N}"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    echo -e "${C}║${W} No se encontró la ruta: ${D}$INSTALL_DIR          ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    exit 1
}

# ========= SINCRONIZAR SOLO INFO =========
git fetch --all >/dev/null 2>&1

# ========= VERSIONES =========
LOCAL_VERSION=$(cat version.txt 2>/dev/null | tr -d '\r\n ')
REMOTE_VERSION=$(curl -s "$RAW_VERSION?$(date +%s)" | tr -d '\r\n ')

[ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="N/A"
[ -z "$REMOTE_VERSION" ] && REMOTE_VERSION="ERROR"

# ========= COMMITS =========
LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null)
REMOTE_COMMIT=$(git ls-remote origin $BRANCH | awk '{print $1}')

# ========= ESTADO =========
if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
    STATUS="${Y}ACTUALIZACIÓN DISPONIBLE${N}"
    STATUS_ICON="${Y}[!]${N}"
else
    STATUS="${G}SCRIPT AL DÍA${N}"
    STATUS_ICON="${G}[✔]${N}"
fi

while true; do
    clear

    # ========= BANNER ESTILIZADO =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}                 ⚙️ GESTOR DE KIRA ⚙️                ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""
    
    # ========= INFO DE VERSIÓN EN CAJA =========
    echo -e "${C}┌─────────────────────────────────────────────────────┐${N}"
    printf "${C}│${N} ${W}Versión Actual:${N}  %-33s ${C}│${N}\n" "$LOCAL_VERSION"
    printf "${C}│${N} ${W}Versión Remota:${N}  %-33s ${C}│${N}\n" "$REMOTE_VERSION"
    echo -e "${C}├─────────────────────────────────────────────────────┤${N}"
    printf "${C}│${N} ${W}Estado:${N}          %b %-23s ${C}│${N}\n" "$STATUS_ICON" "$STATUS"
    echo -e "${C}└─────────────────────────────────────────────────────┘${N}"
    echo ""

    # ========= MENÚ DE OPCIONES =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    printf "${C}║${N} ${Y}[1]${N} ${W}%-45s${C}║${N}\n" "Actualizar o sincronizar repositorio"
    printf "${C}║${N} ${R}[2]${N} ${W}%-45s${C}║${N}\n" "Desinstalar script por completo"
    echo -e "${C}╠═════════════════════════════════════════════════════╣${N}"
    printf "${C}║${N} ${R}[0]${N} ${W}%-45s${C}║${N}\n" "Regresar al menú principal"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    read -p " ► Selecciona una opción: " op
    echo ""

    case $op in

        1)
            if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
                echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
                echo -e "${C}║${N} ${G}✔ YA TIENES LA ÚLTIMA VERSIÓN (${LOCAL_VERSION})${N}      ${C}║${N}"
                echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
                sleep 2
                continue
            fi

            echo -e "${Y}🔄 Actualizando sistema y repositorio...${N}"

            # BACKUP
            BACKUP_DIR="$HOME/kira_backup_$(date +%s)"
            cp -r "$INSTALL_DIR" "$BACKUP_DIR"
            echo -e "${C} ✔ Backup temporal creado con éxito.${N}"

            # ACTUALIZAR
            git reset --hard origin/$BRANCH >/dev/null 2>&1
            chmod +x *.sh modules/*.sh 2>/dev/null

            # VALIDAR
            NEW_COMMIT=$(git rev-parse HEAD)
            NEW_VERSION=$(cat version.txt 2>/dev/null | tr -d '\r\n ')

            if [[ "$NEW_COMMIT" == "$REMOTE_COMMIT" ]]; then
                echo -e "${G} ✔ ¡Actualizado con éxito a la versión ${NEW_VERSION}!${N}"
                sleep 2
                exec bash menu.sh
            else
                echo -e "${R} ❌ Error en la actualización. Restaurando backup...${N}"
                cd ~
                rm -rf "$INSTALL_DIR"
                mv "$BACKUP_DIR" "$INSTALL_DIR"
                echo -e "${Y} ✔ Sistema restaurado al estado anterior.${N}"
                sleep 2
            fi
        ;;

        2)
            echo -e "${R} ⚠ Desinstalando Kira Key de tu sistema...${N}"
            cd ~
            rm -rf "$INSTALL_DIR"
            echo -e "${G} ✔ Script desinstalado correctamente.${N}"
            sleep 2
            exit 0
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