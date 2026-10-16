#!/bin/bash
# =============================================================================
#  KIRA · módulo 07 · ACTUALIZAR SCRIPT
#  Uso:  bash modules/update.sh
#        DEMO=1 bash modules/update.sh     (sin red, para ver el diseño)
#
#  Compara COMMITS de git, no números de versión. Cualquier push al repo se
#  detecta al instante y no hay que editar ningún archivo de versión a mano.
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
  exit 1
fi
source "$DIR/lib/ui.sh"

# ============================================================== AJUSTES =====
ARCH_VER="$DIR/VERSION"
RESPALDOS="$DIR/.respaldos"
LOG="/tmp/kira-update.log"

# La salida de git destroza el marco si sale por pantalla: va toda al log.
ejec() { echo "+ $*" >> "$LOG"; "$@" >> "$LOG" 2>&1; }
git_k() { git -C "$DIR" "$@" 2>/dev/null; }

VER_LOCAL="$(cat "$ARCH_VER" 2>/dev/null)"; [ -z "$VER_LOCAL" ] && VER_LOCAL="—"
RAMA="";  SHA_LOCAL="—"; SHA_REMOTO="—"; ATRAS=0; FECHA_REM="—"; AUTOR="—"
NOVEDADES=()
ESTADO="revisando"   # revisando · al_dia · disponible · instalando · listo · error
MENSAJE=""; BUF=""; SELLO=""

PASOS=("Consultar GitHub"     "Respaldar la versión actual" "Traer los commits nuevos"
       "Verificar archivos"   "Leer la versión"             "Reiniciar servicios")
EST=(pend pend pend pend pend pend)
DET=("" "" "" "" "" "")

# ================================================================ DATOS =====
revisar() {
  ESTADO="revisando"; render
  if [ -n "${DEMO:-}" ]; then
    RAMA="main"; SHA_LOCAL="a1b2c3d"; SHA_REMOTO="9f8e7d6"; ATRAS=3
    FECHA_REM="16/10 01:42"; AUTOR="linerlander"
    NOVEDADES=("Rediseño del panel de usuarios" "Arregla el conteo de sesiones"
               "Agrega soporte WebSocket")
    ESTADO="disponible"; return
  fi

  if [ ! -d "$DIR/.git" ]; then
    ESTADO="error"; MENSAJE="$DIR no es un repositorio git. Reinstalá con git clone."; return
  fi

  RAMA=$(git_k rev-parse --abbrev-ref HEAD); [ -z "$RAMA" ] && RAMA="main"

  # fetch trae las referencias del remoto SIN tocar tus archivos. Es lo que
  # permite saber si hay algo nuevo sin bajarlo todavía.
  if ! ejec git -C "$DIR" fetch --quiet origin "$RAMA"; then
    ESTADO="error"; MENSAJE="No se pudo contactar a GitHub. ¿El VPS tiene internet?"; return
  fi

  SHA_LOCAL=$(git_k rev-parse --short HEAD)
  SHA_REMOTO=$(git_k rev-parse --short "origin/$RAMA")
  ATRAS=$(git_k rev-list --count "HEAD..origin/$RAMA"); [ -z "$ATRAS" ] && ATRAS=0
  FECHA_REM=$(git_k log -1 --format=%cd --date=format:'%d/%m %H:%M' "origin/$RAMA")
  AUTOR=$(git_k log -1 --format=%an "origin/$RAMA")
  [ -z "$FECHA_REM" ] && FECHA_REM="—"; [ -z "$AUTOR" ] && AUTOR="—"

  # El historial de commits ES la lista de novedades: no hay que escribirla.
  mapfile -t NOVEDADES < <(git_k log --format=%s "HEAD..origin/$RAMA" | head -12)

  if [ "$ATRAS" -gt 0 ]; then ESTADO="disponible"; else ESTADO="al_dia"; fi
}

# ============================================================== PANTALLA ====
# Caja izquierda: 1 + etiqueta 12 + valor 13 + marca 9 = 35
fila_izq() { # $1=etiqueta $2=valor $3=color $4=marca
  caja_izq " $E_MUT$(pad "$1" 12)$E_RST$3$(pad "$2" 13)$E_RST$E_BLD$E_WARN$(rpad "${4:-}" 9)$E_RST"
}
# Caja derecha: 1 + viñeta 1 + 1 + texto 32 = 35
fila_der() {
  if [ -n "${1:-}" ]; then caja_der " $E_P1•$E_RST $E_TXT$(pad "$1" 32)$E_RST"
  else                     caja_der "$(pad '' 35)"; fi
}

paneles() {
  local marca="" tit="CAMBIOS NUEVOS"
  [ "$ESTADO" = "disponible" ] && marca="NUEVOS"
  [ "$ATRAS" -eq 0 ] 2>/dev/null && tit="SIN CAMBIOS"
  techo "ESTADO" "$E_P1" "$tit" "$E_P2"
  fila_izq "VERSIÓN"  "$VER_LOCAL"  "$E_TXT"      ""      ; fila_der "${NOVEDADES[0]:-}"
  fila_izq "RAMA"     "${RAMA:-—}"  "$E_INFO"     ""      ; fila_der "${NOVEDADES[1]:-}"
  fila_izq "TU COPIA" "$SHA_LOCAL"  "$E_TXT"      ""      ; fila_der "${NOVEDADES[2]:-}"
  fila_izq "EN GITHUB" "$SHA_REMOTO" "$E_BLD$E_OK" "$marca"; fila_der "${NOVEDADES[3]:-}"
  fila_izq "ÚLTIMO"   "$FECHA_REM"  "$E_MUT"      ""      ; fila_der "${NOVEDADES[4]:-}"
  piso
}

# Fila de paso: 2 + ▏1 + 1 + glifo 1 + 1 + texto 38 + 1 + detalle 33 = 78
fila_paso() {
  local i=$1 g c
  case "${EST[i]}" in
    ok)    g="✔"; c="$E_OK"  ;;
    curso) g="◐"; c="$E_P1"  ;;
    falla) g="✖"; c="$E_ERR" ;;
    *)     g="○"; c="$E_MUT" ;;
  esac
  printf '  %s▏%s %s%s%s %s%s%s %s%s%s\n' "$E_OFF" "$E_RST" "$c" "$g" "$E_RST" \
    "$E_TXT" "$(pad "${PASOS[i]}" 38)" "$E_RST" "$E_MUT" "$(rpad "${DET[i]}" 33)" "$E_RST"
}

ACC_NUM=(01 02 00)
ACC_EMO=("📥" "📋" "🚪")
ACC_TXT=("ACTUALIZAR AHORA" "VER TODOS LOS CAMBIOS" "VOLVER AL MENÚ")
acciones() {
  local i n f bar chip col
  for i in 0 1 2; do
    n="${ACC_NUM[i]}"
    if [ "$i" = 0 ] && [ "$ESTADO" != "disponible" ]; then col="$E_OFF"; else col="$E_TXT"; fi
    if [ -n "$BUF" ] && { [ "$BUF" = "$n" ] || [ "$BUF" = "${n#0}" ]; }; then
      f="$B_SEL"; bar="$E_P1▌$E_RST$f"; chip="$B_CHIP$E_BLD$E_P1"
    else
      f=""; bar="$E_OFF▏$E_RST"; chip="$B_CHIP$E_P1"
    fi
    printf '%s  %s %s %s %s %s%s\n' "$f" "$bar" "$chip $n $E_RST$f" \
      "$E_P2${ACC_EMO[i]}$E_RST$f" "$E_OFF│$E_RST$f" \
      "$E_BLD$col$(pad "${ACC_TXT[i]}" 64)" "$E_RST"
  done
}

aviso() {
  local t
  case "$ESTADO" in
    al_dia)     t="✔ Tu copia está al día con GitHub" ;;
    disponible) t="▸ Hay $ATRAS commit(s) nuevo(s) · pulsá 01 para traerlos" ;;
    listo)      t="✔ Actualizado · $ATRAS commit(s) aplicados" ;;
    error)      t="✖ $MENSAJE" ;;
    instalando) t="◐ Actualizando… no cierres la terminal" ;;
    revisando)  t="◐ Consultando GitHub…" ;;
    *)          t="" ;;
  esac
  case "$ESTADO" in
    al_dia|listo) printf '  %s%s%s\n' "$E_BLD$E_OK"  "$(pad "$t" 76)" "$E_RST" ;;
    error)        printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "$t" 76)" "$E_RST" ;;
    disponible)   printf '  %s%s%s\n' "$E_BLD$E_WARN" "$(pad "$t" 76)" "$E_RST" ;;
    *)            printf '  %s%s%s\n' "$E_MUT" "$(pad "$t" 76)" "$E_RST" ;;
  esac
}

prompt() {
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  echo
  encabezado "ACTUALIZAR SCRIPT" "KIRA v$VER_LOCAL"
  echo
  paneles
  echo
  seccion "PROCESO" "$E_P2"
  echo
  local i; for i in 0 1 2 3 4 5; do fila_paso "$i"; done
  echo
  aviso
  echo
  acciones
  echo
  prompt
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# =========================================================== INSTALACIÓN ====
paso()   { EST[$1]="$2"; DET[$1]="${3:-}"; render; }
fallar() { EST[$1]=falla; DET[$1]="${2:-}"; ESTADO="error"; MENSAJE="$3"; render; }

actualizar() {
  local faltantes f
  paso 0 ok "$ATRAS nuevos"

  # Respaldo ANTES de tocar nada: si algo falla a mitad, hay con qué volver.
  paso 1 curso
  mkdir -p "$RESPALDOS"
  SELLO="$(date +%Y%m%d-%H%M%S)"
  if [ -n "${DEMO:-}" ]; then
    sleep 0.5; paso 1 ok "guardada"
  elif tar czf "$RESPALDOS/kira-$SHA_LOCAL-$SELLO.tgz" -C "$DIR" --exclude='.respaldos' --exclude='.git' . 2>/dev/null; then
    paso 1 ok "$SHA_LOCAL guardada"
  else
    fallar 1 "sin permisos" "No se pudo respaldar. Se cancela para no dejar el panel a medias."
    return 1
  fi

  paso 2 curso
  if [ -n "${DEMO:-}" ]; then
    sleep 0.8; paso 2 ok "9f8e7d6"
  else
    # El respaldo ya está hecho, así que se descartan los cambios locales: un
    # archivo tocado a mano no debe bloquear la actualización.
    if [ -n "$(git_k status --porcelain)" ]; then
      ejec git -C "$DIR" checkout -- .
    fi
    if ejec git -C "$DIR" merge --ff-only "origin/$RAMA"; then
      paso 2 ok "$(git_k rev-parse --short HEAD)"
    else
      fallar 2 "no se pudo fusionar" "El historial local divergió. Reinstalá con git clone."
      return 1
    fi
  fi

  # Que los archivos que el panel necesita estén y no hayan quedado a medias
  paso 3 curso
  faltantes=""
  for f in menu.sh lib/ui.sh; do
    [ -r "$DIR/$f" ] || faltantes="$faltantes $f"
  done
  if [ -n "$faltantes" ]; then
    fallar 3 "faltan archivos" "El repo no trae:$faltantes. Restaurá el respaldo $SELLO."
    return 1
  fi
  if [ -z "${DEMO:-}" ] && ! bash -n "$DIR/menu.sh" 2>>"$LOG"; then
    fallar 3 "menu.sh con errores" "Lo descargado no es válido. Restaurá el respaldo $SELLO."
    return 1
  fi
  paso 3 ok "sintaxis correcta"

  # VERSION viene EN el repo: el merge ya lo actualizó. Sólo se lee. Si este
  # script lo escribiera, al estar versionado el próximo pull chocaría con
  # "local changes would be overwritten".
  paso 4 curso
  if [ -z "${DEMO:-}" ]; then
    VER_LOCAL="$(cat "$ARCH_VER" 2>/dev/null)"; [ -z "$VER_LOCAL" ] && VER_LOCAL="—"
    SHA_LOCAL=$(git_k rev-parse --short HEAD); SHA_REMOTO="$SHA_LOCAL"
  else
    SHA_LOCAL="9f8e7d6"; SHA_REMOTO="9f8e7d6"
  fi
  paso 4 ok "v$VER_LOCAL"

  paso 5 curso
  if [ -z "${DEMO:-}" ]; then
    systemctl daemon-reload 2>/dev/null; systemctl restart kira 2>/dev/null
  else sleep 0.3; fi
  paso 5 ok "al día"

  ESTADO="listo"; render

  # Bash ya tiene el código viejo en memoria: sin reiniciar, el usuario
  # actualiza y sigue usando la versión anterior sin notarlo.
  if [ -z "${DEMO:-}" ] && [ -r "$DIR/menu.sh" ]; then
    sleep 2; cursor_on; exec bash "$DIR/menu.sh"
  fi
}

ver_cambios() {
  local f; f="$(
    echo; printf '%s\n' "$REGLA_FIJA"; echo
    encabezado "CAMBIOS PENDIENTES" "${RAMA:-main} · $SHA_LOCAL → $SHA_REMOTO"
    echo
    if [ ${#NOVEDADES[@]} -eq 0 ]; then
      printf '  %s%s%s\n' "$E_MUT" "$(pad 'No hay commits nuevos.' 76)" "$E_RST"
    else
      local n
      for n in "${NOVEDADES[@]}"; do
        printf '  %s•%s %s%s%s\n' "$E_P1" "$E_RST" "$E_TXT" "$(pad "$n" 74)" "$E_RST"
      done
    fi
    echo
    printf '  %s%s%s\n' "$E_OFF" "$(rep '─' 76)" "$E_RST"
    echo
    printf '  %s%s%s\n' "$E_MUT" "$(pad 'Una tecla para volver…' 76)" "$E_RST"
  )"
  volcar "$f"
  read -rsn1 _
}

# ================================================================= MAIN =====
exigir_ancho
REGLA_FIJA="$(regla '▀' 76)"
# El manejador de INT/TERM DEBE salir. Si sólo limpia, Ctrl+C ejecuta el
# trap y el bucle sigue corriendo: no hay forma de cortar el script.
trap 'cursor_on; printf "\e[?2026l\e[0m\n"' EXIT
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; exit 130' INT TERM
cursor_off
clear
: > "$LOG"

render        # el marco primero: el usuario no ve la pantalla en blanco
revisar
render

procesar() {
  case "$1" in
    "")
      case "$BUF" in
        1|01) [ "$ESTADO" = "disponible" ] && { ESTADO="instalando"; render; actualizar; } ;;
        2|02) ver_cambios ;;
        0|00) exit 0 ;;
        9|99) revisar ;;     # volver a consultar sin salir del módulo
      esac
      BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    [0-9])         [ ${#BUF} -lt 2 ] && BUF="$BUF$1" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;
  esac
}

while true; do
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done