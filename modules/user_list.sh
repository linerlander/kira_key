#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.04 · USUARIOS REGISTRADOS
#  El padrón completo: todas las cuentas que existen en la VPS, con filtros y
#  buscador. No toca nada — sólo mira. Para cambiar algo están los módulos
#  01, 02 y 03.
#  Uso:  bash modules/user_list.sh
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
ui_exige banda cabecera cachear_cabecera datos_sistema seccion encabezado pad rpad volcar rep

# ================================================================ ESTADO ====
POR_PAGINA=10
PAGINA=0
FILTRO=todas              # todas · activas · pronto · vencidas · bloqueadas · enlinea
BUSCA=""
PANTALLA=lista            # lista · buscar
AVISO=""
UMBRAL_VENCE=7
SIN_ROOT=0
BUF=""; SEG_ANT=0; CARGA_ANT=0

declare -a T_NOM=() T_VENCE=() T_VTO=() T_CONEX=() T_ESTADO=() T_LIMITE=()
declare -a V_IDX=()       # los índices que pasan el filtro y la búsqueda
declare -A CON_USR=() NOM_DE_UID=()

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
# Conexiones por DUEÑO del proceso. El por qué está explicado en user.sh:
# `who` lee utmp y un túnel de HTTP Injector entra sin terminal, así que ahí
# no figura.
cargar_conexiones() {
  CON_USR=()
  local p c k v u
  for p in /proc/[0-9]*; do
    [ -r "$p/comm" ] || continue
    read -r c < "$p/comm" 2>/dev/null || continue
    case "$c" in
      sshd|sshd-session|sshd-auth|dropbear|dropbearmulti) ;;
      *) continue ;;
    esac
    v=""
    while read -r k v _; do [ "$k" = "Uid:" ] && break; done < "$p/status" 2>/dev/null
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    u="${NOM_DE_UID[$v]:-}"
    [ -n "$u" ] && (( CON_USR[$u]++ ))
  done
}

cargar_cuentas() {
  T_NOM=(); T_VENCE=(); T_VTO=(); T_CONEX=(); T_ESTADO=(); T_LIMITE=(); NOM_DE_UID=()
  declare -A ES_CLIENTE=() LIM=() ES_DEMO=()

  # Clientes = UID >= 1000. root y las cuentas de sistema no se venden.
  local n uid resto
  while IFS=: read -r n resto uid resto; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid != 65534 )) || continue
    NOM_DE_UID[$uid]="$n"; ES_CLIENTE[$n]=1
  done < /etc/passwd

  cargar_conexiones

  local lu ll
  if [ -r "$DIR/db/limites" ]; then
    while read -r lu ll; do
      [ -n "$lu" ] && [[ "$ll" =~ ^[0-9]+$ ]] && LIM[$lu]="$ll"
    done < "$DIR/db/limites"
  fi
  local du dt
  if [ -r "$DIR/db/demos" ]; then
    while read -r du dt; do [ -n "$du" ] && ES_DEMO[$du]=1; done < "$DIR/db/demos"
  fi

  if [ ! -r /etc/shadow ]; then SIN_ROOT=1; aplicar_filtro; return; fi
  SIN_ROOT=0

  # Campo 2 de shadow = clave (! bloqueada, * o vacía = sin clave).
  # Campo 8 = día de vencimiento, contado en días desde 1970.
  local hoy; hoy=$(( $(date +%s) / 86400 ))
  local nom clave c3 c4 c5 c6 c7 vto est dias fecha epoca
  while IFS=: read -r nom clave c3 c4 c5 c6 c7 vto resto; do
    [ -n "${ES_CLIENTE[$nom]:-}" ] || continue
    if [[ "$vto" =~ ^[0-9]+$ ]]; then
      epoca=$(( vto * 86400 ))
      fecha=$(date -u -d "@$epoca" '+%d/%m/%Y' 2>/dev/null)
      dias=$(( vto - hoy ))
    else
      epoca=0; fecha="sin fecha"; dias=99999
    fi
    # Un "!" solo (o "!!") es una cuenta que NUNCA tuvo clave: no está
    # bloqueada, está sin estrenar. Bloqueada es la que tenía clave y se le
    # puso el "!" adelante. Son dos cosas distintas y conviene distinguirlas.
    case "$clave" in
      '!'|'!!'|'*'|'') est="sin clave" ;;
      '!'*)            est="bloqueada" ;;
      *)
        if   [ -n "${ES_DEMO[$nom]:-}" ]; then est="prueba"
        elif (( dias == 99999 ));         then est="sin tope"
        elif (( dias < 0 ));              then est="vencida"
        elif (( dias <= UMBRAL_VENCE ));  then est="pronto"
        else                                   est="activa"; fi ;;
    esac
    T_NOM+=("$nom"); T_VENCE+=("$fecha"); T_VTO+=("$epoca")
    T_CONEX+=("${CON_USR[$nom]:-0}"); T_ESTADO+=("$est"); T_LIMITE+=("${LIM[$nom]:-}")
  done < /etc/shadow
  aplicar_filtro
}

# Qué cuentas se ven, según el filtro puesto y lo que se haya buscado.
aplicar_filtro() {
  V_IDX=()
  local i e n
  for i in "${!T_NOM[@]}"; do
    e="${T_ESTADO[i]}"; n="${T_NOM[i]}"
    case "$FILTRO" in
      activas)    [ "$e" = activa ] || [ "$e" = "sin tope" ] || [ "$e" = prueba ] || continue ;;
      pronto)     [ "$e" = pronto ] || continue ;;
      vencidas)   [ "$e" = vencida ] || continue ;;
      bloqueadas) [ "$e" = bloqueada ] || [ "$e" = "sin clave" ] || continue ;;
      enlinea)    (( ${T_CONEX[i]:-0} > 0 )) || continue ;;
    esac
    if [ -n "$BUSCA" ]; then
      case "${n,,}" in *"${BUSCA,,}"*) ;; *) continue ;; esac
    fi
    V_IDX+=("$i")
  done
  local tope=$(( (${#V_IDX[@]} + POR_PAGINA - 1) / POR_PAGINA ))
  (( tope == 0 )) && tope=1
  (( PAGINA >= tope )) && PAGINA=$(( tope - 1 ))
}

paginas() { local n=${#V_IDX[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

# Cuánto le queda. Misma forma que en el módulo de borrar: con más de dos días
# se muestran los días, porque todas las cuentas vencen en el MISMO instante
# (00:00 UTC) y repetir el mismo reloj en cada fila no dice nada. Con menos de
# dos días aparece el reloj, y las horas no se cortan en 24.
cuenta_regresiva() { # $1=epoch del vencimiento
  local v="$1" ahora r d h m sg
  (( v == 0 )) && { printf '—'; return; }
  printf -v ahora '%(%s)T' -1
  r=$(( v - ahora ))
  (( r <= 0 )) && { printf '00:00:00'; return; }
  if (( r >= 172800 )); then
    d=$(( r / 86400 ))
    (( d >= 1000 )) && { printf '%dd' "$d"; return; }
    printf '%d días' "$d"; return
  fi
  h=$(( r / 3600 )); r=$(( r % 3600 ))
  m=$(( r / 60 ));   sg=$(( r % 60 ))
  printf '%02d:%02d:%02d' "$h" "$m" "$sg"
}

color_estado() {
  case "$1" in
    vencida|bloqueada) printf '%s' "$E_ERR" ;;
    pronto)            printf '%s' "$E_WARN" ;;
    prueba)            printf '%s' "$E_P2" ;;
    activa)            printf '%s' "$E_OK" ;;
    *)                 printf '%s' "$E_MUT" ;;
  esac
}

# ====================================================== MARCO A LO ANCHO ===
# 2 de margen + 1 del borde + 74 de contenido + 1 del borde = 78.
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

# Media fila de opción: 2 del número + 1 + 2 del emoji + 1 + 31 del texto = 37
opcion() { # $1=número $2=emoji $3=texto
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
# El filtro que está puesto se escribe en rosa, el mismo color del título de
# la tabla: se ve de un vistazo cuál está activo y con qué lista se
# corresponde. Antes se marcaba con un fondo, pero sombrear una sola opción
# del cuadro queda raro.
opcion_f() { # $1=número $2=emoji $3=texto $4=clave del filtro
  local c="$E_BLD$E_TXT"
  [ "$FILTRO" = "$4" ] && c="$E_BLD$E_PINK"
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$c" "$(pad "$3" 31)" "$E_RST"
}
opcion_salir() {
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_ERR" "$(pad '00' 2)" "$E_RST" "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad "${1:-VOLVER AL PANEL}" 70)" "$E_RST"
}

linea_aviso() {
  if   [ -n "$AVISO" ]; then
    printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  elif (( SIN_ROOT )); then
    printf '  %s%s%s\n' "$E_BLD$E_WARN" "$(pad '▸ Entrá como root para ver las cuentas' 76)" "$E_RST"
  else
    printf '  %s\n' "$(pad '' 76)"
  fi
}

prompt() {
  local et="${1:-Opción:}" vis
  vis=$(( 4 + ${#et} + 1 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%s%s%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$et" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

# =============================================================== PANTALLA ===
# Fila de 74: 1 + nº 2 + 2 + usuario 18 + 2 + finaliza 10 + 2 + termina 9
#             + 2 + conex 5 + 2 + límite 6 + 2 + estado 10 + 1
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'USUARIO' 18)" "$(pad 'FINALIZA' 10)" \
    "$(rpad 'TERMINA' 9)" "$(rpad 'CONEX' 5)" "$(rpad 'LÍMITE' 6)" \
    "$(rpad 'ESTADO' 10)" "$E_RST")"
}
fila_usuario() { # $1=número a mostrar  $2=índice real
  local n="$1" i="$2" col colr resta ahora_f falta cx lim
  col="$(color_estado "${T_ESTADO[i]}")"
  resta="$(cuenta_regresiva "${T_VTO[i]}")"
  printf -v ahora_f '%(%s)T' -1
  falta=$(( ${T_VTO[i]:-0} - ahora_f ))
  # El color sale de la FECHA, no del texto: una vencida se escribe 00:00:00
  # y mirar la cadena ya no alcanza para distinguirla.
  colr="$E_TXT"
  if   (( ${T_VTO[i]:-0} == 0 )); then colr="$E_MUT"
  elif (( falta <= 0 ));          then colr="$E_BLD$E_ERR"
  elif (( falta < 172800 ));      then colr="$E_BLD$E_WARN"
  fi
  # Las conexiones en verde cuando hay alguien usando la cuenta ahora mismo.
  cx="$E_MUT"; (( ${T_CONEX[i]:-0} > 0 )) && cx="$E_BLD$E_OK"
  lim="${T_LIMITE[i]}"; [ -z "$lim" ] && lim="—"
  fila_ancha "$(printf ' %s%s%s  %s%s%s  %s%s  %s%s%s  %s%s  %s%s  %s%s%s ' \
    "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST" \
    "$E_TXT" "$(pad "${T_NOM[i]}" 18)" "$E_RST" \
    "$E_MUT" "$(pad "${T_VENCE[i]}" 10)" \
    "$colr" "$(rpad "$resta" 9)" "$E_RST" \
    "$cx" "$(rpad "${T_CONEX[i]}" 5)" \
    "$E_MUT" "$(rpad "$lim" 6)" \
    "$col" "$(rpad "${T_ESTADO[i]}" 10)" "$E_RST")"
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
  if (( total == 0 )); then medio="no hay cuentas que coincidan"
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
  local t="TODAS LAS CUENTAS"
  case "$FILTRO" in
    activas)    t="ACTIVAS" ;;
    pronto)     t="POR VENCER" ;;
    vencidas)   t="VENCIDAS" ;;
    bloqueadas) t="BLOQUEADAS" ;;
    enlinea)    t="EN LÍNEA AHORA" ;;
  esac
  [ -n "$BUSCA" ] && t="$t · BUSCANDO \"$BUSCA\""
  printf '%s' "$t"
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
  encabezado "USUARIOS REGISTRADOS" "KIRA v$KIRA_VER"
  echo
  techo_ancho "$(titulo_tabla)"
  cab_tabla
  if (( total == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'Ninguna cuenta entra en este filtro.' 72)")"
    for ((i=1; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  else
    for ((i=desde; i<fin; i++)); do fila_usuario $(( i + 1 )) "${V_IDX[i]}"; done
    for ((i=fin-desde; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  fi
  indicador_paginas "$pags" "$desde" "$fin" "$total"
  piso_ancho
  echo
  seccion "FILTRAR" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion_f '01' '📋' 'TODAS' todas)"          "$(opcion_f '02' '✅' 'ACTIVAS' activas)"
  printf '  %s  %s\n' "$(opcion_f '03' '⏳' 'POR VENCER' pronto)"     "$(opcion_f '04' '💀' 'VENCIDAS' vencidas)"
  printf '  %s  %s\n' "$(opcion_f '05' '🔒' 'BLOQUEADAS' bloqueadas)" "$(opcion_f '06' '📡' 'EN LÍNEA AHORA' enlinea)"
  printf '  %s  %s\n' "$(opcion   '07' '🔍' 'BUSCAR POR NOMBRE')" "$(opcion '77' '⏪' 'PÁGINA ANTERIOR')"
  printf '  %s  %s\n' "$(opcion   '88' '⏩' 'PÁGINA SIGUIENTE')"  "$(opcion '99' '🧽' 'LIMPIAR LA BÚSQUEDA')"
  opcion_salir
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_buscar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "USUARIOS REGISTRADOS" "KIRA v$KIRA_VER"
  echo
  seccion "BUSCAR POR NOMBRE" "$E_P1"
  echo
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad 'Escribí una parte del nombre y dale ENTER. No hace falta el nombre entero.' 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'ENTER en blanco muestra todas las cuentas otra vez.' 76)" "$E_RST"
  echo
  printf '  %s%s%s%s%s\n' "$E_MUT" "$(pad 'Buscando ahora:' 17)" \
    "$E_BLD$E_P1" "$(pad "${BUSCA:-nada}" 59)" "$E_RST"
  echo
  opcion_salir "CANCELAR"
  echo
  linea_aviso
  prompt "Buscar:"
}

pintar() {
  case "$PANTALLA" in
    buscar) pintar_buscar ;;
    *)      pintar_lista ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

ejecutar() {
  local entrada="$1"
  AVISO=""
  case "$PANTALLA" in
    lista)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        1|01) FILTRO=todas;      PAGINA=0; aplicar_filtro ;;
        2|02) FILTRO=activas;    PAGINA=0; aplicar_filtro ;;
        3|03) FILTRO=pronto;     PAGINA=0; aplicar_filtro ;;
        4|04) FILTRO=vencidas;   PAGINA=0; aplicar_filtro ;;
        5|05) FILTRO=bloqueadas; PAGINA=0; aplicar_filtro ;;
        6|06) FILTRO=enlinea;    PAGINA=0; aplicar_filtro ;;
        7|07) PANTALLA=buscar; BUF="" ;;
        77) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        88) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        99)
          if [ -z "$BUSCA" ]; then AVISO="No hay ninguna búsqueda puesta"
          else BUSCA=""; PAGINA=0; aplicar_filtro; fi ;;
        *)  AVISO="Elegí una opción de la lista" ;;
      esac ;;
    buscar)
      if [ "$entrada" = "00" ]; then PANTALLA=lista
      else BUSCA="$entrada"; PAGINA=0; aplicar_filtro; PANTALLA=lista; fi ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;
    *)
      # En la pantalla de buscar se escriben letras; en la lista, sólo números.
      if [ "$PANTALLA" = buscar ]; then
        case "$1" in [[:print:]]) (( ${#BUF} < 24 )) && BUF="$BUF$1" ;; esac
      else
        case "$1" in [0-9]) (( ${#BUF} < 4 )) && BUF="$BUF$1" ;; esac
      fi ;;
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

while true; do
  printf -v ahora '%(%s)T' -1
  redibujar=0
  # El reloj de TERMINA corre, así que se redibuja cada segundo. Las cuentas
  # se releen cada 5: cambian poco y leer passwd + shadow entero cada vuelta
  # es gasto al pedo.
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; redibujar=1; fi
  if [ "$PANTALLA" = lista ] && (( ahora - CARGA_ANT >= 5 )); then
    cargar_cuentas; CARGA_ANT=$ahora; redibujar=1
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