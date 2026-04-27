#!/bin/bash

echo "═══════════════════════════════"
echo "     🚀 INSTALADOR KIRA"
echo "═══════════════════════════════"

sleep 1

echo "🔄 Actualizando sistema..."
apt update -y

echo "📦 Instalando dependencias..."
apt install curl git -y

# Validar carpeta
if [ ! -d "$HOME/kira_key" ]; then
  echo "📥 Clonando repositorio..."
  git clone https://github.com/linerlander/kira_key.git $HOME/kira_key
fi

echo "🔐 Dando permisos..."
chmod +x $HOME/kira_key/*.sh 2>/dev/null
chmod +x $HOME/kira_key/modules/*.sh 2>/dev/null

echo "⚙️ Configurando auto inicio..."

# evitar duplicado
if ! grep -q "kira_key/menu.sh" ~/.bashrc; then
  echo '' >> ~/.bashrc
  echo 'cd ~/kira_key && bash menu.sh' >> ~/.bashrc
fi

echo "═══════════════════════════════"
echo "✅ INSTALACION COMPLETA"
echo "👉 Sal y vuelve a entrar al VPS"
echo "═══════════════════════════════"