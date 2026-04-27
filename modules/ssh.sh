#!/bin/bash

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

# Obtener puertos configurados
get_ports() {
  grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}'
}

# Verificar si el puerto está activo
check_port() {
  ss -tuln | grep -q ":$1 " && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

while true; do
clear

echo -e "${C}"
echo "   ___              __             __      "
echo "  / (_)__  ___ ____/ /__ ____  ___/ /__    "
echo " / / / _ \/ -_) __/ / _ \`/ _ \/ _  / -_)   "
echo "/_/_/_//_/\__/_/ /_/\_,_/_//_/\_,_/\__/    "
echo -e "${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${W}       🔐 GESTION DE PUERTOS SSH${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${Y}Puertos configurados:${N}"

PORTS=$(get_ports)

if [ -z "$PORTS" ]; then
  echo -e "${R}No hay puertos configurados${N}"
else
  for p in $PORTS; do
    echo -e " ${W}Puerto $p:${N} $(check_port $p)"
  done
fi

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${W}[1] ➮ AGREGAR NUEVO PUERTO SSH${N}"
echo -e "${W}[2] ➮ REMOVER PUERTO SSH${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${R}[0] ➮ [ REGRESAR ]${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op

case $op in

1)
  read -p "Ingrese nuevo puerto SSH: " PORT

  if grep -q "^Port $PORT" /etc/ssh/sshd_config; then
    echo -e "${R}El puerto ya existe${N}"
  else
    echo "Port $PORT" >> /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "${G}Puerto agregado correctamente${N}"
  fi

  read -p "ENTER para continuar..."
  ;;

2)
  read -p "Ingrese puerto a eliminar: " PORT

  if [ "$PORT" = "22" ]; then
    echo -e "${R}No puedes eliminar el puerto 22 (seguridad)${N}"
  elif grep -q "^Port $PORT" /etc/ssh/sshd_config; then
    sed -i "/^Port $PORT/d" /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "${G}Puerto eliminado correctamente${N}"
  else
    echo -e "${R}Ese puerto no existe${N}"
  fi

  read -p "ENTER para continuar..."
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