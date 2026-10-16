#!/bin/bash
# =============================================================================
#  KIRA · módulo 07 · ACTUALIZAR SCRIPT
#  Uso:  bash modules/update.sh
#        DEMO=1 bash modules/update.sh     (sin red, para ver el diseño)
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/lib/ui.sh"

# ============================================================== AJUSTES =====
ORIGEN="${KIRA_ORIGEN:-https://raw.githubusercontent.com/Loki-CC/kira/main}"
ARCH_VER="$DIR/VERSION"
RESPALDOS="$DIR/.respaldos"

VER_LOCAL="$(cat "$ARCH_VER" 2>/dev/null || echo "1.0")"
VER_REMOTA=""; FECHA_REM=""; TAM_REM=""; CANAL="estable"
NOVEDADES=()
ESTADO="revisando"   # revisando · al_dia · disponible · instalando · listo · error
MENSAJE=""
BUF=""
SELLO=""

PASOS=("Comprobar versión remota" "Respaldar la versión actual" "Descargar el paquete"
       "Verificar integridad"     "Instalar archivos"           "Reiniciar servicios")
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
  # Se lee con awk y no con jq: jq no viene instalado en la mayoría de los VPS
  VER_REMOTA=$(awk -F'"' '/"version"/{print $4; exit}' <<< "$meta")
  FECHA_REM=$(awk -F'"' '/"fecha"/{print $4; exit}'    <<< "$meta")
  TAM_REM=$(awk -F'"'  '/"tamano"/{print $4; exit}'    <<< "$meta")
  CANAL=$(awk -F'"'    '/"canal"/{print $4; exit}'     <<< "$meta")
  mapfile -t NOVEDADES < <(awk -F'"' '/"nota"/{print $4}' <<< "$meta")
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
    *)     g="○"; c="$E_OFF" ;;
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
  local tmp; tmp="$(mktemp -d)"
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
    rm -rf "$tmp"; return 1
  fi

  paso 2 curso
  if [ -n "${DEMO:-}" ]; then
    local p; for p in 12 31 48 66 84 100; do PCT[2]=$p; render; sleep 0.12; done
    paso 2 ok "412K"
  elif curl -fsS --max-time 60 -o "$tmp/kira.tgz" "$ORIGEN/kira-$VER_REMOTA.tgz" 2>/dev/null; then
    paso 2 ok "$(bytes_hum "$(stat -c%s "$tmp/kira.tgz" 2>/dev/null || echo 0)")"
  else
    fallar 2 "descarga fallida" "No se pudo descargar el paquete. El script quedó sin tocar."
    rm -rf "$tmp"; return 1
  fi

  paso 3 curso
  if [ -n "${DEMO:-}" ]; then
    sleep 0.4; paso 3 ok "sha256 correcto"
  else
    local esperado real
    esperado=$(curl -fsS --max-time 10 "$ORIGEN/kira-$VER_REMOTA.sha256" 2>/dev/null | awk '{print $1}')
    real=$(sha256sum "$tmp/kira.tgz" 2>/dev/null | awk '{print $1}')
    if [ -n "$esperado" ] && [ "$esperado" = "$real" ]; then
      paso 3 ok "sha256 correcto"
    else
      fallar 3 "suma no coincide" "El paquete no coincide con su firma. No se instaló nada."
      rm -rf "$tmp"; return 1
    fi
  fi

  paso 4 curso
  if [ -n "${DEMO:-}" ]; then
    local p; for p in 25 60 100; do PCT[4]=$p; render; sleep 0.15; done
    paso 4 ok "38 archivos"
  elif tar xzf "$tmp/kira.tgz" -C "$DIR" 2>/dev/null; then
    printf '%s\n' "$VER_REMOTA" > "$ARCH_VER"
    paso 4 ok "instalados"
  else
    fallar 4 "error al extraer" "Falló la instalación. Restaurá con el respaldo $SELLO."
    rm -rf "$tmp"; return 1
  fi

  paso 5 curso
  if [ -z "${DEMO:-}" ]; then
    systemctl daemon-reload 2>/dev/null; systemctl restart kira 2>/dev/null
  else sleep 0.4; fi
  paso 5 ok "al día"

  rm -rf "$tmp"
  VER_LOCAL="$VER_REMOTA"; ESTADO="listo"; render
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
trap 'cursor_on; printf "\e[?2026l\e[0m\n"' EXIT INT TERM
cursor_off
clear

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
