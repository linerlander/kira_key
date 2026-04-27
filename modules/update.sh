#!/bin/bash

# 🎨 COLORES
R='\033[38;5;196m'
G='\033[38;5;46m'
Y='\033[38;5;226m'
C='\033[38;5;51m'
W='\033[38;5;255m'
D='\033[38;5;240m'
N='\033[0m'

# 🔗 TU REPO
REPO_URL="https://raw.githubusercontent.com/linerlander/kira_key/main/version.txt"

# 📦 VERSIONES
LOCAL_VERSION=$(cat ~/kira_key/version.txt 2>/dev/null)
REMOTE_VERSION=$(curl -s $REPO_URL)

# 📁 BACKUP DIR
BACKUP_DIR="/root/kira_backup_$(date +%s)"

# 🔥 BARRA
progress_bar() {
  echo -ne "${Y}Actualizando: ${N}"
  for i in {1..30}; do
    echo -ne "${G}█${N}"
    sleep 0.04
  done
  echo ""
}

while true; do
clear

# 🔥 BANNER KIRA 🇵🇪
echo -e "${R}██╗  ██╗${W}██╗${R}██████╗  █████╗ ${N}"
echo -e "${R}██║ ██╔╝${W}██║██╔══██╗██╔══██╗${N}"
echo -e "${W}█████╔╝ ${R}██║██████╔╝███████║${N}"
echo -e "${W}██╔═██╗ ${R}██║██╔══██╗██╔══██║${N}"
echo -e "${R}██║  ██╗${W}██║██║  ██║██║  ██║${N}"
echo -e "${R}╚═╝  ╚═╝${W}╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${N}"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# 🔍 VERSION CHECK
if [[ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]]; then
  MSG="${Y}[!] ACTUALIZAR SCRIPT${N} ${D}(${LOCAL_VERSION})${N} ► ${G}[${REMOTE_VERSION}]${N}"
else
  MSG="${G}[✔] SCRIPT ACTUALIZADO${N} (${LOCAL_VERSION})"
fi

printf " ${W}[1]${N} ➮ %b\n" "$MSG"
printf " ${W}[2]${N} ➮ ${R}[!] DESINSTALAR SCRIPT${N}\n"

echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] ➮ [ REGRESAR ]${N}"
echo -e "${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p " ► Opcion : " op

case $op in

1)
  if [[ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
    echo -e "${G}✔ Ya tienes la ultima version${N}"
    sleep 2
    continue
  fi

  echo -e "${Y}📦 Creando backup...${N}"
  cp -r ~/kira_key $BACKUP_DIR

  progress_bar

  cd ~/kira_key || exit

  # 🔥 UPDATE
  git fetch --all >/dev/null 2>&1
  git reset --hard origin/main >/dev/null 2>&1
  chmod +x *.sh modules/*.sh

  # 🔍 VALIDAR SI FALLÓ
  if [[ ! -f "menu.sh" ]]; then
    echo -e "${R}❌ ERROR EN UPDATE → RESTAURANDO BACKUP...${N}"
    
    rm -rf ~/kira_key
    mv $BACKUP_DIR ~/kira_key

    echo -e "${G}✔ Backup restaurado${N}"
    sleep 2
    exec bash ~/kira_key/menu.sh
  fi

  echo -e "${G}✔ Script actualizado correctamente${N}"
  sleep 2
  exec bash menu.sh
  ;;

2)
  echo -e "${R}¿Seguro que deseas eliminar KIRA? (y/n)${N}"
  read confirm

  if [[ $confirm == "y" ]]; then
    rm -rf ~/kira_key
    sed -i '/kira_key\/menu.sh/d' ~/.bashrc
    echo -e "${G}✔ Script eliminado${N}"
    sleep 2
    exit
  fi
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