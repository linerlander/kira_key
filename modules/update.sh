#!/bin/bash

# ========= COLORES Y ESTILOS =========
W='\033[1;37m'
D='\033[38;5;108m'
Y='\033[38;5;220m'
R='\033[38;5;196m'
C='\033[38;5;51m'
G='\033[38;5;82m'
N='\033[0m'

# ========= CONFIGURACIÓN =========
REPO="linerlander/kira_key"
BRANCH="main"
INSTALL_DIR="$HOME/kira_key"
RAW_VERSION="https://raw.githubusercontent.com/$REPO/$BRANCH/version.txt"

# ========= IR AL DIRECTORIO =========
cd "$INSTALL_DIR" 2>/dev/null || {
    clear
    echo -e "${R}Error: no se encontró kira_key en $INSTALL_DIR${N}"
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
    STATUS="${Y}[! ] ACTUALIZAR DISPONIBLE${N}"
else
    STATUS="${G}[✔ ] SCRIPT ACTUALIZADO${N}"
fi

while true; do
    clear

    # ========= BANNER =========
    echo -e "${C}╔═════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}               ⚡ GESTOR DE ACTUALIZACIÓN ⚡         ${C}║${N}"
    echo -e "${C}╚═════════════════════════════════════════════════════╝${N}"
    echo ""

    # ========= INFO VERSION =========
    echo -e "${W} Versión actual : ${C}$LOCAL_VERSION${N}"
    echo -e "${W} Versión remota : ${Y}$REMOTE_VERSION${N}"
    echo -e "${D}─────────────────────────────────────────────────────${N}"

    # ========= MENU =========
    echo -e " ${W}[1]${N} ➮ ${status_label:-Actualizar Sistema} $STATUS"
    echo -e " ${W}[2]${N} ➮ ${R}Desinstalar Script${N}"
    echo -e "${D}─────────────────────────────────────────────────────${N}"
    echo -e " ${R}[0]${N} ➮ ${W}Regresar al menú${N}"
    echo -e "${D}─────────────────────────────────────────────────────${N}"
    echo ""

    read -p " ► Opción: " op
    echo ""

    case $op in

        1)
            if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
                echo -e "${G}✔ YA TIENES LA ÚLTIMA VERSIÓN (${LOCAL_VERSION})${N}"
                sleep 2
                continue
            fi

            echo -e "${Y}🔄 ACTUALIZANDO...${N}"

            # BACKUP
            BACKUP_DIR="$HOME/kira_backup_$(date +%s)"
            cp -r "$INSTALL_DIR" "$BACKUP_DIR"
            echo -e "${C}✔ Backup temporal creado${N}"

            # ACTUALIZAR
            git reset --hard origin/$BRANCH >/dev/null 2>&1
            chmod +x *.sh modules/*.sh 2>/dev/null

            # VALIDAR
            NEW_COMMIT=$(git rev-parse HEAD)
            NEW_VERSION=$(cat version.txt 2>/dev/null | tr -d '\r\n ')

            if [[ "$NEW_COMMIT" == "$REMOTE_COMMIT" ]]; then
                echo -e "${G}✔ ACTUALIZADO A VERSIÓN ${NEW_VERSION}${N}"
                sleep 2
                exec bash menu.sh
            else
                echo -e "${R}❌ ERROR → RESTAURANDO BACKUP${N}"
                cd ~
                rm -rf "$INSTALL_DIR"
                mv "$BACKUP_DIR" "$INSTALL_DIR"
                echo -e "${Y}✔ RESTAURADO CON ÉXITO${N}"
                sleep 2
            fi
        ;;

        2)
            echo -e "${R}⚠ DESINSTALANDO KIRA KEY...${N}"
            cd ~
            rm -rf "$INSTALL_DIR"
            echo -e "${G}✔ ELIMINADO CORRECTAMENTE${N}"
            sleep 2
            exit 0
        ;;

        0)
            break
        ;;

        *)
            echo -e "${R}Opción inválida${N}"
            sleep 1
        ;;

    esac

done