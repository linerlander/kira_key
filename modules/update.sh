#!/bin/bash

# ========= COLORES =========
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[1;37m'
N='\033[0m'

# ========= CONFIG =========
REPO="linerlander/kira_key"
BRANCH="main"
INSTALL_DIR="$HOME/kira_key"

RAW_VERSION="https://raw.githubusercontent.com/$REPO/$BRANCH/version.txt"

# ========= VERSION =========
LOCAL_VERSION=$(cat $INSTALL_DIR/version.txt 2>/dev/null)
REMOTE_VERSION=$(curl -s "$RAW_VERSION?$(date +%s)" | tr -d '\r')

# ========= COMMITS =========
LOCAL_COMMIT=$(git -C $INSTALL_DIR rev-parse HEAD 2>/dev/null)
REMOTE_COMMIT=$(git ls-remote https://github.com/$REPO.git refs/heads/$BRANCH | awk '{print $1}')

# ========= VALIDACIONES =========
[ -z "$REMOTE_VERSION" ] && REMOTE_VERSION="ERROR"

# ========= BANNER =========
clear
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ========= DETECCION =========
if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
  STATUS="${Y}[!] ACTUALIZAR DISPONIBLE${N}"
else
  STATUS="${G}[✔] SCRIPT ACTUALIZADO${N}"
fi

echo -e " ${W}[1]${N} ➮ $STATUS (${C}${LOCAL_VERSION}${N}) ► [${Y}${REMOTE_VERSION}${N}]"
echo -e " ${W}[2]${N} ➮ ${R}[!] DESINSTALAR SCRIPT${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] ➮ [ REGRESAR ]${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)

  if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo -e "${G}✔ YA TIENES LA ULTIMA VERSION${N}"
    sleep 2
    exit
  fi

  echo -e "${Y}🔄 ACTUALIZANDO...${N}"

  # BACKUP
  BACKUP_DIR="$HOME/kira_backup_$(date +%s)"
  cp -r $INSTALL_DIR $BACKUP_DIR

  cd $INSTALL_DIR || exit

  git fetch --all >/dev/null 2>&1
  git reset --hard origin/$BRANCH >/dev/null 2>&1

  chmod +x *.sh modules/*.sh

  # VALIDACION
  NEW_COMMIT=$(git rev-parse HEAD)

  if [[ "$NEW_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo -e "${G}✔ ACTUALIZADO CORRECTAMENTE${N}"
    sleep 2
    exec bash menu.sh
  else
    echo -e "${R}❌ ERROR → RESTAURANDO BACKUP${N}"
    cd ~
    rm -rf $INSTALL_DIR
    mv $BACKUP_DIR $INSTALL_DIR
    echo -e "${Y}✔ RESTAURADO${N}"
    sleep 2
  fi

;;

2)
  echo -e "${R}⚠ DESINSTALANDO...${N}"
  rm -rf $INSTALL_DIR
  echo -e "${G}✔ ELIMINADO${N}"
  sleep 2
;;

0)
  exit
;;

*)
  echo -e "${R}Opcion invalida${N}"
  sleep 1
;;

esac