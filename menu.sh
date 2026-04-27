#!/bin/bash

while true; do
clear

echo "=================================="
echo "        🔥 SCRIPT KIRA 🔥"
echo "=================================="
echo "1) Ver IP del VPS"
echo "2) Ver uso de RAM"
echo "3) Actualizar sistema"
echo "0) Salir"
echo "=================================="

read -p "Elige una opcion: " op

case $op in
1)
  echo "Tu IP es:"
  curl -s ifconfig.me
  echo ""
  read -p "Presiona ENTER para continuar..."
  ;;
2)
  free -h
  read -p "Presiona ENTER para continuar..."
  ;;
3)
  apt update -y && apt upgrade -y
  read -p "Presiona ENTER para continuar..."
  ;;
0)
  exit
  ;;
*)
  echo "Opcion invalida"
  sleep 1
  ;;
esac

done