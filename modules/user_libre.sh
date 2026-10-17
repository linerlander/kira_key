#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.14 · CONTROL MULTILOGIN
#  Cuántas conexiones a la vez le toca a cada cliente, y quién se está
#  pasando ahora mismo. El que corta es el servicio kira-vigilante, que ya
#  venía andando por detrás: acá se le fijan los números y se lo prende o
#  apaga, sin tocar archivos a mano.
#  Uso:  bash modules/user_libre.sh
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
ui_exige banda cabecera cachear_cabecera datos_sistema seccion encabezado pad rpad volcar rep barra

if [ "$(id -u)" -ne 0 ]; then
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para cambiar los límites\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
POR_PAGINA=10
PAGINA=0
FILTRO=todas              # todas · excedidos
PANTALLA=lista            # lista · limite
SEL_USR=""
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0; CARGA_ANT=0
VIGILA="sin instalar"     # activo · parado · sin instalar

LIMITES="$DIR/db/limites"
VIGILANTE="$DIR/kira-vigilante"
MAX_LIMITE=99

declare -a L_NOM=() L_CONEX=() L_LIMITE=() L_ESTADO=()
declare -a V_IDX=()
declare -A CON_USR=() NOM_DE_UID=()

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
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
    v=""; est=""
    # OJO con los ZOMBIS. Cuando una conexión se cae, el proceso de sshd queda
    # un rato en estado Z: ya murió, pero sigue en /proc con su nombre y su
    # dueño intactos hasta que el padre lo levanta. Contarlo es contar una
    # conexión que no existe, y como el número nunca baja, el cupo se llena de
    # fantasmas y el cliente deja de poder entrar. Se reconecta, deja otro
    # zombi, y empeora. Por eso hay que mirar el estado y saltearlos.
    # State: viene antes que Uid: en /proc/PID/status, así que cuando
    # encontramos el Uid el estado ya está leído.
    while read -r k v _; do
      case "$k" in
        State:) est="$v" ;;
        Uid:)   break ;;
      esac
    done < "$p/status" 2>/dev/null
    [ "$est" = "Z" ] && continue
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    u="${NOM_DE_UID[$v]:-}"
    [ -n "$u" ] && (( CON_USR[$u]++ ))
  done
}

estado_vigilante() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet kira-vigilante 2>/dev/null; then
    VIGILA="activo"
  elif [ -f /usr/local/sbin/kira-vigilante ]; then
    VIGILA="parado"
  else
    VIGILA="sin instalar"
  fi
}

cargar_cuentas() {
  L_NOM=(); L_CONEX=(); L_LIMITE=(); L_ESTADO=(); NOM_DE_UID=()
  declare -A LIM=()
  estado_vigilante

  local n uid resto
  while IFS=: read -r n resto uid resto; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid != 65534 )) || continue
    NOM_DE_UID[$uid]="$n"
  done < /etc/passwd

  cargar_conexiones

  local lu ll
  if [ -r "$LIMITES" ]; then
    while read -r lu ll; do
      [ -n "$lu" ] && [[ "$ll" =~ ^[0-9]+$ ]] && LIM[$lu]="$ll"
    done < "$LIMITES"
  fi

  local u cx lm est
  for uid in "${!NOM_DE_UID[@]}"; do
    u="${NOM_DE_UID[$uid]}"
    cx="${CON_USR[$u]:-0}"
    lm="${LIM[$u]:-}"
    if   [ -z "$lm" ];       then est="sin tope"
    elif (( cx > lm ));      then est="se pasa"
    elif (( cx == lm && cx > 0 )); then est="en el tope"
    else                          est="dentro"
    fi
    L_NOM+=("$u"); L_CONEX+=("$cx"); L_LIMITE+=("$lm"); L_ESTADO+=("$est")
  done
  ordenar
}

# De más conexiones a menos: el que se está pasando queda arriba de todo.
ordenar() {
  local -a orden=()
  local i linea
  while read -r linea; do [ -n "$linea" ] && orden+=("${linea#* }"); done < <(
    for i in "${!L_NOM[@]}"; do printf '%s %s\n' "${L_CONEX[i]}" "$i"; done | sort -rn
  )
  V_IDX=()
  for i in "${orden[@]}"; do
    [ "$FILTRO" = excedidos ] && [ "${L_ESTADO[i]}" != "se pasa" ] && continue
    V_IDX+=("$i")
  done
  local tope=$(( (${#V_IDX[@]} + POR_PAGINA - 1) / POR_PAGINA ))
  (( tope == 0 )) && tope=1
  (( PAGINA >= tope )) && PAGINA=$(( tope - 1 ))
}

paginas() { local n=${#V_IDX[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

indice_de() { # $1=usuario -> IDX, o -1
  IDX=-1
  local i
  for i in "${!L_NOM[@]}"; do [ "${L_NOM[i]}" = "$1" ] && { IDX=$i; return; }; done
}

cuantos_se_pasan() {
  local i n=0
  for i in "${!L_ESTADO[@]}"; do [ "${L_ESTADO[i]}" = "se pasa" ] && (( n++ )); done
  printf '%s' "$n"
}

# ============================================================== ACCIONES ====
poner_limite() { # $1=usuario $2=límite ('' = sin tope)
  local u="$1" l="$2" tmp="$DIR/db/.limites.tmp"
  mkdir -p "$DIR/db" 2>/dev/null
  [ -e "$LIMITES" ] || : > "$LIMITES" 2>/dev/null
  grep -v "^$u " "$LIMITES" > "$tmp" 2>/dev/null
  [ -n "$l" ] && printf '%s %s\n' "$u" "$l" >> "$tmp"
  mv -f "$tmp" "$LIMITES" 2>/dev/null || { AVISO="No pude escribir $LIMITES"; return 1; }
  cargar_cuentas
  return 0
}

prender_vigilante() {
  [ -f "$VIGILANTE" ] || { AVISO="Falta el archivo kira-vigilante en la carpeta del panel"; return 1; }
  KIRA_DIR="$DIR" bash "$VIGILANTE" --instalar >/tmp/kira-vigilante.log 2>&1
  estado_vigilante
  [ "$VIGILA" = activo ] && return 0
  AVISO="No quedó activo · mirá /tmp/kira-vigilante.log"
  return 1
}
apagar_vigilante() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now kira-vigilante >/dev/null 2>&1
  fi
  estado_vigilante
  [ "$VIGILA" != activo ] && return 0
  AVISO="No se pudo apagar el vigilante"
  return 1
}

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
# Fila de "etiqueta  valor" adentro del marco: 2 + 14 + 57 + 1 = 74
fila_dato() { # $1=etiqueta $2=valor [$3=color]
  fila_ancha "$(printf '  %s%s%s%s%s ' "$E_MUT" "$(pad "$1" 14)" \
    "${3:-$E_BLD$E_TXT}" "$(pad "$2" 57)" "$E_RST")"
}

# Lo tecleado se marca con fondo: ves a qué le vas a dar antes del ENTER.
sel_de() { # $1=número de fila o letra de opción
  [ -n "$BUF" ] || return 0
  local a="${BUF,,}" b="${1,,}"
  { [ "$a" = "$b" ] || [ "$a" = "${b#0}" ]; } && printf '%s' "$B_SEL"
  return 0
}
opcion() { # $1=letra o número $2=emoji $3=texto
  local f; f="$(sel_de "$1")"
  printf '%s%s%s%s %s%s%s %s%s%s' "$f$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST$f" \
         "$E_P2" "$2" "$E_RST$f" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
opcion_f() { # $1=letra $2=emoji $3=texto $4=clave del filtro
  local c="$E_BLD$E_TXT" f
  [ "$FILTRO" = "$4" ] && c="$E_BLD$E_PINK"
  f="$(sel_de "$1")"
  printf '%s%s%s%s %s%s%s %s%s%s' "$f$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST$f" \
         "$E_P2" "$2" "$E_RST$f" "$c" "$(pad "$3" 31)" "$E_RST"
}
opcion_salir() {
  local f; f="$(sel_de '00')"
  printf '  %s%s%s%s %s%s%s %s%s%s\n' \
    "$f$E_BLD$E_ERR" "$(pad '00' 2)" "$E_RST$f" "$E_P2" "🚪" "$E_RST$f" \
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
# Fila de 74: 1 + nº 2 + 2 + usuario 18 + 2 + conex 5 + 2 + límite 6
#             + 2 + estado 12 + 2 + uso 19 + 1
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'USUARIO' 18)" "$(rpad 'CONEX' 5)" \
    "$(rpad 'LÍMITE' 6)" "$(pad 'ESTADO' 12)" "$(pad 'USO DEL CUPO' 19)" "$E_RST")"
}
fila_cuenta() { # $1=número a mostrar $2=índice
  local n="$1" i="$2" cx lm est col ccx pct barra txt f
  cx="${L_CONEX[i]}"; lm="${L_LIMITE[i]}"; est="${L_ESTADO[i]}"
  case "$est" in
    "se pasa")    col="$E_BLD$E_ERR" ;;
    "en el tope") col="$E_BLD$E_WARN" ;;
    "sin tope")   col="$E_MUT" ;;
    *)            col="$E_OK" ;;
  esac
  ccx="$E_MUT"; (( cx > 0 )) && ccx="$E_BLD$E_OK"
  # Sin cupo no hay barra que dibujar, y con cero conexiones tampoco: doce
  # caracteres de relleno repetidos en cada fila sin uso arman un bloque
  # oscuro que le gana la vista a las barras que sí importan.
  if [ -n "$lm" ] && (( cx > 0 )); then
    pct=$(( cx * 100 / lm )); (( pct > 100 )) && pct=100
    barra="$(barra "$pct" 12)"
    txt="$cx/$lm"
  else
    barra="$(pad '' 12)"
    if [ -n "$lm" ]; then txt="0/$lm"; else txt="—"; fi
  fi
  f="$(sel_de "$n")"
  fila_ancha "$(printf '%s %s%s%s  %s%s%s  %s%s  %s%s  %s%s%s  %s %s%s%s %s' \
    "$f" "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST$f" \
    "$E_TXT" "$(pad "${L_NOM[i]}" 18)" "$E_RST$f" \
    "$ccx" "$(rpad "$cx" 5)" \
    "$E_MUT" "$(rpad "${lm:---}" 6)" \
    "$col" "$(pad "$est" 12)" "$E_RST$f" \
    "$barra" "$E_MUT" "$(rpad "$txt" 6)" "$E_RST$f" "$E_RST")"
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

# El renglón que dice si esto está cortando de verdad o es sólo un número
# guardado. Sin el vigilante andando, los límites no se aplican.
# Cuando el vigilante está andando no se dice nada: que funcione es lo
# normal y un cartel verde fijo sólo ocupa lugar. El renglón aparece
# únicamente cuando hay algo que avisar, que es cuando NO está cortando.
linea_vigilante() {
  local c t
  case "$VIGILA" in
    activo) return 0 ;;
    parado) c="$E_WARN"; t="▸ Vigilante apagado · los límites están guardados pero NO se aplican" ;;
    *)      c="$E_ERR";  t="✖ Vigilante sin instalar · hoy nadie corta nada · opción C" ;;
  esac
  printf '  %s%s%s\n' "$E_BLD$c" "$(pad "$t" 76)" "$E_RST"
}

titulo_tabla() {
  if [ "$FILTRO" = excedidos ]; then printf 'SÓLO LOS QUE SE PASAN'
  else printf 'TODAS LAS CUENTAS · %s PASÁNDOSE' "$(cuantos_se_pasan)"; fi
}

marco_superior() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "CONTROL MULTILOGIN" "KIRA v$KIRA_VER"
  echo
}

pintar_lista() {
  local total=${#V_IDX[@]} pags; pags=$(paginas)
  local i desde fin
  desde=$(( PAGINA * POR_PAGINA ))
  fin=$(( desde + POR_PAGINA ))
  (( fin > total )) && fin=$total

  marco_superior
  techo_ancho "$(titulo_tabla)"
  cab_tabla
  if (( total == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'Ninguna cuenta entra en este filtro.' 72)")"
    for ((i=1; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  else
    for ((i=desde; i<fin; i++)); do fila_cuenta $(( i + 1 )) "${V_IDX[i]}"; done
    for ((i=fin-desde; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  fi
  indicador_paginas "$pags" "$desde" "$fin" "$total"
  piso_ancho
  echo
  linea_vigilante
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad '  Escribí el número de una cuenta para cambiarle el cupo.' 76)" "$E_RST"
  echo
  seccion "OPCIONES · SE ELIGEN CON LETRA" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion_f 'A' '📋' 'TODAS' todas)" "$(opcion_f 'B' '🚦' 'SÓLO LOS QUE SE PASAN' excedidos)"
  if [ "$VIGILA" = activo ]; then
    printf '  %s  %s\n' "$(opcion 'C' '🛑' 'APAGAR EL VIGILANTE')" "$(opcion 'D' '⏪' 'PÁGINA ANTERIOR')"
  else
    printf '  %s  %s\n' "$(opcion 'C' '🔧' 'PRENDER EL VIGILANTE')" "$(opcion 'D' '⏪' 'PÁGINA ANTERIOR')"
  fi
  printf '  %s  %s\n' "$(opcion 'E' '⏩' 'PÁGINA SIGUIENTE')" "$(pad '' 37)"
  opcion_salir
  echo
  linea_aviso
  prompt "Cuenta:"
}

pintar_limite() {
  local i cx="0" lm="" est=""
  indice_de "$SEL_USR"; i=$IDX
  if (( i >= 0 )); then cx="${L_CONEX[i]}"; lm="${L_LIMITE[i]}"; est="${L_ESTADO[i]}"; fi
  local ccx="$E_MUT"; (( cx > 0 )) && ccx="$E_BLD$E_OK"
  marco_superior
  techo_ancho "CUPO DE $SEL_USR"
  fila_dato "USUARIO"     "$SEL_USR"
  fila_dato "CONECTADO"   "$cx conexiones ahora mismo" "$ccx"
  fila_dato "CUPO ACTUAL" "${lm:-sin tope}"
  fila_dato "ESTADO"      "$est"
  fila_ancha "$(pad '' 74)"
  fila_dato "PARA CAMBIAR" "escribí cuántas conexiones le permitís" "$E_BLD$E_P1"
  fila_dato ""             "0 le saca el tope · 00 cancela" "$E_MUT"
  piso_ancho
  echo
  if [ "$VIGILA" != activo ]; then
    printf '  %s%s%s\n' "$E_BLD$E_WARN" \
      "$(pad '▸ El vigilante está apagado: el número se guarda pero no se aplica.' 76)" "$E_RST"
  else
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad 'Si se pasa, el vigilante le corta las MÁS VIEJAS: la que reconecta gana.' 76)" "$E_RST"
  fi
  echo
  opcion_salir "CANCELAR"
  echo
  linea_aviso
  prompt "Cupo:"
}

pintar() {
  case "$PANTALLA" in
    limite) pintar_limite ;;
    *)      pintar_lista ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

ejecutar() {
  local entrada="$1" idx n
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    lista)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        a|A) FILTRO=todas;     PAGINA=0; ordenar ;;
        b|B) FILTRO=excedidos; PAGINA=0; ordenar ;;
        c|C)
          if [ "$VIGILA" = activo ]; then
            apagar_vigilante && MENSAJE="Vigilante apagado · los límites dejan de aplicarse"
          else
            prender_vigilante && MENSAJE="Vigilante encendido · ya está cortando lo que sobra"
          fi ;;
        d|D) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        e|E) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        *)
          # Los NÚMEROS son cuentas y las LETRAS son opciones: la lista numera
          # de corrido, así que cualquier opción numerada terminaría pisándose
          # con el número de una cuenta en la página dos.
          if [[ "$entrada" =~ ^[0-9]+$ ]]; then
            idx=$(( 10#$entrada - 1 ))
            if (( idx >= 0 && idx < ${#V_IDX[@]} )); then
              SEL_USR="${L_NOM[${V_IDX[$idx]}]}"; PANTALLA=limite
            else AVISO="No hay ninguna cuenta con el número $entrada"; fi
          else AVISO="Los números son cuentas y las letras son opciones"; fi ;;
      esac ;;

    limite)
      case "$entrada" in
        00) PANTALLA=lista; SEL_USR="" ;;
        "") AVISO="Escribí un número · 0 le saca el tope · 00 cancela" ;;
        *)
          if [[ "$entrada" =~ ^[0-9]+$ ]]; then
            n=$(( 10#$entrada ))
            if (( n == 0 )); then
              poner_limite "$SEL_USR" "" && {
                MENSAJE="$SEL_USR queda sin tope de conexiones"
                PANTALLA=lista; SEL_USR=""; }
            elif (( n <= MAX_LIMITE )); then
              poner_limite "$SEL_USR" "$n" && {
                MENSAJE="$SEL_USR queda con $n conexiones a la vez"
                PANTALLA=lista; SEL_USR=""; }
            else
              AVISO="Como mucho $MAX_LIMITE · si querés más, usá 0 para sacarle el tope"
            fi
          else AVISO="Escribí un número · 0 le saca el tope · 00 cancela"; fi ;;
      esac ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    # Números para las cuentas y los cupos, letras para las opciones. Una
    # letra reemplaza lo que hubiera: nadie escribe "3a".
    [0-9])         (( ${#BUF} < 4 )) && BUF="$BUF$1" ;;
    [a-eA-E])      [ "$PANTALLA" = lista ] && BUF="$1" ;;
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

while true; do
  printf -v ahora '%(%s)T' -1
  redibujar=0
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; redibujar=1; fi
  # Las conexiones cambian solas, así que se releen cada 3 segundos: es lo
  # que hace que veas en vivo a alguien pasarse del cupo.
  if (( ahora - CARGA_ANT >= 3 )); then
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