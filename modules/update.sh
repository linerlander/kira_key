#!/bin/bash

# ========= COLORES =========
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[1;37m'
N='\033[0m'

# ========= CONFIG =========
REPO="https://github.com/linerlander/kira_key"
RAW_VERSION="https://raw.githubusercontent.com/linerlander/kira_key/main/version.txt"
INSTALL_DIR="$HOME/kira_key"

# ========= VERSION LOCAL =========
LOCAL_VERSION=$(cat $INSTALL_DIR/version.txt 2>/dev/null)

# ========= VERSION REMOTA (SIN CACHE) =========
REMOTE_VERSION=$(curl -s "$RAW_VERSION?$(date +%s)" | tr -d '\r')

# validar
if [[ -z "$REMOTE_VERSION" ]]; then
  REMOTE_VERSION="ERROR"
fi

# ========= BANNER KIRA =========
clear
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${W}[1]${N} ➮ [!] ACTUALIZAR SCRIPT (${C}${LOCAL_VERSION}${N}) ► [${Y}${REMOTE_VERSION}${N}]"
echo -e " ${W}[2]${N} ➮ [!] DESINSTALAR SCRIPT"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] ➮ [ REGRESAR ]${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)

  # VALIDACION VERSION
  if [[ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
    echo -e "${G}[✔] YA TIENES LA ULTIMA VERSION (${LOCAL_VERSION})${N}"
    sleep 2
    exit
  fi

  echo -e "${Y}🔄 ACTUALIZANDO...${N}"

  # BACKUP
  BACKUP_DIR="$HOME/kira_backup_$(date +%s)"
  cp -r $INSTALL_DIR $BACKUP_DIR

  echo -e "${C}✔ Backup creado en: $BACKUP_DIR${N}"

  cd $INSTALL_DIR || exit

  # ACTUALIZAR
  git fetch --all >/dev/null 2>&1
  git reset --hard origin/main >/dev/null 2>&1

  chmod +x *.sh modules/*.sh

  # VALIDAR UPDATE
  NEW_VERSION=$(cat version.txt 2>/dev/null)

  if [[ "$NEW_VERSION" == "$REMOTE_VERSION" ]]; then
    echo -e "${G}[✔] ACTUALIZADO CORRECTAMENTE A ${NEW_VERSION}${N}"
    sleep 2
    exec bash menu.sh
  else
    echo -e "${R}[✖] ERROR EN UPDATE → RESTAURANDO...${N}"
    rm -rf $INSTALL_DIR
    mv $BACKUP_DIR $INSTALL_DIR
    echo -e "${Y}[✔] RESTAURADO${N}"
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