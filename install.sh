#!/bin/bash

echo "═══════════════════════════════"
echo "     🚀 INSTALADOR KIRA"
echo "═══════════════════════════════"

sleep 1

echo "🔄 Actualizando sistema..."
apt update -y

echo "📦 Instalando dependencias..."
apt install curl -y

echo "🔐 Dando permisos..."
chmod +x ~/kira_key/*.sh 2>/dev/null

echo "⚙️ Configurando auto inicio..."

# Evitar duplicados en bashrc
if ! grep -q "kira_key/menu.sh" ~/.bashrc; then
  echo '' >> ~/.bashrc
  echo 'cd ~/kira_key && bash menu.sh' >> ~/.bashrc
fi

echo "═══════════════════════════════"
echo "✅ INSTALACION COMPLETA"
echo "👉 Vuelve a entrar al VPS"
echo "═══════════════════════════════"