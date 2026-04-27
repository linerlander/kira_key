#!/bin/bash

# Colores
rojo="\e[31m"
verde="\e[32m"
amarillo="\e[33m"
azul="\e[34m"
magenta="\e[35m"
cian="\e[36m"
blanco="\e[97m"
reset="\e[0m"

while true; do
clear

echo -e "${cian}╔══════════════════════════════════════╗${reset}"
echo -e "${cian}║        ${verde}🔥 SCRIPT KIRA 🔥${cian}        ║${reset}"
echo -e "${cian}╠══════════════════════════════════════╣${reset}"
echo -e "${cian}║ ${amarillo}[1]${blanco} Ver IP del VPS          ${cian}║${reset}"
echo -e "${cian}║ ${amarillo}[2]${blanco} Ver uso de RAM         ${cian}║${reset}"
echo -e "${cian}║ ${amarillo}[3]${blanco} Actualizar sistema     ${cian}║${reset}"
echo -e "${cian}║ ${rojo}[0]${blanco} Salir                   ${cian}║${reset}"
echo -e "${cian}╚══════════════════════════════════════╝${reset}"

echo ""
read -p "➤ Elige una opcion: " op

case $op in
1)
  echo -e "\n${verde}🌐 Tu IP es:${reset}"
  curl -s ifconfig.me
  echo ""
  read -p "Presiona ENTER para continuar..."
  ;;
2)
  echo -e "\n${azul}💾 Uso de memoria:${reset}"
  free -h
  read -p "Presiona ENTER para continuar..."
  ;;
3)
  echo -e "\n${amarillo}⚙️ Actualizando sistema...${reset}"
  apt update -y && apt upgrade -y
  read -p "Presiona ENTER para continuar..."
  ;;
0)
  echo -e "${rojo}Saliendo...${reset}"
  exit
  ;;
*)
  echo -e "${rojo}❌ Opción inválida${reset}"
  sleep 1
  ;;
esac

done