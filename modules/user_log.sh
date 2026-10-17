#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.07 · LOG DE CONSUMO
#  Cuánto gastó cada cliente: hoy, este mes y desde siempre. Los números los
#  junta el servicio kira-consumo; acá sólo se leen y se muestran.
#  Uso:  bash modules/user_log.sh
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
  exit 1
fi
KIRA_DIR="$DIR"
source "$DIR/lib/ui.sh"

ui_exige() {
  local f faltan=""
  for f in "$@"; do declare -F "$f" >/dev/null 2>&1 || faltan="$faltan $f"; done
  [ -z "$faltan" ] && return 0
  printf '\e[1;38;2;255;95;109m✖ Tu lib/ui.sh está desactualizado\e[0m\n'
  printf '  Le faltan estas funciones:\e[1m%s\e[0m\n' "$faltan"
  printf '  Actualizalo con:  \e[1mcd %s && git pull\e[0m\n' "$KIRA_DIR"
  exit 1
}
ui_exige banda cabecera cachear_cabecera datos_sistema seccion encabezado pad rpad \
         volcar rep bytes_hum barra_fija

# ================================================================ ESTADO ====
POR_PAGINA=10
PAGINA=0
PANTALLA=lista            # lista · confirmar
ACCION=""
VISTA=mes                 # mes · hoy · total · por cuál se ordena y se reparte
SOLO_CON_GASTO=1
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0; CARGA_ANT=0
ESTADO_CONT="sin instalar"
TRAFICO_VPS=0

CADENA="KIRA_CONSUMO"
ARCHIVO="$DIR/db/consumo"
CONTADOR="$DIR/kira-consumo"

declare -a C_NOM=() C_HOY=() C_MES=() C_TOT=()
declare -a V_IDX=()

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
# El servicio anota cada veinte segundos. Entre una anotación y la siguiente,
# los bytes nuevos están en el contador vivo de iptables, así que acá se suma
# lo guardado MÁS lo que todavía no se anotó. Si no, la pantalla se quedaría
# clavada veinte segundos y parecería rota.
leer_vivos() { # deja en VIVO[uid] los bytes del contador de ahora
  VIVO=()
  local uid bytes
  while read -r uid bytes; do
    [[ "$uid" =~ ^[0-9]+$ ]] && VIVO[$uid]="$bytes"
  done < <(iptables -L "$CADENA" -vxn 2>/dev/null | awk '
    /owner UID match/ {
      uid = ""
      for (i = 1; i <= NF; i++) if ($i == "match" && $(i-1) == "UID") uid = $(i+1)
      if (uid != "") print uid, $2
    }')
}

estado_contador() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet kira-consumo 2>/dev/null; then
    ESTADO_CONT="activo"
  elif iptables -nL "$CADENA" >/dev/null 2>&1; then
    ESTADO_CONT="parado"
  else
    ESTADO_CONT="sin instalar"
  fi
}

# Lo que movió la VPS entera desde que arrancó. Sirve de referencia: si la
# suma de los clientes es mucho menor, el resto se lo llevó otra cosa.
trafico_vps() {
  local t=0 n rx tx
  for n in /sys/class/net/*; do
    [ "${n##*/}" = "lo" ] && continue
    [ -r "$n/statistics/tx_bytes" ] || continue
    read -r rx < "$n/statistics/rx_bytes" 2>/dev/null || continue
    read -r tx < "$n/statistics/tx_bytes" 2>/dev/null || continue
    t=$(( t + rx + tx ))
  done
  TRAFICO_VPS=$t
}

declare -A VIVO=()
cargar() {
  C_NOM=(); C_HOY=(); C_MES=(); C_TOT=()
  estado_contador
  trafico_vps
  leer_vivos

  declare -A UID_DE=()
  local n uid resto
  while IFS=: read -r n resto uid resto; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid != 65534 )) || continue
    UID_DE[$n]="$uid"
  done < /etc/passwd

  local t m mi h di ul extra
  if [ -r "$ARCHIVO" ]; then
    while read -r n t m mi h di ul; do
      [ -n "$n" ] || continue
      [ -n "${UID_DE[$n]:-}" ] || continue      # cuenta borrada: ya no se lista
      uid="${UID_DE[$n]}"
      # Lo que el contador lleva de más desde la última anotación
      extra=0
      if [ -n "${VIVO[$uid]:-}" ]; then
        if (( VIVO[$uid] >= ${ul:-0} )); then extra=$(( VIVO[$uid] - ${ul:-0} ))
        else extra=${VIVO[$uid]}; fi
      fi
      C_NOM+=("$n")
      C_TOT+=($(( ${t:-0} + extra )))
      C_MES+=($(( ${m:-0} + extra )))
      C_HOY+=($(( ${h:-0} + extra )))
    done < "$ARCHIVO"
  fi
  ordenar
}

valor_de() { # $1=índice · el número por el que se ordena y se reparte
  case "$VISTA" in
    hoy)   printf '%s' "${C_HOY[$1]}" ;;
    total) printf '%s' "${C_TOT[$1]}" ;;
    *)     printf '%s' "${C_MES[$1]}" ;;
  esac
}

TOTAL_VISTA=0
ordenar() {
  V_IDX=(); TOTAL_VISTA=0
  local i v linea
  for i in "${!C_NOM[@]}"; do
    v="$(valor_de "$i")"
    (( TOTAL_VISTA += v ))
    if (( SOLO_CON_GASTO )) && (( v == 0 )); then continue; fi
    V_IDX+=("$i")
  done
  # De mayor a menor: el que más gasta queda arriba, que es a quien mirás.
  local -a orden=()
  while read -r linea; do [ -n "$linea" ] && orden+=("${linea#* }"); done < <(
    for i in "${V_IDX[@]}"; do printf '%s %s\n' "$(valor_de "$i")" "$i"; done | sort -rn
  )
  V_IDX=("${orden[@]}")
  local tope=$(( (${#V_IDX[@]} + POR_PAGINA - 1) / POR_PAGINA ))
  (( tope == 0 )) && tope=1
  (( PAGINA >= tope )) && PAGINA=$(( tope - 1 ))
}

paginas() { local n=${#V_IDX[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

# ====================================================== MARCO A LO ANCHO ===
techo_ancho() { # $1=título, centrado en el borde de arriba
  local t=" $1 " hueco izq der
  (( ${#t} > 72 )) && t="${t:0:72}"
  hueco=$(( 74 - ${#t} ))
  izq=$(( hueco / 2 )); der=$(( hueco - izq ))
  printf '  %s╭%s%s%s%s%s%s%s╮%s\n' "$M_TABLA" "$(rep '─' "$izq")" \
    "$E_RST$B_CHIP$E_BLD$E_PINK" "$t" "$E_RST$M_TABLA" "$(rep '─' "$der")" \
    "" "$M_TABLA" "$E_RST"
}
fila_ancha() { printf '  %s│%s%s%s│%s\n' "$M_TABLA" "$E_RST" "$1" "$M_TABLA" "$E_RST"; }
piso_ancho() { printf '  %s╰%s╯%s\n' "$M_TABLA" "$(rep '─' 74)" "$E_RST"; }

opcion() { # $1=número $2=emoji $3=texto
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
opcion_off() {
  printf '%s%s%s %s%s%s %s%s%s' "$E_MUT" "$(pad "$1" 2)" "$E_RST" \
         "$E_MUT" "$2" "$E_RST" "$E_MUT" "$(pad "$3" 31)" "$E_RST"
}
# La vista elegida va en rosa, igual que en el padrón.
opcion_v() { # $1=número $2=emoji $3=texto $4=clave
  local c="$E_BLD$E_TXT"
  [ "$VISTA" = "$4" ] && c="$E_BLD$E_PINK"
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$c" "$(pad "$3" 31)" "$E_RST"
}
opcion_salir() {
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_ERR" "$(pad '00' 2)" "$E_RST" "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad "${1:-VOLVER AL PANEL}" 70)" "$E_RST"
}
linea_aviso() {
  if   [ -n "$AVISO" ];   then printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  elif [ -n "$MENSAJE" ]; then printf '  %s%s%s\n' "$E_BLD$E_OK"  "$(pad "✔ $MENSAJE" 76)" "$E_RST"
  else printf '  %s\n' "$(pad '' 76)"; fi
}
prompt() {
  local et="${1:-Opción:}" vis
  vis=$(( 4 + ${#et} + 1 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%s%s%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$et" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

# =============================================================== PANTALLA ===
# Fila de 74: 1 + nº 2 + 2 + usuario 16 + 2 + hoy 9 + 2 + mes 9 + 2 + total 9
#             + 2 + reparto 17 + 1
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'USUARIO' 16)" "$(rpad 'HOY' 9)" \
    "$(rpad 'ESTE MES' 9)" "$(rpad 'TOTAL' 9)" "$(pad 'REPARTO' 17)" "$E_RST")"
}
fila_consumo() { # $1=número a mostrar $2=índice
  local n="$1" i="$2" v pct barra ch cm
  v="$(valor_de "$i")"
  pct=0
  (( TOTAL_VISTA > 0 )) && pct=$(( v * 100 / TOTAL_VISTA ))
  # La barra dice qué parte del gasto se lleva ESTE usuario. Un solo color:
  # acá el color no significa peligro, sólo cuánto del total es suyo.
  #
  # Con 0% no se dibuja la barra vacía: once caracteres de relleno en cada
  # fila sin consumo arman un bloque oscuro que no dice nada y le gana la
  # vista a las barras que sí importan.
  if (( pct > 0 )); then barra="$(barra_fija "$pct" 11 "$E_P1")"
  else                   barra="$(pad '' 11)"; fi
  ch="$E_MUT"; (( ${C_HOY[i]} > 0 )) && ch="$E_BLD$E_OK"
  cm="$E_TXT"; (( ${C_MES[i]} > 0 )) && cm="$E_BLD$E_TXT"
  fila_ancha "$(printf ' %s%s%s  %s%s%s  %s%s  %s%s  %s%s%s  %s %s%s%s ' \
    "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST" \
    "$E_TXT" "$(pad "${C_NOM[i]}" 16)" "$E_RST" \
    "$ch" "$(rpad "$(bytes_hum "${C_HOY[i]}")" 9)" \
    "$cm" "$(rpad "$(bytes_hum "${C_MES[i]}")" 9)" \
    "$E_MUT" "$(rpad "$(bytes_hum "${C_TOT[i]}")" 9)" "$E_RST" \
    "$barra" "$E_MUT" "$(rpad "$pct%" 5)" "$E_RST")"
}

indicador_paginas() { # $1=páginas $2=desde $3=hasta $4=total
  local pags="$1" desde="$2" fin="$3" total="$4"
  local puntos="" i vis=0
  if (( pags > 1 && pags <= 24 )); then
    for ((i=0; i<pags; i++)); do
      if (( i == PAGINA )); then puntos="$puntos$E_BLD$E_P1●$E_RST"
      else                       puntos="$puntos$E_MUT○$E_RST"; fi
    done
    vis=$(( pags + 3 ))
  fi
  local medio
  if (( total == 0 )); then medio=""
  else medio="mostrando $(( desde + 1 ))-$fin de $total"; fi
  vis=$(( vis + ${#medio} ))
  local izq=$(( (74 - vis) / 2 )); (( izq < 1 )) && izq=1
  local der=$(( 74 - izq - vis )); (( der < 0 )) && der=0
  if (( vis > ${#medio} )); then
    fila_ancha "$(printf '%*s%s   %s%s%s%*s' "$izq" '' "$puntos" "$E_MUT" "$medio" "$E_RST" "$der" '')"
  else
    fila_ancha "$(printf '%*s%s%s%s%*s' "$izq" '' "$E_MUT" "$medio" "$E_RST" "$der" '')"
  fi
}

titulo_tabla() {
  local q
  case "$VISTA" in
    hoy)   q="HOY" ;;
    total) q="DESDE SIEMPRE" ;;
    *)     q="ESTE MES" ;;
  esac
  printf '%s · %s ENTRE %s CUENTAS' "$q" "$(bytes_hum "$TOTAL_VISTA")" "${#V_IDX[@]}"
}

pintar_lista() {
  local total=${#V_IDX[@]} pags; pags=$(paginas)
  local i desde fin
  desde=$(( PAGINA * POR_PAGINA ))
  fin=$(( desde + POR_PAGINA ))
  (( fin > total )) && fin=$total

  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "LOG DE CONSUMO" "KIRA v$KIRA_VER"
  echo
  techo_ancho "$(titulo_tabla)"
  cab_tabla
  if (( total == 0 )); then
    if [ "$ESTADO_CONT" = "sin instalar" ]; then
      fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'La contabilidad todavía no está puesta · opción 01' 72)")"
    else
      fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'Nadie consumió nada todavía en este período.' 72)")"
    fi
    for ((i=1; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  else
    for ((i=desde; i<fin; i++)); do fila_consumo $(( i + 1 )) "${V_IDX[i]}"; done
    for ((i=fin-desde; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  fi
  indicador_paginas "$pags" "$desde" "$fin" "$total"
  piso_ancho
  echo
  linea_estado
  echo
  seccion "QUÉ MIRAR" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion_v '01' '📅' 'ESTE MES' mes)"   "$(opcion_v '02' '🌞' 'HOY' hoy)"
  printf '  %s  %s\n' "$(opcion_v '03' '📈' 'DESDE SIEMPRE' total)" "$(opcion_filtro)"
  printf '  %s  %s\n' "$(opcion '77' '⏪' 'PÁGINA ANTERIOR')"   "$(opcion '88' '⏩' 'PÁGINA SIGUIENTE')"
  if [ "$ESTADO_CONT" = "activo" ]; then
    printf '  %s  %s\n' "$(opcion_off '05' '🔧' 'CONTABILIDAD ACTIVA')" "$(opcion '09' '🧹' 'BORRAR LO ANOTADO')"
  else
    printf '  %s  %s\n' "$(opcion '05' '🔧' 'ACTIVAR LA CONTABILIDAD')" "$(opcion '09' '🧹' 'BORRAR LO ANOTADO')"
  fi
  opcion_salir
  echo
  linea_aviso
  prompt "Opción:"
}

opcion_filtro() {
  if (( SOLO_CON_GASTO )); then
    printf '%s' "$(opcion '04' '🔎' 'VER TAMBIÉN LAS DE CERO')"
  else
    printf '%s' "$(opcion '04' '🔎' 'SÓLO LAS QUE GASTARON')"
  fi
}

# Una línea que dice de dónde salen los números y qué miden, porque un total
# sin saber qué incluye no sirve para cobrarle a nadie.
linea_estado() {
  local c t
  case "$ESTADO_CONT" in
    activo) c="$E_OK";   t="✔ Contabilidad activa · mide la BAJADA de cada cliente" ;;
    parado) c="$E_WARN"; t="▸ Las reglas están puestas pero el servicio no corre · opción 05" ;;
    *)      c="$E_MUT";  t="▸ Sin contabilidad puesta: todavía no se está midiendo nada" ;;
  esac
  printf '  %s%s%s\n' "$E_BLD$c" "$(pad "$t" 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad "  La VPS movió $(bytes_hum "$TRAFICO_VPS") desde que arrancó, contando todo." 76)" "$E_RST"
}

pintar_confirmar() {
  local t1 t2 bot
  case "$ACCION" in
    borrar)
      t1="Se borra todo lo anotado: hoy, el mes y el total de cada cuenta."
      t2="Los contadores arrancan de cero. No afecta a ningún cliente."
      bot="SÍ, BORRAR TODO" ;;
    instalar)
      t1="Se van a poner reglas de conteo en el cortafuegos, una por cliente."
      t2="No bloquean nada: sólo cuentan y dejan pasar. Se puede sacar después."
      bot="SÍ, ACTIVARLA" ;;
  esac
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "LOG DE CONSUMO" "KIRA v$KIRA_VER"
  echo
  seccion "CONFIRMÁ" "$E_ERR"
  echo
  printf '  %s%s%s\n' "$E_BLD$E_TXT" "$(pad "$t1" 76)" "$E_RST"
  echo
  printf '  %s%s%s\n' "$E_MUT" "$(pad "$t2" 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '01' '✅' "$bot")" "$(pad '' 37)"
  opcion_salir "NO, VOLVER"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar() {
  case "$PANTALLA" in
    confirmar) pintar_confirmar ;;
    *)         pintar_lista ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# =============================================================== ACCIONES ===
activar_contabilidad() {
  if [ ! -f "$CONTADOR" ]; then
    AVISO="Falta el archivo kira-consumo en la carpeta del panel"
    return 1
  fi
  KIRA_DIR="$DIR" bash "$CONTADOR" --instalar >/tmp/kira-consumo.log 2>&1
  KIRA_DIR="$DIR" bash "$CONTADOR" --una-vez >/dev/null 2>&1
  estado_contador
  if [ "$ESTADO_CONT" = "activo" ]; then return 0; fi
  AVISO="No quedó activa · mirá /tmp/kira-consumo.log"
  return 1
}

borrar_anotado() {
  rm -f "$ARCHIVO"
  # También se ponen a cero los contadores vivos: si no, en la pasada
  # siguiente el servicio vería un contador grande contra un registro vacío
  # y lo sumaría entero de golpe.
  iptables -Z "$CADENA" 2>/dev/null
  [ -f "$CONTADOR" ] && KIRA_DIR="$DIR" bash "$CONTADOR" --una-vez >/dev/null 2>&1
  cargar
  return 0
}

ejecutar() {
  local entrada="$1"
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    lista)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        1|01) VISTA=mes;   PAGINA=0; ordenar ;;
        2|02) VISTA=hoy;   PAGINA=0; ordenar ;;
        3|03) VISTA=total; PAGINA=0; ordenar ;;
        4|04) SOLO_CON_GASTO=$(( ! SOLO_CON_GASTO )); PAGINA=0; ordenar ;;
        5|05)
          if [ "$ESTADO_CONT" = "activo" ]; then AVISO="La contabilidad ya está activa"
          else ACCION=instalar; PANTALLA=confirmar; fi ;;
        9|09)
          if [ ! -r "$ARCHIVO" ]; then AVISO="No hay nada anotado todavía"
          else ACCION=borrar; PANTALLA=confirmar; fi ;;
        77) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        88) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        *)  AVISO="Elegí una opción de la lista" ;;
      esac ;;
    confirmar)
      case "$entrada" in
        1|01)
          case "$ACCION" in
            instalar) activar_contabilidad && MENSAJE="Contabilidad activa · ya está midiendo" ;;
            borrar)   borrar_anotado && MENSAJE="Listo · los contadores arrancan de cero" ;;
          esac
          [ -z "$AVISO" ] && PANTALLA=lista ;;
        ""|0|00) PANTALLA=lista ;;
        *)       AVISO="Elegí 01 para seguir o 00 para volver" ;;
      esac ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    [0-9])         (( ${#BUF} < 4 )) && BUF="$BUF$1" ;;
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
cargar

while true; do
  printf -v ahora '%(%s)T' -1
  redibujar=0
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; redibujar=1; fi
  # Cada 3 segundos se releen los contadores. Leer iptables cuesta un proceso,
  # así que no se hace en cada vuelta del teclado.
  if [ "$PANTALLA" = lista ] && (( ahora - CARGA_ANT >= 3 )); then
    cargar; CARGA_ANT=$ahora; redibujar=1
  fi
  (( redibujar )) && render
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done