#!/bin/bash

# 🎨 COLORES PRO
G='\033[38;5;46m'   # verde neón
R='\033[38;5;196m'  # rojo fuerte
Y='\033[38;5;226m'  # amarillo
C='\033[38;5;51m'   # cyan
W='\033[38;5;255m'  # blanco limpio
D='\033[38;5;240m'  # gris
N='\033[0m'

CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak"

get_ports() {
  grep -E "^Port" $CONFIG | awk '{print $2}'
}

port_in_use() {
  ss -tuln | grep -q ":$1 "
}

backup_config() {
  cp $CONFIG $BACKUP
}

open_firewall() {
  if command -v ufw >/dev/null; then
    ufw allow $1/tcp >/dev/null 2>&1
  else
    iptables -A INPUT -p tcp --dport $1 -j ACCEPT
  fi
}

while true; do
clear

# 🔹 HEADER LIMPIO
echo -e "${C}╔══════════════════════════════════════════════╗${N}"
echo -e "${C}║${W} 🔐 SSH SECURITY PANEL - KIRA             ${C}║${N}"
echo -e "${C}╚══════════════════════════════════════════════╝${N}"

# 🔸 INFO
echo -e "${Y}⚠ Puerto 22 protegido (no se puede eliminar)${N}"
echo -e "${D}──────────────────────────────────────────────${N}"

# 🔌 PUERTOS
echo -e "${C}🔌 PUERTOS SSH${N}"

PORTS=$(get_ports)

for p in $PORTS; do
  if ss -tuln | grep -q ":$p "; then
    STATUS="${G}● ACTIVO${N}"
  else
    STATUS="${R}● INACTIVO${N}"
  fi

  printf " ${D}├─${N} ${W}%-6s${N} %b\n" "$p" "$STATUS"
done

echo -e "${D}──────────────────────────────────────────────${N}"

# 🎛️ MENU
echo -e " ${G}[1]${N} ➤ Agregar puerto SSH"
echo -e " ${R}[2]${N} ➤ Eliminar puerto SSH"
echo -e " ${W}[0]${N} ➤ Volver"

echo -e "${D}──────────────────────────────────────────────${N}"

read -p "➤ Opcion: " op

case $op in

1)
  read -p "Nuevo puerto: " PORT

  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo -e "${R}Puerto invalido${N}"
    read -p "ENTER..."
    continue
  fi

  if grep -q "^Port $PORT" $CONFIG; then
    echo -e "${R}Ese puerto ya existe${N}"
    read -p "ENTER..."
    continue
  fi

  if port_in_use $PORT; then
    echo -e "${R}Puerto en uso por otro servicio${N}"
    read -p "ENTER..."
    continue
  fi

  backup_config
  echo "Port $PORT" >> $CONFIG
  open_firewall $PORT
  systemctl restart ssh

  echo -e "${G}✔ Puerto agregado correctamente${N}"
  read -p "ENTER..."
  ;;

2)
  read -p "Puerto a eliminar: " PORT

  if [ "$PORT" = "22" ]; then
    echo -e "${R}✖ No puedes eliminar el puerto 22${N}"
    read -p "ENTER..."
    continue
  fi

  if ! grep -q "^Port $PORT" $CONFIG; then
    echo -e "${R}Ese puerto no existe${N}"
    read -p "ENTER..."
    continue
  fi

  TOTAL=$(get_ports | wc -l)

  if [ "$TOTAL" -le 1 ]; then
    echo -e "${R}No puedes eliminar el ultimo puerto${N}"
    read -p "ENTER..."
    continue
  fi

  backup_config
  sed -i "/^Port $PORT/d" $CONFIG
  systemctl restart ssh

  echo -e "${G}✔ Puerto eliminado correctamente${N}"
  read -p "ENTER..."
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