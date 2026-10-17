#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.08 · BLOQUEAR USUARIO
#  Deja la cuenta sin poder entrar, pero SIN borrarla: se le conserva la fecha
#  de vencimiento, el límite y el consumo. Cuando el cliente se pone al día se
#  desbloquea y sigue donde estaba.
#  Uso:  bash modules/user_lock.sh
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

if [ "$(id -u)" -ne 0 ]; then
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para bloquear cuentas\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
POR_PAGINA=10
PAGINA=0
FILTRO=todas              # todas · activas · bloqueadas
PANTALLA=lista            # lista · motivo · confirmar
SEL_USR=""
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0; CARGA_ANT=0

REGISTRO="$DIR/db/bloqueos"

declare -a B_NOM=() B_CONEX=() B_ESTADO=() B_DESDE=() B_MOTIVO=()
declare -a B_VENCE=() B_LIMITE=()
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

cargar_cuentas() {
  B_NOM=(); B_CONEX=(); B_ESTADO=(); B_DESDE=(); B_MOTIVO=()
  B_VENCE=(); B_LIMITE=(); NOM_DE_UID=()
  declare -A ES_CLIENTE=() DESDE=() MOTIVO=() LIM=()

  local n uid resto
  while IFS=: read -r n resto uid resto; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid != 65534 )) || continue
    NOM_DE_UID[$uid]="$n"; ES_CLIENTE[$n]=1
  done < /etc/passwd

  cargar_conexiones

  # El registro propio: cuándo se bloqueó y por qué. El sistema no guarda
  # nada de eso —sólo pone un "!" adelante de la clave— así que si no lo
  # anotamos nosotros, a la semana no te acordás por qué bloqueaste a quién.
  local ru rf rm
  if [ -r "$REGISTRO" ]; then
    while IFS='|' read -r ru rf rm; do
      [ -n "$ru" ] && { DESDE[$ru]="$rf"; MOTIVO[$ru]="$rm"; }
    done < "$REGISTRO"
  fi

  local lu ll
  if [ -r "$DIR/db/limites" ]; then
    while read -r lu ll; do
      [ -n "$lu" ] && [[ "$ll" =~ ^[0-9]+$ ]] && LIM[$lu]="$ll"
    done < "$DIR/db/limites"
  fi

  local nom clave c3 c4 c5 c6 c7 vto est fecha
  while IFS=: read -r nom clave c3 c4 c5 c6 c7 vto resto; do
    [ -n "${ES_CLIENTE[$nom]:-}" ] || continue
    case "$clave" in
      '!'|'!!'|'*'|'') est="sin clave" ;;
      '!'*)            est="bloqueada" ;;
      *)               est="activa" ;;
    esac
    if [[ "$vto" =~ ^[0-9]+$ ]]; then
      fecha=$(date -u -d "@$(( vto * 86400 ))" '+%d/%m/%Y' 2>/dev/null)
    else
      fecha="sin fecha"
    fi
    B_NOM+=("$nom"); B_CONEX+=("${CON_USR[$nom]:-0}"); B_ESTADO+=("$est")
    B_DESDE+=("${DESDE[$nom]:-}"); B_MOTIVO+=("${MOTIVO[$nom]:-}")
    B_VENCE+=("$fecha"); B_LIMITE+=("${LIM[$nom]:-}")
  done < /etc/shadow
  aplicar_filtro
}

aplicar_filtro() {
  V_IDX=()
  local i e
  for i in "${!B_NOM[@]}"; do
    e="${B_ESTADO[i]}"
    case "$FILTRO" in
      activas)    [ "$e" = activa ] || continue ;;
      bloqueadas) [ "$e" = bloqueada ] || continue ;;
    esac
    V_IDX+=("$i")
  done
  local tope=$(( (${#V_IDX[@]} + POR_PAGINA - 1) / POR_PAGINA ))
  (( tope == 0 )) && tope=1
  (( PAGINA >= tope )) && PAGINA=$(( tope - 1 ))
}

paginas() { local n=${#V_IDX[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

indice_de() { # $1=usuario -> deja el índice en IDX, o -1
  IDX=-1
  local i
  for i in "${!B_NOM[@]}"; do [ "${B_NOM[i]}" = "$1" ] && { IDX=$i; return; }; done
}

estado_de() { # $1=usuario
  local i
  for i in "${!B_NOM[@]}"; do [ "${B_NOM[i]}" = "$1" ] && { printf '%s' "${B_ESTADO[i]}"; return; }; done
}

# ============================================================== ACCIONES ====
# Igual que al cambiar la clave: bloquear NO tira lo que ya está conectado.
# Los túneles abiertos siguen vivos con la sesión vieja y el cliente sigue
# navegando como si nada hasta que se le corte solo. Por eso se cortan acá.
cortar_conexiones() { # $1=usuario
  local u="$1" uid p c k v n=0
  uid=$(id -u "$u" 2>/dev/null) || { printf '0'; return; }
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
    [ "$v" = "$uid" ] && { kill -9 "${p##*/}" 2>/dev/null && n=$(( n + 1 )); }
  done
  printf '%s' "$n"
}

anotar() { # $1=usuario $2=motivo
  local tmp="$DIR/db/.bloqueos.tmp"
  mkdir -p "$DIR/db" 2>/dev/null
  [ -e "$REGISTRO" ] || : > "$REGISTRO" 2>/dev/null
  grep -v "^$1|" "$REGISTRO" > "$tmp" 2>/dev/null
  printf '%s|%s|%s\n' "$1" "$(date '+%d/%m/%Y')" "$2" >> "$tmp"
  mv -f "$tmp" "$REGISTRO" 2>/dev/null
}
desanotar() { # $1=usuario
  local tmp="$DIR/db/.bloqueos.tmp"
  [ -r "$REGISTRO" ] || return 0
  grep -v "^$1|" "$REGISTRO" > "$tmp" 2>/dev/null
  mv -f "$tmp" "$REGISTRO" 2>/dev/null
}

bloquear() { # $1=usuario $2=motivo
  local u="$1" m="$2" n
  if ! usermod -L "$u" 2>/tmp/kira-lock.err; then
    AVISO="No se pudo bloquear: $(head -1 /tmp/kira-lock.err 2>/dev/null)"
    return 1
  fi
  anotar "$u" "$m"
  n=$(cortar_conexiones "$u")
  if (( n > 0 )); then MENSAJE="$u bloqueado · se le cortaron $n conexiones"
  else                 MENSAJE="$u bloqueado · no tenía conexiones abiertas"; fi
  cargar_cuentas
  return 0
}

desbloquear() { # $1=usuario
  local u="$1" clave
  # OJO: usermod -U saca el "!" de adelante. Si lo único que había era ese
  # "!", al sacarlo la cuenta queda CON LA CLAVE VACÍA y entra cualquiera
  # sin escribir nada. Eso pasa con las cuentas a las que nunca se les puso
  # contraseña. Antes de desbloquear hay que mirar qué hay detrás del "!".
  clave=$(awk -F: -v n="$u" '$1==n {print $2; exit}' /etc/shadow 2>/dev/null)
  case "$clave" in
    '!'|'!!'|'!*'|'')
      AVISO="$u no tiene contraseña guardada · ponele una desde el módulo 03"
      return 1 ;;
  esac
  if ! usermod -U "$u" 2>/tmp/kira-lock.err; then
    AVISO="No se pudo desbloquear: $(head -1 /tmp/kira-lock.err 2>/dev/null)"
    return 1
  fi
  desanotar "$u"
  MENSAJE="$u desbloqueado · ya puede volver a conectarse"
  cargar_cuentas
  return 0
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
# Una fila de "etiqueta  valor" dentro del marco: 2 + 14 + 57 + 1 = 74
fila_dato() { # $1=etiqueta $2=valor [$3=color del valor]
  fila_ancha "$(printf '  %s%s%s%s%s ' "$E_MUT" "$(pad "$1" 14)" \
    "${3:-$E_BLD$E_TXT}" "$(pad "$2" 57)" "$E_RST")"
}
piso_ancho() { printf '  %s╰%s╯%s\n' "$M_TABLA" "$(rep '─' 74)" "$E_RST"; }

# Lo que se va tecleando se marca con fondo, igual que en el menú principal:
# así ves a qué le vas a dar ANTES de apretar ENTER. Cada vez que se corta el
# color hay que volver a poner el fondo, si no el sombreado queda a pedazos.
sel_de() { # $1=número de fila o letra de opción
  [ -n "$BUF" ] || return 0
  local a="${BUF,,}" b="${1,,}"
  { [ "$a" = "$b" ] || [ "$a" = "${b#0}" ]; } && printf '%s' "$B_SEL"
  return 0
}

opcion() { # $1=número $2=emoji $3=texto
  local f; f="$(sel_de "$1")"
  printf '%s%s%s%s %s%s%s %s%s%s' "$f$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST$f" \
         "$E_P2" "$2" "$E_RST$f" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
opcion_f() { # $1=número $2=emoji $3=texto $4=clave del filtro
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
# Fila de 74: 1 + nº 2 + 2 + usuario 16 + 2 + conex 5 + 2 + estado 10
#             + 2 + desde 10 + 2 + motivo 19 + 1
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'USUARIO' 16)" "$(rpad 'CONEX' 5)" \
    "$(pad 'ESTADO' 10)" "$(pad 'DESDE' 10)" "$(pad 'MOTIVO' 19)" "$E_RST")"
}
fila_cuenta() { # $1=número a mostrar $2=índice
  local n="$1" i="$2" col cx de mo f
  case "${B_ESTADO[i]}" in
    bloqueada) col="$E_BLD$E_ERR" ;;
    activa)    col="$E_BLD$E_OK" ;;
    *)         col="$E_MUT" ;;
  esac
  cx="$E_MUT"; (( ${B_CONEX[i]:-0} > 0 )) && cx="$E_BLD$E_OK"
  de="${B_DESDE[i]}"; [ -z "$de" ] && de="—"
  mo="${B_MOTIVO[i]}"; [ -z "$mo" ] && mo="—"
  f="$(sel_de "$n")"
  fila_ancha "$(printf '%s %s%s%s  %s%s%s  %s%s  %s%s%s  %s%s  %s%s%s %s' \
    "$f" "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST$f" \
    "$E_TXT" "$(pad "${B_NOM[i]}" 16)" "$E_RST$f" \
    "$cx" "$(rpad "${B_CONEX[i]}" 5)" \
    "$col" "$(pad "${B_ESTADO[i]}" 10)" "$E_RST$f" \
    "$E_MUT" "$(pad "$de" 10)" \
    "$E_MUT" "$(pad "$mo" 19)" "$E_RST$f" "$E_RST")"
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

cuantas_bloqueadas() {
  local i n=0
  for i in "${!B_ESTADO[@]}"; do [ "${B_ESTADO[i]}" = bloqueada ] && (( n++ )); done
  printf '%s' "$n"
}

titulo_tabla() {
  case "$FILTRO" in
    activas)    printf 'SÓLO LAS ACTIVAS' ;;
    bloqueadas) printf 'SÓLO LAS BLOQUEADAS' ;;
    *)          printf 'TODAS LAS CUENTAS · %s BLOQUEADAS' "$(cuantas_bloqueadas)" ;;
  esac
}

marco_superior() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BLOQUEAR USUARIO" "KIRA v$KIRA_VER"
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
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad 'Escribí el número de la cuenta, o la letra de una opción, y ENTER.' 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'Bloquear no borra nada: se le guardan los días, el límite y el consumo.' 76)" "$E_RST"
  echo
  seccion "OPCIONES · SE ELIGEN CON LETRA" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion_f 'A' '📋' 'TODAS' todas)"       "$(opcion_f 'B' '✅' 'SÓLO ACTIVAS' activas)"
  printf '  %s  %s\n' "$(opcion_f 'C' '🔒' 'SÓLO BLOQUEADAS' bloqueadas)" "$(opcion 'D' '⏪' 'PÁGINA ANTERIOR')"
  printf '  %s  %s\n' "$(opcion   'E' '⏩' 'PÁGINA SIGUIENTE')"  "$(pad '' 37)"
  opcion_salir
  echo
  linea_aviso
  prompt "Cuenta:"
}

pintar_motivo() {
  local i cx="0" est="" ven="—" lim="—"
  indice_de "$SEL_USR"; i=$IDX
  if (( i >= 0 )); then
    cx="${B_CONEX[i]:-0}"; est="${B_ESTADO[i]}"
    ven="${B_VENCE[i]:-—}"
    [ -n "${B_LIMITE[i]}" ] && lim="${B_LIMITE[i]} conexiones a la vez"
  fi
  local ccx="$E_MUT"; (( cx > 0 )) && ccx="$E_BLD$E_OK"
  marco_superior
  techo_ancho "BLOQUEAR A $SEL_USR"
  fila_dato "USUARIO"     "$SEL_USR"
  fila_dato "ESTADO"      "$est"      "$E_BLD$E_OK"
  fila_dato "CONEXIONES"  "$cx"       "$ccx"
  fila_dato "VENCE"       "$ven"
  fila_dato "LÍMITE"      "$lim"
  fila_ancha "$(pad '' 74)"
  fila_dato "AL BLOQUEAR" "no entra más, y se le cortan las conexiones" "$E_WARN"
  fila_dato ""            "la cuenta queda igual: días, límite y consumo" "$E_MUT"
  piso_ancho
  echo
  seccion "POR QUÉ LO BLOQUEÁS" "$E_ERR"
  echo
  printf '  %s  %s\n' "$(opcion '01' '💳' 'NO PAGÓ')"          "$(opcion '02' '🔗' 'COMPARTIÓ LA CUENTA')"
  printf '  %s  %s\n' "$(opcion '03' '📈' 'ABUSO DE CONSUMO')" "$(opcion '04' '📝' 'OTRO MOTIVO')"
  opcion_salir "NO, VOLVER"
  echo
  linea_aviso
  prompt "Motivo:"
}

pintar_confirmar() {
  local i de="—" mo="—" cx="0" ven="—"
  indice_de "$SEL_USR"; i=$IDX
  if (( i >= 0 )); then
    [ -n "${B_DESDE[i]}" ]  && de="${B_DESDE[i]}"
    [ -n "${B_MOTIVO[i]}" ] && mo="${B_MOTIVO[i]}"
    cx="${B_CONEX[i]:-0}"; ven="${B_VENCE[i]:-—}"
  fi
  marco_superior
  techo_ancho "DESBLOQUEAR A $SEL_USR"
  fila_dato "USUARIO"     "$SEL_USR"
  fila_dato "ESTADO"      "bloqueada" "$E_BLD$E_ERR"
  fila_dato "DESDE"       "$de"
  fila_dato "MOTIVO"      "$mo"       "$E_BLD$E_WARN"
  fila_dato "VENCE"       "$ven"
  fila_ancha "$(pad '' 74)"
  fila_dato "AL SOLTARLO" "vuelve a entrar con la misma contraseña" "$E_OK"
  fila_dato ""            "se le borra el motivo del registro" "$E_MUT"
  piso_ancho
  echo
  seccion "CONFIRMÁ" "$E_OK"
  echo
  printf '  %s  %s\n' "$(opcion '01' '🔓' 'SÍ, DESBLOQUEAR')" "$(pad '' 37)"
  opcion_salir "NO, VOLVER"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar() {
  case "$PANTALLA" in
    motivo)    pintar_motivo ;;
    confirmar) pintar_confirmar ;;
    *)         pintar_lista ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

ejecutar() {
  local entrada="$1" idx est
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    lista)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        a|A) FILTRO=todas;      PAGINA=0; aplicar_filtro ;;
        b|B) FILTRO=activas;    PAGINA=0; aplicar_filtro ;;
        c|C) FILTRO=bloqueadas; PAGINA=0; aplicar_filtro ;;
        d|D) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        e|E) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        *)
          # Los NÚMEROS son siempre cuentas y las LETRAS son siempre opciones.
          # Por eso las de abajo son A, B, C y no 01, 02, 03: la lista numera
          # de corrido, así que en la página 2 la primera fila es la 11 y
          # cualquier opción numerada terminaría pisándose con una cuenta.
          if [[ "$entrada" =~ ^[0-9]+$ ]]; then
            idx=$(( 10#$entrada - 1 ))
            if (( idx >= 0 && idx < ${#V_IDX[@]} )); then
              SEL_USR="${B_NOM[${V_IDX[$idx]}]}"
              est="$(estado_de "$SEL_USR")"
              case "$est" in
                bloqueada) PANTALLA=confirmar ;;
                activa)    PANTALLA=motivo ;;
                *)         AVISO="$SEL_USR no tiene contraseña: no hay nada que bloquear"; SEL_USR="" ;;
              esac
            else AVISO="No hay ninguna cuenta con el número $entrada"; fi
          else AVISO="Los números son cuentas y las letras son opciones"; fi ;;
      esac ;;

    motivo)
      case "$entrada" in
        ""|0|00) PANTALLA=lista; SEL_USR="" ;;
        1|01) bloquear "$SEL_USR" "no pagó"            && { PANTALLA=lista; SEL_USR=""; } ;;
        2|02) bloquear "$SEL_USR" "compartió la cuenta" && { PANTALLA=lista; SEL_USR=""; } ;;
        3|03) bloquear "$SEL_USR" "abuso de consumo"   && { PANTALLA=lista; SEL_USR=""; } ;;
        4|04) bloquear "$SEL_USR" "otro motivo"        && { PANTALLA=lista; SEL_USR=""; } ;;
        *)    AVISO="Elegí un motivo del 01 al 04, o 00 para volver" ;;
      esac ;;

    confirmar)
      case "$entrada" in
        ""|0|00) PANTALLA=lista; SEL_USR="" ;;
        1|01)    desbloquear "$SEL_USR" && { PANTALLA=lista; SEL_USR=""; } ;;
        *)       AVISO="Elegí 01 para desbloquear o 00 para volver" ;;
      esac ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    # Números para las cuentas, letras para las opciones. Una letra reemplaza
    # lo que hubiera: nadie escribe "3a", y si se equivocó de tecla es más
    # cómodo que se pise sola que tener que borrar.
    [0-9])         (( ${#BUF} < 4 )) && BUF="$BUF$1" ;;
    [a-eA-E])      BUF="$1" ;;
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