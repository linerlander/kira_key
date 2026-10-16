#!/bin/bash
# =============================================================================
#  KIRA · módulo 01 · CONTROL DE USUARIOS
#  Uso:  bash modules/user.sh
#        DEMO=1 bash modules/user.sh    (datos inventados, para ver el diseño)
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
  exit 1
fi
KIRA_DIR="$DIR"
source "$DIR/lib/ui.sh"

# lib/ui.sh crece con el tiempo. Si el módulo es nuevo y la librería vieja,
# bash tira "command not found" por cada llamada y la pantalla se inunda.
ui_exige() {
  local f faltan=""
  for f in "$@"; do declare -F "$f" >/dev/null 2>&1 || faltan="$faltan $f"; done
  [ -z "$faltan" ] && return 0
  printf '\e[1;38;2;255;95;109m✖ Tu lib/ui.sh está desactualizado\e[0m\n'
  printf '  Le faltan estas funciones:\e[1m%s\e[0m\n' "$faltan"
  printf '  Actualizalo con:  \e[1mcd %s && git pull\e[0m\n' "$KIRA_DIR"
  exit 1
}
ui_exige techo piso banda cabecera cachear_cabecera datos_sistema pad rpad

MOD="$DIR/modules"
BUF=""; MENSAJE=""; AVISO=""
UMBRAL_VENCE=7      # días para considerar que una cuenta "está por vencer"

# ================================================================ DATOS =====
# Se lee de /etc/shadow, que es la fuente real: campo 2 = contraseña (si
# empieza con ! la cuenta está bloqueada) y campo 8 = día de expiración,
# contado en días desde 1970.
TOTAL=0; ACTIVOS=0; POR_VENCER=0; VENCIDOS=0; BLOQUEADOS=0
EN_LINEA=0; SESIONES=0; EXCEDIDOS=0; ULTIMO="—"; CONSUMO="—"; SIN_ROOT=0

cargar_cuentas() {
  if [ -n "${DEMO:-}" ]; then
    TOTAL=42; ACTIVOS=38; POR_VENCER=3; VENCIDOS=1; BLOQUEADOS=1
    EN_LINEA=8; SESIONES=11; EXCEDIDOS=2; ULTIMO="juanperez · hace 2m"
    CONSUMO="4.2G este mes"
    return
  fi

  TOTAL=0; ACTIVOS=0; POR_VENCER=0; VENCIDOS=0; BLOQUEADOS=0
  if [ ! -r /etc/shadow ]; then
    SIN_ROOT=1
  else
    SIN_ROOT=0
    local hoy; hoy=$(( $(date +%s) / 86400 ))
    # Un solo recorrido de passwd + shadow. Antes era un grep y dos cut POR
    # usuario: con 40 cuentas eran ~120 subshells cada vez que refresca.
    # `read < <(...)` corre el read en ESTA shell, así que los valores quedan;
    # con `VAR=$(...)` se perderían al cerrar el subshell.
    #   campo 2 de shadow = clave   · empieza con ! -> bloqueada
    #                               · empieza con * o vacía -> sin clave, no se vende
    #   campo 8 de shadow = día de vencimiento, contado desde 1970
    read -r TOTAL ACTIVOS POR_VENCER VENCIDOS BLOQUEADOS < <(
      awk -F: -v hoy="$hoy" -v lim="$UMBRAL_VENCE" '
        NR==FNR { if ($3>=1000 && $1!="nobody" && $1!="nogroup") usr[$1]=1; next }
        # OJO: la fecha NO puede llamarse exp. exp() es una función de awk y
        # usarla como variable es error de sintaxis, que con 2>/dev/null se
        # traga en silencio y deja todos los contadores en cero.
        ($1 in usr) {
          clave=$2; vto=$8
          if (clave == "" || clave ~ /^\*/) next
          tot++
          if (clave ~ /^!/) { bloq++; next }
          if (vto ~ /^[0-9]+$/) {
            if (vto < hoy)        { venc++; next }
            if (vto - hoy <= lim) { pov++ }
          }
          act++
        }
        END { printf "%d %d %d %d %d", tot+0, act+0, pov+0, venc+0, bloq+0 }
      ' /etc/passwd /etc/shadow 2>/dev/null
    )
    : "${TOTAL:=0}" "${ACTIVOS:=0}" "${POR_VENCER:=0}" "${VENCIDOS:=0}" "${BLOQUEADOS:=0}"
  fi

  # Conectados: una sesión por proceso de sshd/dropbear con usuario asignado
  mapfile -t SES < <(who 2>/dev/null | awk '{print $1}')
  SESIONES=${#SES[@]}
  EN_LINEA=$(printf '%s\n' "${SES[@]}" | sort -u | grep -c . 2>/dev/null)
  [ -z "$EN_LINEA" ] && EN_LINEA=0

  # Quién pasa su límite de sesiones: necesita el límite por usuario, que
  # guarda el módulo de multilogin. Si no existe, no se puede saber.
  EXCEDIDOS=0
  if [ -r "$DIR/db/limites" ]; then
    local lu ll n
    while IFS=' ' read -r lu ll; do
      [ -z "$lu" ] && continue
      n=$(printf '%s\n' "${SES[@]}" | grep -cx "$lu")
      (( n > ll )) && EXCEDIDOS=$((EXCEDIDOS+1))
    done < "$DIR/db/limites"
  fi

  ULTIMO=$(last -n 1 -F 2>/dev/null | awk 'NR==1 && $1!="" {print $1}')
  [ -z "$ULTIMO" ] && ULTIMO="—"

  CONSUMO="—"
  [ -r "$DIR/db/consumo" ] && CONSUMO=$(awk '{s+=$2} END{printf "%.1fG este mes", s/1073741824}' "$DIR/db/consumo" 2>/dev/null)
}

# ============================================================== PANTALLA ====
# El contenido entre bordes mide SIEMPRE 35:
#   izquierda  1 + etiqueta 12 + valor 7 + nota 15 = 35
#   derecha    1 + etiqueta 12 + valor 22          = 35
fila_izq() { caja_izq " $E_MUT$(pad "$1" 12)$E_RST$2$(pad "$3" 7)$E_RST$E_MUT$(pad "${4:-}" 15)$E_RST" "$M_CTA"; }
fila_der() { caja_der " $E_MUT$(pad "$1" 12)$E_RST$2$(pad "$3" 22)$E_RST" "$M_ACT"; }

M_CTA=$'\e[38;2;22;92;110m'      # marco cian apagado
M_ACT=$'\e[38;2;74;64;130m'      # marco violeta apagado

paneles() {
  local c_vence="$E_TXT" c_venc="$E_TXT" c_bloq="$E_TXT"
  (( POR_VENCER > 0 )) && c_vence="$E_BLD$E_WARN"
  (( VENCIDOS   > 0 )) && c_venc="$E_BLD$E_ERR"
  (( BLOQUEADOS > 0 )) && c_bloq="$E_BLD$E_ERR"
  local c_exc="$E_TXT"; (( EXCEDIDOS > 0 )) && c_exc="$E_BLD$E_WARN"

  techo "CUENTAS" "$E_P1" "ACTIVIDAD" "$E_P2" "$M_CTA" "$M_ACT"
  fila_izq "TOTAL"      "$E_BLD$E_TXT" "$TOTAL"      ""                        ; fila_der "EN LÍNEA"   "$E_BLD$E_OK"  "$EN_LINEA"
  fila_izq "ACTIVOS"    "$E_BLD$E_OK"  "$ACTIVOS"    ""                        ; fila_der "SESIONES"   "$E_TXT"       "$SESIONES"
  fila_izq "POR VENCER" "$c_vence"     "$POR_VENCER" "en $UMBRAL_VENCE días"   ; fila_der "MULTILOGIN" "$c_exc"       "$(excedidos_txt)"
  fila_izq "VENCIDOS"   "$c_venc"      "$VENCIDOS"   ""                        ; fila_der "ÚLTIMO"     "$E_INFO"      "$ULTIMO"
  fila_izq "BLOQUEADOS" "$c_bloq"      "$BLOQUEADOS" ""                        ; fila_der "CONSUMO"    "$E_TXT"       "$CONSUMO"
  piso "$M_CTA" "$M_ACT"
}
plural() { (( $1 == 1 )) && printf '%s' "$2" || printf '%s' "$3"; }
excedidos_txt() {
  (( EXCEDIDOS > 0 )) && printf '%s %s' "$EXCEDIDOS" "$(plural "$EXCEDIDOS" excedido excedidos)" \
                      || printf 'sin excesos'
}

# Dos columnas. Cada celda = nn 2 + sp + emoji 2 + sp + texto 31 = 37
# Fila = 2 de margen + 37 + 2 de separación + 37 = 78
OPC=(
  "01|👥|AGREGAR USUARIO"        "08|🔒|BLOQUEAR USUARIO"
  "02|🧹|BORRAR USUARIO(S)"      "09|💾|BACKUP DE USUARIOS"
  "03|🔄|EDITAR / RENOVAR"       "10|🔗|MENÚ SSR / SS"
  "04|📋|USUARIOS REGISTRADOS"   "11|🤖|BOT DE TELEGRAM"
  "05|📡|USUARIOS CONECTADOS"    "12|🔍|VERIFICADOR"
  "06|📢|BANNER SSH"             "13|📄|CHECKUSER"
  "07|📊|LOG DE CONSUMO"         "14|🚦|CONTROL MULTILOGIN"
)
celda() { # $1="nn|emoji|texto"
  local n e t sel
  IFS='|' read -r n e t <<< "$1"
  if [ -n "$BUF" ] && { [ "$BUF" = "$n" ] || [ "$BUF" = "${n#0}" ]; }; then
    printf '%s%s%s %s%s%s %s%s%s' "$B_SEL$E_BLD$E_P1" "$n" "$E_RST$B_SEL" \
           "$E_P2" "$e" "$E_RST$B_SEL" "$E_BLD$E_TXT" "$(pad "$t" 31)" "$E_RST"
  else
    printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$n" "$E_RST" \
           "$E_P2" "$e" "$E_RST" "$E_TXT" "$(pad "$t" 31)" "$E_RST"
  fi
}
opciones() {
  local i
  for ((i=0; i<${#OPC[@]}; i+=2)); do
    printf '  %s  %s\n' "$(celda "${OPC[i]}")" "$(celda "${OPC[i+1]}")"
  done
}

pie() {
  printf '  %s%s%s  %s%s%s  %s%s%s\n' \
    "$E_BLD$E_ERR" "00" "$E_RST" "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad 'VOLVER AL MENÚ PRINCIPAL' 68)" "$E_RST"
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

# Renglón reservado para avisos. Queda en blanco cuando no hay nada que decir
# — no se borra la línea, porque si apareciera y desapareciera el bloque de
# abajo saltaría una fila y la pantalla se vería brincar.
linea_aviso() {
  if [ -n "$AVISO" ]; then
    printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  elif (( SIN_ROOT )); then
    printf '  %s%s%s\n' "$E_BLD$E_WARN" "$(pad "▸ Entrá como root para ver el estado real de las cuentas" 76)" "$E_RST"
  else
    printf '  %s\n' "$(pad '' 76)"
  fi
}

pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "CONTROL DE USUARIOS" "KIRA v$KIRA_VER"
  echo
  paneles
  echo
  seccion "OPERACIONES" "$E_P2"
  echo
  opciones
  echo
  linea_aviso
  echo
  pie
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# =============================================================== ACCIONES ===
abrir() { # $1=archivo $2=nombre
  if [ -f "$MOD/$1" ]; then
    cursor_on; clear
    bash "$MOD/$1"
    clear; cursor_off
    cargar_cuentas
    AVISO=""
  else
    AVISO="$2 no está instalado · falta modules/$1"
  fi
}

ejecutar() {
  AVISO=""          # cada elección arranca limpia: el aviso anterior ya no aplica
  case "$1" in
    1|01)  abrir user_add.sh     "Agregar usuario" ;;
    2|02)  abrir user_clear.sh   "Borrar usuarios" ;;
    3|03)  abrir user_edit.sh    "Editar / renovar" ;;
    4|04)  abrir user_list.sh    "Usuarios registrados" ;;
    5|05)  abrir user_online.sh  "Usuarios conectados" ;;
    6|06)  abrir ssh_banner.sh   "Banner SSH" ;;
    7|07)  abrir user_log.sh     "Log de consumo" ;;
    8|08)  abrir user_lock.sh    "Bloquear usuario" ;;
    9|09)  abrir user_backup.sh  "Backup de usuarios" ;;
    10)    abrir ssr.sh          "Menú SSR / SS" ;;
    11)    abrir bot_telegram.sh "Bot de Telegram" ;;
    12)    abrir user_check.sh   "Verificador" ;;
    13)    abrir checkuser.sh    "Checkuser" ;;
    14)    abrir user_libre.sh   "Control multilogin" ;;
    0|00)  clear; exit 0 ;;
    "")    return ;;
    *)     AVISO="Opción $1 inválida" ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    [0-9])         [ ${#BUF} -lt 2 ] && BUF="$BUF$1" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;
  esac
}

# ================================================================= MAIN =====
exigir_ancho
datos_sistema
cachear_cabecera
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear' EXIT
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear; exit 130' INT TERM
cursor_off
clear

cargar_cuentas
SEG_ANT=-1

while true; do
  # Las cuentas se releen cada 5s: cambian poco y leer /etc/shadow entero
  # en cada vuelta es gasto al pedo.
  printf -v ahora '%(%s)T' -1
  if (( ahora - SEG_ANT >= 5 )); then cargar_cuentas; SEG_ANT=$ahora; fi
  render
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done