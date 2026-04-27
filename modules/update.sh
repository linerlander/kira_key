#!/bin/bash

# ========= COLORES =========
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[1;37m'
D='\033[38;5;240m'
N='\033[0m'

# ========= CONFIG =========
REPO="linerlander/kira_key"
BRANCH="main"
INSTALL_DIR="$HOME/kira_key"

RAW_VERSION="https://raw.githubusercontent.com/$REPO/$BRANCH/version.txt"

# ========= IR AL DIRECTORIO =========
cd "$INSTALL_DIR" 2>/dev/null || {
  echo -e "${R}Error: no se encontró kira_key${N}"
  exit
}

# ========= SINCRONIZAR (CLAVE 🔥) =========
git fetch --all >/dev/null 2>&1

# ========= VERSIONES =========
LOCAL_VERSION=$(cat version.txt 2>/dev/null | tr -d '\r\n ')
REMOTE_VERSION=$(curl -s "$RAW_VERSION?$(date +%s)" | tr -d '\r\n ')

[ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="N/A"
[ -z "$REMOTE_VERSION" ] && REMOTE_VERSION="ERROR"

# ========= COMMITS =========
LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null)
REMOTE_COMMIT=$(git ls-remote https://github.com/$REPO.git refs/heads/$BRANCH | awk '{print $1}')

# ========= ESTADO =========
if [[ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
  STATUS="${Y}[!] ACTUALIZAR DISPONIBLE${N}"
else
  STATUS="${G}[✔] SCRIPT ACTUALIZADO${N}"
fi

while true; do
clear

# ========= BANNER =========
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ========= INFO VERSION =========
echo -e " ${W}Version actual:${N} ${C}$LOCAL_VERSION${N}"
echo -e " ${W}Version remota:${N} ${Y}$REMOTE_VERSION${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ========= MENU =========
printf " ${W}[1]${N} ➮ %b ${D}(%s)${N} ► ${G}[%s]${N}\n" "$STATUS" "$LOCAL_VERSION" "$REMOTE_VERSION"
echo -e " ${W}[2]${N} ➮ ${R}[!] DESINSTALAR SCRIPT${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] ➮ [ REGRESAR ]${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)
  if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo -e "${G}✔ YA TIENES LA ULTIMA VERSION (${LOCAL_VERSION})${N}"
    sleep 2
    continue
  fi

  echo -e "${Y}🔄 ACTUALIZANDO...${N}"

  # BACKUP
  BACKUP_DIR="$HOME/kira_backup_$(date +%s)"
  cp -r "$INSTALL_DIR" "$BACKUP_DIR"
  echo -e "${C}✔ Backup creado${N}"

  # UPDATE REAL
  git reset --hard origin/$BRANCH >/dev/null 2>&1

  chmod +x *.sh modules/*.sh

  # VALIDACION
  NEW_COMMIT=$(git rev-parse HEAD)
  NEW_VERSION=$(cat version.txt 2>/dev/null | tr -d '\r\n ')

  if [[ "$NEW_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo -e "${G}✔ ACTUALIZADO A VERSION ${NEW_VERSION}${N}"
    sleep 2
    exec bash menu.sh
  else
    echo -e "${R}❌ ERROR → RESTAURANDO BACKUP${N}"
    cd ~
    rm -rf "$INSTALL_DIR"
    mv "$BACKUP_DIR" "$INSTALL_DIR"
    echo -e "${Y}✔ RESTAURADO${N}"
    sleep 2
  fi
;;

2)
  echo -e "${R}⚠ DESINSTALANDO...${N}"
  cd ~
  rm -rf "$INSTALL_DIR"
  echo -e "${G}✔ ELIMINADO${N}"
  sleep 2
;;

0)
  break
;;

*)
  echo -e "${R}Opcion invalida${N}"
  sleep 1
;;

esac

done