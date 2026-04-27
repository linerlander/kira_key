#!/bin/bash

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak"

# Obtener puertos
get_ports() {
  grep -E "^Port" $CONFIG | awk '{print $2}'
}

# Verificar puerto activo
check_port() {
  ss -tuln | grep -q ":$1 " && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

# Detectar si puerto está ocupado
port_in_use() {
  ss -tuln | grep -q ":$1 "
}

# Backup automático
backup_config() {
  cp $CONFIG $BACKUP
}

# Abrir firewall (ufw o iptables)
open_firewall() {
  if command -v ufw >/dev/null; then
    ufw allow $1/tcp >/dev/null 2>&1
  else
    iptables -A INPUT -p tcp --dport $1 -j ACCEPT
  fi
}

while true; do
clear

echo -e "${C}══════════════════════════════════════════════════${N}"
echo -e "${W}🔐 GESTION PRO DE SSH (KIRA)${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"

echo -e "${Y}⚠️ El puerto 22 es obligatorio y no se puede eliminar${N}"

PORTS=$(get_ports)

echo -e "${W}Puertos actuales:${N}"
for p in $PORTS; do
  echo -e "  ${W}$p${N} $(check_port $p)"
done

echo -e "${C}══════════════════════════════════════════════════${N}"

echo -e "${W}[1] ➮ AGREGAR PUERTO SSH${N}"
echo -e "${W}[2] ➮ ELIMINAR PUERTO SSH${N}"
echo -e "${R}[0] ➮ VOLVER${N}"

echo -e "${C}══════════════════════════════════════════════════${N}"

read -p "➤ Opcion: " op

case $op in

# 🔥 AGREGAR PUERTO PRO
1)
  read -p "Ingrese nuevo puerto: " PORT

  # Validar número
  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo -e "${R}Puerto invalido${N}"
    read -p "ENTER..."
    continue
  fi

  # Verificar duplicado
  if grep -q "^Port $PORT" $CONFIG; then
    echo -e "${R}Ese puerto ya existe${N}"
    read -p "ENTER..."
    continue
  fi

  # Detectar si está ocupado
  if port_in_use $PORT; then
    echo -e "${R}Ese puerto ya está en uso por otro servicio${N}"
    read -p "ENTER..."
    continue
  fi

  # Backup antes de modificar
  backup_config

  echo "Port $PORT" >> $CONFIG

  # Abrir firewall
  open_firewall $PORT

  systemctl restart ssh

  sleep 1

  if check_port $PORT | grep -q ON; then
    echo -e "${G}Puerto $PORT agregado y activo${N}"
  else
    echo -e "${R}Error al activar el puerto${N}"
    echo -e "${Y}Restaurando backup...${N}"
    cp $BACKUP $CONFIG
    systemctl restart ssh
  fi

  read -p "ENTER..."
  ;;

# 🔥 ELIMINAR PUERTO PRO
2)
  read -p "Ingrese puerto a eliminar: " PORT

  # Bloquear puerto 22
  if [ "$PORT" = "22" ]; then
    echo -e "${R}No puedes eliminar el puerto 22${N}"
    read -p "ENTER..."
    continue
  fi

  # Verificar existencia
  if ! grep -q "^Port $PORT" $CONFIG; then
    echo -e "${R}Ese puerto no existe${N}"
    read -p "ENTER..."
    continue
  fi

  TOTAL=$(get_ports | wc -l)

  # No dejar sin puertos
  if [ "$TOTAL" -le 1 ]; then
    echo -e "${R}No puedes eliminar el ultimo puerto${N}"
    read -p "ENTER..."
    continue
  fi

  # Backup antes de modificar
  backup_config

  sed -i "/^Port $PORT/d" $CONFIG
  systemctl restart ssh

  sleep 1

  if systemctl is-active --quiet ssh; then
    echo -e "${G}Puerto eliminado correctamente${N}"
  else
    echo -e "${R}Error en SSH, restaurando backup...${N}"
    cp $BACKUP $CONFIG
    systemctl restart ssh
  fi

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