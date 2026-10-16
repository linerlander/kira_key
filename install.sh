#!/bin/bash
# =============================================================================
#  KIRA · INSTALADOR  v1.0
#  bash <(curl -fsSL https://raw.githubusercontent.com/linerlander/kira_key/main/install.sh)
#  DEMO=1 bash install.sh   -> sólo dibuja, no toca el sistema
#
#  Este archivo es el ÚNICO que no usa lib/ui.sh: corre ANTES de que el
#  repositorio exista, así que lleva su propia copia mínima de la paleta.
# =============================================================================
set -u
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

VERSION="1.0"
REPO="https://github.com/linerlander/kira_key.git"
LOG="/tmp/kira-install.log"

# ============================================================== PALETA ======
E_RST=$'\e[0m'; E_BLD=$'\e[1m'
E_P1=$'\e[38;2;45;212;232m'    # cian
E_P2=$'\e[38;2;155;140;255m'   # violeta
E_OK=$'\e[38;2;63;224;168m'    # menta
E_WARN=$'\e[38;2;255;194;71m'  # ámbar
E_ERR=$'\e[38;2;255;95;109m'   # coral
E_MUT=$'\e[38;2;111;125;156m'  # gris
E_TXT=$'\e[38;2;220;228;245m'
E_OFF=$'\e[38;2;28;39;66m'
G1=(45 212 232); G2=(199 125 238)

# pad RECORTA además de rellenar, y cuenta CARACTERES: printf "%-30s" cuenta
# bytes y con tildes (versión, instalación) descuadra la columna.
pad()  { local s="$1" w="$2"; (( ${#s} > w )) && s="${s:0:w}"
         local n=$(( w - ${#s} )); printf '%s%*s' "$s" "$n" ''; }
rpad() { local s="$1" w="$2"; (( ${#s} > w )) && s="${s:0:w}"
         local n=$(( w - ${#s} )); printf '%*s%s' "$n" '' "$s"; }
rep()  { local i; for ((i=0;i<$2;i++)); do printf '%s' "$1"; done; }
mezcla() { local i=$1 n=$2; (( n<2 )) && n=2
  printf '%d;%d;%d' $(( G1[0]+(G2[0]-G1[0])*i/(n-1) )) \
                    $(( G1[1]+(G2[1]-G1[1])*i/(n-1) )) \
                    $(( G1[2]+(G2[2]-G1[2])*i/(n-1) )); }
regla() { local i; printf '  '
  for ((i=0;i<76;i++)); do printf '\e[38;2;%sm▀' "$(mezcla "$i" 76)"; done
  printf '%s\n' "$E_RST"; }
grad_txt() { local s="$1" f="${2:-0}"; local n=${#s}; local i p
  for ((i=0;i<n;i++)); do p=$(( i+f*3 )); (( p>=n )) && p=$(( n-1 ))
    printf '\e[38;2;%sm%s' "$(mezcla "$p" "$n")" "${s:i:1}"; done
  printf '%s' "$E_RST"; }

# ================================================================ PASOS =====
PASOS=("Comprobar requisitos" "Actualizar índice de paquetes" "Instalar dependencias"
       "Descargar KIRA"       "Permisos y versión"            "Configurar auto inicio")
EST=(pend pend pend pend pend pend)
DET=("" "" "" "" "" "")
RESULTADO=""; MENSAJE=""

REGLA_FIJA=""; LOGO=()
cachear() {
  REGLA_FIJA="$(regla)"
  local L=("██╗  ██╗██╗██████╗  █████╗ " "██║ ██╔╝██║██╔══██╗██╔══██╗"
           "█████╔╝ ██║██████╔╝███████║" "██╔═██╗ ██║██╔══██╗██╔══██║"
           "██║  ██╗██║██║  ██║██║  ██║" "╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝")
  local i; for i in 0 1 2 3 4 5; do LOGO[i]="$(grad_txt "${L[i]}" "$i")"; done
}

fila_paso() { # $1=indice · 2 + ▏1 + 1 + glifo1 + 1 + texto38 + 1 + detalle33 = 78
  local i=$1 g c
  case "${EST[i]}" in
    ok)    g="✔"; c="$E_OK"  ;;
    curso) g="◐"; c="$E_P1"  ;;
    falla) g="✖"; c="$E_ERR" ;;
    salta) g="–"; c="$E_MUT" ;;
    *)     g="○"; c="$E_OFF" ;;
  esac
  printf '  %s▏%s %s%s%s %s%s%s %s%s%s\n' "$E_OFF" "$E_RST" "$c" "$g" "$E_RST" \
    "$E_TXT" "$(pad "${PASOS[i]}" 38)" "$E_RST" "$E_MUT" "$(rpad "${DET[i]}" 33)" "$E_RST"
}

pintar() {
  local i
  echo
  printf '%s\n' "$REGLA_FIJA"
  echo
  # 2 + logo 27 + 3 + ┃ 1 + 2 + info 43 = 78, igual que en el menú
  for i in 0 1 2 3 4 5; do
    printf '  %s   %s┃%s  ' "${LOGO[i]}" "$E_OFF" "$E_RST"
    case $i in
      1) printf '%s%s%s' "$E_BLD$E_TXT" "$(pad 'INSTALADOR' 43)" "$E_RST" ;;
      2) printf '%s%s%s%s%s' "$E_BLD$E_P1" "$(pad "versión $VERSION" 18)" "$E_RST$E_MUT" \
                "$(pad 'administrador de VPS' 25)" "$E_RST" ;;
      3) printf '%s%s%s' "$E_MUT" "$(pad 'soporte @Loki_CC' 43)" "$E_RST" ;;
      *) printf '%*s' 43 '' ;;
    esac
    printf '\n'
  done
  echo
  printf '  %s▌%s %s%s%s %s%s%s\n' "$E_P1" "$E_RST" "$E_BLD$E_TXT" "INSTALACIÓN" "$E_RST" \
         "$E_OFF" "$(rep '─' 62)" "$E_RST"
  echo
  for i in 0 1 2 3 4 5; do fila_paso "$i"; done
  echo
  case "$RESULTADO" in
    ok)
      printf '  %s%s%s\n' "$E_BLD$E_OK" "$(pad '✔ INSTALACIÓN COMPLETA' 76)" "$E_RST"
      printf '  %s%s%s\n' "$E_TXT" "$(pad 'Salí y volvé a entrar al VPS, o escribí: kira' 76)" "$E_RST" ;;
    falla)
      printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $MENSAJE" 76)" "$E_RST"
      printf '  %s%s%s\n' "$E_MUT" "$(pad "Detalle completo en $LOG" 76)" "$E_RST" ;;
    *)
      printf '  %s%s%s\n' "$E_MUT" "$(pad '◐ Trabajando… puede tardar un par de minutos' 76)" "$E_RST"
      printf '  %s\n' "$(pad '' 76)" ;;
  esac
  echo
}

render() { local f; f="$(pintar)"; printf '\e[?2026h\e[H%s\e[0J\e[?2026l' "$f"; }
paso()   { EST[$1]="$2"; DET[$1]="${3:-}"; render; }
morir()  { EST[$1]=falla; DET[$1]="${2:-}"; RESULTADO=falla; MENSAJE="$3"; render
           printf '\e[?25h\n'; exit 1; }

# Todo el ruido de apt y git va al log: si sale por pantalla, destroza el marco.
ejec() { echo "+ $*" >> "$LOG"; "$@" >> "$LOG" 2>&1; }

# ================================================================= MAIN =====
cachear
trap 'printf "\e[?25h\e[?2026l\e[0m\n"' EXIT INT TERM
printf '\e[?25l'; clear
: > "$LOG"
render

# --- 1. Requisitos ----------------------------------------------------------
paso 0 curso
if [ -n "${DEMO:-}" ]; then
  sleep 0.5; paso 0 ok "modo demostración"
else
  # Sin root, apt falla y el script seguía igual anunciando éxito.
  if [ "$(id -u)" -ne 0 ]; then
    morir 0 "no sos root" "Ejecutá el instalador como root:  sudo bash install.sh"
  fi
  # printf '%(%s)T' y las tablas requieren bash 4.2 o más nuevo
  if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
    morir 0 "bash ${BASH_VERSION%%(*}" "KIRA necesita bash 4.2 o superior."
  fi
  command -v apt-get >/dev/null 2>&1 || \
    morir 0 "sin apt-get" "Este instalador es para Debian o Ubuntu."
  paso 0 ok "root · bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
fi

# --- 2. Índice de paquetes --------------------------------------------------
paso 1 curso
if [ -n "${DEMO:-}" ]; then sleep 0.6; paso 1 ok "listo"
elif ejec apt-get update; then paso 1 ok "listo"
else morir 1 "apt-get update falló" "No se pudo leer la lista de paquetes. ¿El VPS tiene internet?"
fi

# --- 3. Dependencias --------------------------------------------------------
# curl y git no alcanzan: el panel usa free, ss, tput, pgrep y tar. Sin
# iproute2 todos los servicios se ven OFF; sin ncurses-bin no se puede medir
# el ancho de la terminal.
DEPS=(curl git ca-certificates tar procps iproute2 ncurses-bin locales)
paso 2 curso
if [ -n "${DEMO:-}" ]; then
  sleep 0.8; paso 2 ok "${#DEPS[@]} paquetes"
else
  faltan=()
  for d in "${DEPS[@]}"; do
    dpkg -s "$d" >/dev/null 2>&1 || faltan+=("$d")
  done
  if [ ${#faltan[@]} -eq 0 ]; then
    paso 2 ok "ya estaban"
  elif ejec apt-get install -y "${faltan[@]}"; then
    paso 2 ok "${#faltan[@]} instalados"
  else
    morir 2 "apt-get install falló" "No se pudieron instalar: ${faltan[*]}"
  fi
  # El marco se dibuja con caracteres Unicode: sin locale UTF-8 salen como ?
  if ! locale -a 2>/dev/null | grep -qi 'C.utf8\|en_US.utf8'; then
    ejec locale-gen en_US.UTF-8
  fi
fi

# --- 4. Descarga ------------------------------------------------------------
# Con sudo, $HOME puede ser /root y el .bashrc del usuario queda en otro lado.
# Se usa el HOME del dueño real de la sesión.
DUENO="${SUDO_USER:-$(id -un)}"
CASA="$(getent passwd "$DUENO" 2>/dev/null | cut -d: -f6)"
[ -z "$CASA" ] && CASA="$HOME"
DESTINO="$CASA/kira_key"

paso 3 curso
if [ -n "${DEMO:-}" ]; then
  sleep 0.9; paso 3 ok "clonado"
elif [ -d "$DESTINO/.git" ]; then
  # Ya instalado: se actualiza en vez de no hacer nada
  if ejec git -C "$DESTINO" pull --ff-only; then paso 3 ok "actualizado"
  else morir 3 "git pull falló" "Hay cambios locales en $DESTINO. Movelo y reintentá."
  fi
elif [ -d "$DESTINO" ]; then
  morir 3 "la carpeta existe" "$DESTINO existe y no es un repositorio. Movela y reintentá."
elif ejec git clone --depth 1 "$REPO" "$DESTINO"; then
  paso 3 ok "clonado"
else
  morir 3 "git clone falló" "No se pudo descargar el repositorio desde GitHub."
fi

# --- 5. Permisos y versión --------------------------------------------------
paso 4 curso
if [ -n "${DEMO:-}" ]; then
  sleep 0.4; paso 4 ok "v$VERSION"
else
  # Sin 2>/dev/null: si chmod falla hay que enterarse, no esconderlo
  find "$DESTINO" -name '*.sh' -exec chmod +x {} + 2>>"$LOG"
  printf '%s\n' "$VERSION" > "$DESTINO/VERSION"
  chown -R "$DUENO":"$DUENO" "$DESTINO" 2>>"$LOG"
  # Atajo para no depender sólo del .bashrc
  printf '#!/bin/bash\ncd "%s" && exec bash menu.sh\n' "$DESTINO" > /usr/local/bin/kira
  chmod +x /usr/local/bin/kira
  paso 4 ok "v$VERSION · comando kira"
fi

# --- 6. Auto inicio ---------------------------------------------------------
# Tres arreglos sobre la versión anterior:
#  1) el guardia buscaba "kira_key/menu.sh", cadena que la línea escrita NO
#     contiene, así que cada corrida agregaba otra copia al .bashrc;
#  2) sin comprobar que la sesión sea interactiva, la línea rompe scp, rsync
#     y git-over-ssh, que también leen el .bashrc;
#  3) sin KIRA_ADENTRO, salir del menú lo vuelve a abrir en bucle.
BASHRC="$CASA/.bashrc"
MARCA="# >>> KIRA auto inicio >>>"
paso 5 curso
if [ -n "${DEMO:-}" ]; then
  sleep 0.4; paso 5 ok "activado"
else
  if grep -qF "$MARCA" "$BASHRC" 2>/dev/null; then
    paso 5 ok "ya estaba"
  else
    {
      printf '\n%s\n' "$MARCA"
      printf 'if [[ $- == *i* ]] && [ -z "${KIRA_ADENTRO:-}" ]; then\n'
      printf '  export KIRA_ADENTRO=1\n'
      printf '  cd "%s" && bash menu.sh\n' "$DESTINO"
      printf 'fi\n'
      printf '# <<< KIRA auto inicio <<<\n'
    } >> "$BASHRC"
    chown "$DUENO":"$DUENO" "$BASHRC" 2>>"$LOG"
    paso 5 ok "activado"
  fi
fi

RESULTADO=ok
render
printf '\e[?25h'