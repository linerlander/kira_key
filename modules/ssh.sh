#!/bin/bash

# Colores
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

# Obtener puertos
get_ports() {
  grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}'
}

# Verificar puerto activo
check_port() {
  ss -tuln | grep -q ":$1 " && echo -e "${G}[ON]${N}" || echo -e "${R}[OFF]${N}"
}

while true; do
clear

echo -e "${C}══════════════════════════════════════════════════${N}"
echo -e "${W}🔐 GESTION DE PUERTOS SSH${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"

# ⚠️ MENSAJE IMPORTANTE
echo -e "${Y}⚠️  IMPORTANTE:${N} El puerto 22 es el principal del sistema."
echo -e "${R}Si se elimina, puedes perder acceso total al VPS.${N}"
echo -e "${G}Por seguridad, este script NO permite eliminar el puerto 22.${N}"

echo -e "${C}══════════════════════════════════════════════════${N}"

PORTS=$(get_ports)

echo -e "${W}Puertos configurados:${N}"
for p in $PORTS; do
  echo -e "  ${W}$p${N} $(check_port $p)"
done

echo -e "${C}══════════════════════════════════════════════════${N}"

echo -e "${W}[1] ➮ AGREGAR NUEVO PUERTO SSH${N}"
echo -e "${W}[2] ➮ ELIMINAR PUERTO SSH${N}"
echo -e "${R}[0] ➮ VOLVER${N}"

echo -e "${C}══════════════════════════════════════════════════${N}"

read -p "➤ Opcion: " op

case $op in

# 🔥 AGREGAR PUERTO
1)
  read -p "Ingrese nuevo puerto: " PORT

  if grep -q "^Port $PORT" /etc/ssh/sshd_config; then
    echo -e "${R}Ese puerto ya existe${N}"
  else
    echo "Port $PORT" >> /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "${G}Puerto agregado correctamente${N}"
  fi

  read -p "ENTER..."
  ;;

# 🔥 ELIMINAR PUERTO (PROTEGIDO)
2)
  read -p "Ingrese puerto a eliminar: " PORT

  # ❌ BLOQUEAR PUERTO 22
  if [ "$PORT" = "22" ]; then
    echo -e "${R}❌ NO PUEDES ELIMINAR EL PUERTO 22${N}"
    echo -e "${Y}Es el puerto principal del sistema SSH.${N}"
    read -p "ENTER..."
    continue
  fi

  if grep -q "^Port $PORT" /etc/ssh/sshd_config; then
    sed -i "/^Port $PORT/d" /etc/ssh/sshd_config
    systemctl restart ssh
    echo -e "${G}Puerto eliminado correctamente${N}"
  else
    echo -e "${R}Ese puerto no existe${N}"
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