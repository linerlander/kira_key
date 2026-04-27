#!/bin/bash

clear
echo "========================="
echo "     SCRIPT KIRA"
echo "========================="
echo "1) Ver IP"
echo "2) Ver RAM"
echo "0) Salir"
echo "========================="

read -p "Elige una opcion: " op

case $op in
1) curl ifconfig.me ;;
2) free -h ;;
0) exit ;;
*) echo "Opcion invalida" ;;
esac