panel_usuarios() {

clear

# ===== LOGO KIRA =====
echo -e "${G}"
echo "██╗  ██╗██╗██████╗  █████╗ "
echo "██║ ██╔╝██║██╔══██╗██╔══██╗"
echo "█████╔╝ ██║██████╔╝███████║"
echo "██╔═██╗ ██║██╔══██╗██╔══██║"
echo "██║  ██╗██║██║  ██║██║  ██║"
echo "╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
echo -e "${N}"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " 🔐 ${W}KIRA USER MANAGER SYSTEM${N} 🔐"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== STATS =====
RAM=$(free -m | awk '/Mem:/ {print $4}')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')

printf " ${C}▶ RAM:${N} ${G}%-6s${N}   ${C}▶ CPU:${N} ${G}%s%%%s\n" "${RAM}MB" "$CPU" "$N"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ===== MENU (ALINEADO PRO) =====
printf " ${G}[01]${N} ◇ AGREGAR USUARIO (KIRA)              📝\n"
printf " ${G}[02]${N} ◇ BORRAR USUARIO/s                   🗑️\n"
printf " ${G}[03]${N} ◇ EDITAR / RENOVAR                  🔄\n"
printf " ${G}[04]${N} ◇ USUARIOS REGISTRADOS              📋\n"
printf " ${G}[05]${N} ◇ USUARIOS ONLINE                   🌐\n"
printf " ${G}[06]${N} ◇ BANNER SSH                        🖥️\n"
printf " ${G}[07]${N} ◇ LOG DE CONSUMO                    📊\n"
printf " ${G}[08]${N} ◇ BLOQUEAR USUARIOS (${R}LOCK${N})       🔒\n"
printf " ${G}[09]${N} ◇ BACKUP (${G}KIRA${N})                  💾\n"
printf " ${G}[10]${N} ◇ CUENTAS SSR/SS                    ⚙️\n"
printf " ${G}[11]${N} ◇ BOT TELEGRAM (${G}ON${N}) (${Y}BETA${N}) 🤖\n"
printf " ${G}[12]${N} ◇ VERIFICADOR                      🧪\n"
printf " ${G}[13]${N} ◇ CHECKUSER (${R}OFF${N})               📡\n"
printf " ${G}[14]${N} ◇ MULTILOGIN CONTROL               🔥\n"

echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e " ${R}[0]${N} ◇ ${R}REGRESAR${N}"
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e " ${G}(KIRA CORE: ON)${N}   ${C}(KILL MULTI: OFF)${N}"

echo
read -p " ▶ Opcion : " op

case $op in
1|01) crear_user ;;
2|02) eliminar_user ;;
4|04) listar_users ;;
5|05) online_users ;;
0) break ;;
*) echo -e "${R}Opcion invalida${N}"; sleep 1 ;;
esac

}