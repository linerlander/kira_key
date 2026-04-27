#!/bin/bash

R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

while true; do
clear

echo -e "${C}"
echo "   ___              __             __      "
echo "  / (_)__  ___ ____/ /__ ____  ___/ /__    "
echo " / / / _ \/ -_) __/ / _ \`/ _ \/ _  / -_)   "
echo "/_/_/_//_/\__/_/ /_/\_,_/_//_/\_,_/\__/    "
echo -e "${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${W}[1] ➮ AGREGAR NUEVO PUERTO SSH${N}"
echo -e " ${W}[2] ➮ REMOVER PUERTO OPENSSH${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0] ➮ [ REGRESAR ]${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

read -p "➤ Opcion: " op

case $op in

1)
  read -p "Ingrese nuevo puerto SSH: " PORT

  if grep -q "Port $PORT" /etc/ssh/sshd_config; then
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

  if grep -q "Port $PORT" /etc/ssh/sshd_config; then
    sed -i "/Port $PORT/d" /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "${G}Puerto eliminado${N}"
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