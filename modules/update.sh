#!/bin/bash
# =============================================================================
#  KIRA · módulo 07 · ACTUALIZAR SCRIPT
#  Uso:  bash modules/update.sh
#        DEMO=1 bash modules/update.sh     (sin red, para ver el diseño)
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
  exit 1
fi
source "$DIR/lib/ui.sh"

# ============================================================== AJUSTES =====
ORIGEN="${KIRA_ORIGEN:-https://raw.githubusercontent.com/linerlander/kira_key/main}"
ARCH_VER="$DIR/VERSION"
LOG="/tmp/kira-update.log"

# La salida de git destroza el marco si sale por pantalla: va toda al log.
ejec() { echo "+ $*" >> "$LOG"; "$@" >> "$LOG" 2>&1; }
RESPALDOS="$DIR/.respaldos"

VER_LOCAL="$(cat "$ARCH_VER" 2>/dev/null || echo "1.0")"
VER_REMOTA=""; FECHA_REM=""; TAM_REM=""; CANAL="estable"
NOVEDADES=()
ESTADO="revisando"   # revisando · al_dia · disponible · instalando · listo · error
MENSAJE=""
BUF=""
SELLO=""

PASOS=("Comprobar versión remota" "Respaldar la versión actual" "Traer cambios de GitHub"
       "Verificar archivos"       "Confirmar versión"           "Reiniciar servicios")
EST=(pend pend pend pend pend pend)
DET=("" "" "" "" "" "")
PCT=(0 0 0 0 0 0)

# ================================================================ DATOS =====
revisar() {
  if [ -n "${DEMO:-}" ]; then
    VER_REMOTA="1.1"; FECHA_REM="12/10/2026"; TAM_REM="412K"; CANAL="estable"
    # Hasta 32 caracteres: lo que entra en la caja. El texto completo de cada
    # cambio se ve en la opción 02, que dispone de 74 columnas.
    NOVEDADES=("Panel de usuarios rehecho" "Soporte V2Ray y WebSocket"
               "Arregla el conteo de sesiones" "Respaldo automático al instalar"
               "Corrige lectura de sshd_config")
    ESTADO="disponible"; return
  fi
  local meta; meta=$(curl -fsS --max-time 8 "$ORIGEN/VERSION.json" 2>/dev/null)
  if [ -z "$meta" ]; then
    ESTADO="error"; MENSAJE="No se pudo contactar al servidor de actualizaciones"; return
  fi
  # Se lee con awk y no con jq: jq no viene instalado en la mayoría de los VPS.
  # El `tr` parte por comas para que funcione igual si el JSON viene en una
  # sola línea; sin eso, awk toma el primer campo de la línea y devuelve el
  # valor equivocado en todas las claves menos la primera.
  # Se busca la clave ENTRE COMILLAS seguida de dos puntos, y se recorre cada
  # línea buscando TODAS las coincidencias. Dos trampas que esto evita:
  #  - partir por comillas y contar campos falla, porque la clave "notas"
  #    contiene "nota" y corre las posiciones;
  #  - partir por comas rompe los valores que llevan coma adentro
  #    ("Barras de RAM, CPU y disco" se cortaba al medio).
  jval() { awk -v k="$1" '
    match($0, "\""k"\"[[:space:]]*:[[:space:]]*\"[^\"]*\"") {
      v = substr($0, RSTART, RLENGTH)
      sub("^\""k"\"[[:space:]]*:[[:space:]]*\"", "", v); sub("\"$", "", v)
      print v; exit }' <<< "$meta"; }
  VER_REMOTA=$(jval version)
  FECHA_REM=$(jval fecha)
  TAM_REM=$(jval tamano)
  CANAL=$(jval canal)
  mapfile -t NOVEDADES < <(awk '
    { s = $0
      while (match(s, "\"nota\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")) {
        v = substr(s, RSTART, RLENGTH)
        sub("^\"nota\"[[:space:]]*:[[:space:]]*\"", "", v); sub("\"$", "", v)
        print v
        s = substr(s, RSTART + RLENGTH) } }' <<< "$meta")
  [ -z "$VER_REMOTA" ] && { ESTADO="error"; MENSAJE="Respuesta inválida del servidor"; return; }
  [ "$VER_LOCAL" = "$VER_REMOTA" ] && ESTADO="al_dia" || ESTADO="disponible"
}

# ============================================================== PANTALLA ====
# Caja izquierda: 1 + etiqueta 12 + valor 13 + marca 9 = 35
fila_izq() { # $1=etiqueta $2=valor $3=color $4=marca
  caja_izq " $E_MUT$(pad "$1" 12)$E_RST$3$(pad "$2" 13)$E_RST$E_BLD$E_WARN$(rpad "${4:-}" 9)$E_RST"
}
# Caja derecha: 1 + viñeta 1 + 1 + texto 32 = 35
fila_der() { # $1=novedad
  if [ -n "${1:-}" ]; then caja_der " $E_P1•$E_RST $E_TXT$(pad "$1" 32)$E_RST"
  else                     caja_der "$(pad '' 35)"; fi
}

paneles() {
  local marca=""; [ "$ESTADO" = "disponible" ] && marca="NUEVA"
  techo "VERSIÓN" "$E_P1" "NOVEDADES ${VER_REMOTA:-}" "$E_P2"
  fila_izq "INSTALADA"  "$VER_LOCAL"       "$E_TXT"      ""      ; fila_der "${NOVEDADES[0]:-}"
  fila_izq "DISPONIBLE" "${VER_REMOTA:-—}" "$E_BLD$E_OK" "$marca"; fila_der "${NOVEDADES[1]:-}"
  fila_izq "PUBLICADA"  "${FECHA_REM:-—}"  "$E_TXT"      ""      ; fila_der "${NOVEDADES[2]:-}"
  fila_izq "TAMAÑO"     "${TAM_REM:-—}"    "$E_TXT"      ""      ; fila_der "${NOVEDADES[3]:-}"
  fila_izq "CANAL"      "$CANAL"           "$E_INFO"     ""      ; fila_der "${NOVEDADES[4]:-}"
  piso
}

# Fila de paso: 2 + ▏1 + 1 + glifo 1 + 1 + texto 38 + 1 + derecha 33 = 78
fila_paso() { # $1=indice
  local i=$1 g c der
  case "${EST[i]}" in
    ok)    g="✔"; c="$E_OK"  ;;
    curso) g="◐"; c="$E_P1"  ;;
    falla) g="✖"; c="$E_ERR" ;;
    *)     g="○"; c="$E_MUT" ;;
  esac
  if [ "${EST[i]}" = "curso" ] && [ "${PCT[i]}" -gt 0 ]; then
    der="$(barra_fija "${PCT[i]}" 24 "$E_P1") $E_TXT$(rpad "${PCT[i]}%" 4)$E_RST    "
  else
    der="$E_MUT$(rpad "${DET[i]}" 33)$E_RST"
  fi
  printf '  %s▏%s %s%s%s %s%s%s %s\n' "$E_OFF" "$E_RST" "$c" "$g" "$E_RST" \
         "$E_TXT" "$(pad "${PASOS[i]}" 38)" "$E_RST" "$der"
}

# Acción: 2 + bar1 + 1 + chip4 + 1 + emoji2 + 1 + sep1 + 1 + texto 64 = 78
ACC_NUM=(01 02 00)
ACC_EMO=("📥" "📋" "🚪")
ACC_TXT=("ACTUALIZAR AHORA" "VER CAMBIOS COMPLETOS" "VOLVER AL MENÚ")
acciones() {
  local i n f bar chip col
  for i in 0 1 2; do
    n="${ACC_NUM[i]}"
    # "Actualizar ahora" se apaga si no hay nada nuevo que instalar
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
  case "$ESTADO" in
    al_dia) printf '  %s%s%s\n' "$E_BLD$E_OK"  "$(pad "✔ Ya estás en la última versión" 76)" "$E_RST" ;;
    listo)  printf '  %s%s%s\n' "$E_BLD$E_OK"  "$(pad "✔ Actualizado a la versión $VER_REMOTA" 76)" "$E_RST" ;;
    error)  printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $MENSAJE" 76)" "$E_RST" ;;
    instalando) printf '  %s%s%s\n' "$E_P1" "$(pad "◐ Instalando… no cierres la terminal" 76)" "$E_RST" ;;
    revisando)  printf '  %s%s%s\n' "$E_MUT" "$(pad "◐ Consultando el servidor…" 76)" "$E_RST" ;;
    *)      printf '  %s\n' "$(pad '' 76)" ;;
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
paso() { EST[$1]="$2"; DET[$1]="${3:-}"; render; }

fallar() { # $1=indice $2=detalle $3=mensaje
  EST[$1]=falla; DET[$1]="$2"; ESTADO="error"; MENSAJE="$3"; render
}

actualizar() {
  local faltantes f
  paso 0 ok "v$VER_REMOTA"

  # Respaldo ANTES de tocar nada: si algo falla a mitad, hay con qué volver.
  paso 1 curso
  mkdir -p "$RESPALDOS"
  SELLO="$(date +%Y%m%d-%H%M%S)"
  if [ -n "${DEMO:-}" ]; then
    sleep 0.5; paso 1 ok "$VER_LOCAL guardada"
  elif tar czf "$RESPALDOS/kira-$VER_LOCAL-$SELLO.tgz" -C "$DIR" --exclude='.respaldos' . 2>/dev/null; then
    paso 1 ok "$VER_LOCAL guardada"
  else
    fallar 1 "sin permisos" "No se pudo respaldar. Se cancela para no dejar el script a medias."
    return 1
  fi

  # Se actualiza con git, no bajando un paquete: el repo ya es la fuente.
  # Así no hay que armar un .tgz ni su firma en cada versión, y git verifica
  # la integridad de cada objeto por su propio hash.
  paso 2 curso
  if [ -n "${DEMO:-}" ]; then
    sleep 0.7; paso 2 ok "5 archivos"
  elif [ -d "$DIR/.git" ]; then
    # El respaldo ya está hecho, así que se descartan los cambios locales: un
    # archivo tocado a mano no debe bloquear la actualización.
    if [ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ]; then
      ejec git -C "$DIR" checkout -- .
    fi
    if ejec git -C "$DIR" pull --ff-only; then
      paso 2 ok "$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
    else
      fallar 2 "git pull falló" "Hay cambios locales en $DIR. Descartalos con: git -C $DIR checkout -- ."
      return 1
    fi
  else
    fallar 2 "no es un repo git" "Reinstalá con: git clone ${ORIGEN%/main}"
    return 1
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
  if ! bash -n "$DIR/menu.sh" 2>>"$LOG"; then
    fallar 3 "menu.sh con errores" "La versión descargada no es válida. Restaurá el respaldo $SELLO."
    return 1
  fi
  paso 3 ok "sintaxis correcta"

  # El archivo VERSION viene EN el repo, así que el pull ya lo actualizó.
  # Antes lo escribía este script y, al estar versionado, el siguiente pull
  # chocaba con "local changes would be overwritten". Sólo se lee.
  paso 4 curso
  if [ -z "${DEMO:-}" ]; then
    VER_LOCAL="$(cat "$ARCH_VER" 2>/dev/null)"
    [ -z "$VER_LOCAL" ] && VER_LOCAL="$VER_REMOTA"
  else
    VER_LOCAL="$VER_REMOTA"
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
    sleep 2
    cursor_on
    exec bash "$DIR/menu.sh"
  fi
}

ver_cambios() {
  local f; f="$(
    echo; printf '%s\n' "$REGLA_FIJA"; echo
    encabezado "CAMBIOS DE LA VERSIÓN ${VER_REMOTA:-}" "publicada ${FECHA_REM:-—}"
    echo
    local n
    for n in "${NOVEDADES[@]}"; do
      printf '  %s•%s %s%s%s\n' "$E_P1" "$E_RST" "$E_TXT" "$(pad "$n" 74)" "$E_RST"
    done
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

# Una sola función para toda tecla, venga del read principal o del vaciado.
# Si el vaciado no tratara el ENTER, al teclear "01" y confirmar rápido la
# confirmación se perdería y no pasaría nada.
procesar() {
  case "$1" in
    "")
      case "$BUF" in
        1|01) [ "$ESTADO" = "disponible" ] && { ESTADO="instalando"; render; actualizar; } ;;
        2|02) [ ${#NOVEDADES[@]} -gt 0 ] && ver_cambios ;;
        0|00) exit 0 ;;
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