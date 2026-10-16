#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.03 · EDITAR / RENOVAR
#  Se elige una cuenta de la lista y se la renueva, se le cambia la clave,
#  el límite de conexiones, o se la bloquea.
#  Uso:  bash modules/user_edit.sh
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
ui_exige banda cabecera cachear_cabecera datos_sistema seccion encabezado pad rpad volcar rep \
         kira_guardar_clave

if [ "$(id -u)" -ne 0 ]; then
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para editar usuarios\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
POR_PAGINA=10
PAGINA=0
PANTALLA=lista            # lista · editar · pedir
PIDE=""                   # qué se está pidiendo: dias · clave · limite
AVISO=""; MENSAJE=""
UMBRAL_VENCE=7
BUF=""; SEG_ANT=0; CARGA_ANT=0

declare -a U_NOM=() U_VENCE=() U_VTO=() U_VTODIA=() U_CONEX=() U_ESTADO=() U_LIMITE=()
declare -A CON_USR=() NOM_DE_UID=()

SEL=-1                    # índice de la cuenta elegida

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
    v=""
    while read -r k v _; do [ "$k" = "Uid:" ] && break; done < "$p/status" 2>/dev/null
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    u="${NOM_DE_UID[$v]:-}"
    [ -n "$u" ] && (( CON_USR[$u]++ ))
  done
}

cargar_cuentas() {
  U_NOM=(); U_VENCE=(); U_VTO=(); U_VTODIA=(); U_CONEX=(); U_ESTADO=(); U_LIMITE=()
  NOM_DE_UID=()
  declare -A ES_CLIENTE=() LIM=()

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

  declare -A ES_DEMO=()
  local du dt
  if [ -r "$DIR/db/demos" ]; then
    while read -r du dt; do [ -n "$du" ] && ES_DEMO[$du]=1; done < "$DIR/db/demos"
  fi

  local hoy; hoy=$(( $(date +%s) / 86400 ))
  local nom clave c3 c4 c5 c6 c7 vto est dias fecha epoca
  while IFS=: read -r nom clave c3 c4 c5 c6 c7 vto resto; do
    [ -n "${ES_CLIENTE[$nom]:-}" ] || continue

    if [[ "$vto" =~ ^[0-9]+$ ]]; then
      epoca=$(( vto * 86400 ))
      fecha=$(date -d "@$epoca" '+%d/%m/%Y' 2>/dev/null)
      dias=$(( vto - hoy ))
    else
      vto=0; epoca=0; fecha="sin fecha"; dias=99999
    fi

    case "$clave" in
      '!'*|'*'*) est="bloqueada" ;;
      '')        est="sin clave" ;;
      *)
        if   [ -n "${ES_DEMO[$nom]:-}" ]; then est="prueba"
        elif (( dias == 99999 ));         then est="sin límite"
        elif (( dias < 0 ));              then est="vencida"
        elif (( dias <= UMBRAL_VENCE ));  then est="pronto"
        else                                   est="activa"; fi ;;
    esac

    U_NOM+=("$nom"); U_VENCE+=("$fecha"); U_VTO+=("$epoca"); U_VTODIA+=("$vto")
    U_CONEX+=("${CON_USR[$nom]:-0}"); U_ESTADO+=("$est"); U_LIMITE+=("${LIM[$nom]:-}")
  done < /etc/shadow
}

paginas() { local n=${#U_NOM[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

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
  h=$(( r / 3600 ));  r=$(( r % 3600 ))
  m=$(( r / 60 ));    sg=$(( r % 60 ))
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
# 2 de margen + borde + 74 de contenido + borde = 78
techo_ancho() { # $1=título centrado
  local t=" $1 " hueco izq der
  hueco=$(( 74 - ${#t} ))
  izq=$(( hueco / 2 )); der=$(( hueco - izq ))
  printf '  %s╭%s%s%s%s%s%s%s╮%s\n' "$M_TABLA" "$(rep '─' "$izq")" \
    "$E_RST$B_CHIP$E_BLD$E_PINK" "$t" "$E_RST$M_TABLA" "$(rep '─' "$der")" \
    "" "$M_TABLA" "$E_RST"
}
fila_ancha() { printf '  %s│%s%s%s│%s\n' "$M_TABLA" "$E_RST" "$1" "$M_TABLA" "$E_RST"; }
piso_ancho() { printf '  %s╰%s╯%s\n' "$M_TABLA" "$(rep '─' 74)" "$E_RST"; }

opcion() { # $1=número $2=emoji $3=texto · 2 + 1 + 2 + 1 + 31 = 37
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
opcion_salir() { # $1=texto
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_ERR" "$(pad '00' 2)" "$E_RST" "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad "${1:-VOLVER AL PANEL}" 70)" "$E_RST"
}

linea_aviso() {
  if   [ -n "$AVISO" ];   then printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  elif [ -n "$MENSAJE" ]; then printf '  %s%s%s\n' "$E_BLD$E_OK"  "$(pad "✔ $MENSAJE" 76)" "$E_RST"
  else printf '  %s\n' "$(pad '' 76)"; fi
}

prompt() { # $1=etiqueta
  local et="${1:-Opción:}" vis
  vis=$(( 4 + ${#et} + 1 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%s%s%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$et" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

# =============================================================== PANTALLAS ==
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'USUARIO' 21)" "$(pad 'FINALIZA' 10)" \
    "$(rpad 'TERMINA' 10)" "$(rpad 'CONEX' 5)" "$(rpad 'ESTADO' 14)" "$E_RST")"
}
fila_usuario() { # $1=índice
  local i="$1" col colr n resta ahora_f falta
  n=$(( i + 1 ))
  col="$(color_estado "${U_ESTADO[i]}")"
  resta="$(cuenta_regresiva "${U_VTO[i]}")"
  printf -v ahora_f '%(%s)T' -1
  falta=$(( ${U_VTO[i]:-0} - ahora_f ))
  colr="$E_TXT"
  if   (( ${U_VTO[i]:-0} == 0 )); then colr="$E_MUT"
  elif (( falta <= 0 ));          then colr="$E_BLD$E_ERR"
  elif (( falta < 172800 ));      then colr="$E_BLD$E_WARN"
  fi
  fila_ancha "$(printf ' %s%s%s  %s%s%s  %s%s  %s%s%s  %s%s  %s%s%s ' \
    "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST" \
    "$E_TXT" "$(pad "${U_NOM[i]}" 21)" "$E_RST" \
    "$E_MUT" "$(pad "${U_VENCE[i]}" 10)" \
    "$colr" "$(rpad "$resta" 10)" "$E_RST" \
    "$E_TXT" "$(rpad "${U_CONEX[i]}" 5)" \
    "$col" "$(rpad "${U_ESTADO[i]}" 14)" "$E_RST")"
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
  local medio="mostrando $(( desde + 1 ))-$fin de $total"
  vis=$(( vis + ${#medio} ))
  local izq=$(( (74 - vis) / 2 )); (( izq < 1 )) && izq=1
  local der=$(( 74 - izq - vis )); (( der < 0 )) && der=0
  if (( vis > ${#medio} )); then
    fila_ancha "$(printf '%*s%s   %s%s%s%*s' "$izq" '' "$puntos" "$E_MUT" "$medio" "$E_RST" "$der" '')"
  else
    fila_ancha "$(printf '%*s%s%s%s%*s' "$izq" '' "$E_MUT" "$medio" "$E_RST" "$der" '')"
  fi
}

pintar_lista() {
  local total=${#U_NOM[@]} pags; pags=$(paginas)
  (( pags == 0 )) && pags=1
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
  encabezado "EDITAR / RENOVAR" "KIRA v$KIRA_VER"
  echo
  techo_ancho "CUENTAS"
  cab_tabla
  if (( total == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'No hay cuentas de clientes en esta VPS.' 72)")"
  else
    for ((i=desde; i<fin; i++)); do fila_usuario "$i"; done
  fi
  for ((i=fin-desde; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  indicador_paginas "$pags" "$desde" "$fin" "$total"
  piso_ancho
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad "Escribí el número de la cuenta que querés editar o renovar." 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '77' '⏪' 'PÁGINA ANTERIOR')" "$(opcion '88' '⏩' 'PÁGINA SIGUIENTE')"
  opcion_salir
  echo
  linea_aviso
  prompt "Cuenta:"
}

fil_dato() { # $1=etiqueta $2=color $3=valor · 1 + 16 + 56 + 1 = 74
  fila_ancha "$(printf ' %s%s%s%s%s ' "$E_MUT" "$(pad "$1" 16)" "$E_RST$2" "$(pad "$3" 56)" "$E_RST")"
}

pintar_editar() {
  local i="$SEL" lim txt_lim col
  lim="${U_LIMITE[i]}"
  if [ -z "$lim" ]; then txt_lim="sin límite"
  else txt_lim="${U_CONEX[i]} abiertas de $lim permitidas"; fi
  col="$(color_estado "${U_ESTADO[i]}")"

  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "EDITAR / RENOVAR" "KIRA v$KIRA_VER"
  echo
  techo_ancho "${U_NOM[i]}"
  fil_dato "ESTADO"      "$E_BLD$col"   "${U_ESTADO[i]}"
  fil_dato "FINALIZA"    "$E_BLD$E_TXT" "${U_VENCE[i]}"
  fil_dato "TERMINA EN"  "$E_BLD$E_P1"  "$(cuenta_regresiva "${U_VTO[i]}")"
  fil_dato "CONEXIONES"  "$E_TXT"       "$txt_lim"
  piso_ancho
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion '01' '🔄' 'RENOVAR 30 DÍAS')" "$(opcion '02' '🔄' 'RENOVAR 60 DÍAS')"
  printf '  %s  %s\n' "$(opcion '03' '🔄' 'RENOVAR 90 DÍAS')" "$(opcion '04' '📅' 'RENOVAR OTROS DÍAS')"
  printf '  %s  %s\n' "$(opcion '05' '🔑' 'CAMBIAR CONTRASEÑA')" "$(opcion '06' '🚦' 'CAMBIAR LÍMITE')"
  if [ "${U_ESTADO[i]}" = bloqueada ]; then
    printf '  %s  %s\n' "$(opcion '07' '🔓' 'DESBLOQUEAR CUENTA')" "$(pad '' 37)"
  else
    printf '  %s  %s\n' "$(opcion '07' '🔒' 'BLOQUEAR CUENTA')" "$(pad '' 37)"
  fi
  opcion_salir "VOLVER A LA LISTA"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_pedir() {
  local i="$SEL" et ayuda
  case "$PIDE" in
    dias)   et="Días:";       ayuda="Cuántos días sumarle. Entre 1 y 3650." ;;
    clave)  et="Contraseña:"; ayuda="ENTER solo = genero una al azar, fácil de dictar." ;;
    limite) et="Límite:";     ayuda="Cuántos dispositivos puede usar a la vez. 0 = sin límite." ;;
  esac
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "EDITAR / RENOVAR" "KIRA v$KIRA_VER"
  echo
  techo_ancho "${U_NOM[i]}"
  fil_dato "ESTADO"     "$E_BLD$(color_estado "${U_ESTADO[i]}")" "${U_ESTADO[i]}"
  fil_dato "FINALIZA"   "$E_BLD$E_TXT" "${U_VENCE[i]}"
  fil_dato "TERMINA EN" "$E_BLD$E_P1"  "$(cuenta_regresiva "${U_VTO[i]}")"
  piso_ancho
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s%s%s\n' "$E_MUT" "$(pad "$ayuda" 76)" "$E_RST"
  echo
  opcion_salir "CANCELAR"
  echo
  linea_aviso
  prompt "$et"
}

pintar() {
  case "$PANTALLA" in
    editar) pintar_editar ;;
    pedir)  pintar_pedir ;;
    *)      pintar_lista ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# ================================================================ ACCIONES ==
clave_azar() {
  local s
  s=$(LC_ALL=C tr -dc 'a-km-np-z2-9' < /dev/urandom 2>/dev/null | head -c 8)
  [ -z "$s" ] && s="kira$RANDOM"
  printf '%s' "$s"
}

# Corta las conexiones abiertas de un usuario. Devuelve cuántas cortó.
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
    v=""
    while read -r k v _; do [ "$k" = "Uid:" ] && break; done < "$p/status" 2>/dev/null
    [ "$v" = "$uid" ] && { kill -9 "${p##*/}" 2>/dev/null && n=$(( n + 1 )); }
  done
  printf '%s' "$n"
}

renovar() { # $1=días a sumar
  local n="$1" hoy base nuevo fecha u="${U_NOM[$SEL]}"
  hoy=$(( $(date +%s) / 86400 ))
  base="${U_VTODIA[$SEL]}"
  # Si todavía está viva, se suma AL VENCIMIENTO que tiene: el cliente pagó
  # 30 días más, no 30 desde hoy. Si ya venció, se cuenta desde hoy, porque
  # sumarle a una fecha pasada le daría menos días de los que pagó.
  if (( base <= hoy )); then base=$hoy; fi
  nuevo=$(( base + n ))
  # OJO: la fecha va en UTC. Pasándole la fecha local, chage guarda un día
  # menos, porque convierte a días contando desde medianoche UTC.
  fecha=$(date -u -d "@$(( nuevo * 86400 ))" +%F 2>/dev/null)
  if [ -z "$fecha" ]; then AVISO="No pude calcular la fecha"; return 1; fi
  if chage -E "$fecha" "$u" 2>/tmp/kira-edit.err; then
    MENSAJE="$u renovado $n días · ahora termina el $(date -d "@$(( nuevo * 86400 ))" '+%d/%m/%Y')"
    cargar_cuentas
    return 0
  fi
  AVISO="No se pudo renovar: $(head -1 /tmp/kira-edit.err 2>/dev/null)"
  return 1
}

cambiar_clave() { # $1=clave
  local c="$1" u="${U_NOM[$SEL]}"
  [ -z "$c" ] && c="$(clave_azar)"
  case "$c" in
    *:*)  AVISO="La contraseña no puede llevar dos puntos ( : )"; return 1 ;;
    *\ *) AVISO="La contraseña no puede llevar espacios"; return 1 ;;
  esac
  (( ${#c} < 4 )) && { AVISO="Muy corta: mínimo 4 caracteres"; return 1; }
  # printf es builtin: la clave no aparece en la lista de procesos.
  if printf '%s:%s\n' "$u" "$c" | chpasswd 2>/tmp/kira-edit.err; then
    # Y se le cortan las conexiones que ya tenía abiertas. Cambiar la clave
    # NO las tira: siguen vivas con la clave vieja y siguen ocupando el cupo
    # del límite, así que al reconectar con la clave nueva el control de
    # conexiones lo rechaza y parece que la clave no funcionara.
    # Se guarda para poder mostrarla después en el padrón: /etc/shadow sólo
    # tiene el hash y de ahí no se recupera el texto.
    kira_guardar_clave "$DIR" "$u" "$c"
    local n; n=$(cortar_conexiones "$u")
    if (( n > 0 )); then
      MENSAJE="$u · clave nueva: $c · se cortaron $n conexiones viejas"
    else
      MENSAJE="$u · contraseña nueva: $c"
    fi
    cargar_cuentas
    return 0
  fi
  AVISO="No se pudo cambiar: $(head -1 /tmp/kira-edit.err 2>/dev/null)"
  return 1
}

cambiar_limite() { # $1=número
  local l="$1" u="${U_NOM[$SEL]}" tmp
  [[ "$l" =~ ^[0-9]+$ ]] || { AVISO="Escribí sólo números"; return 1; }
  (( 10#$l > 99 )) && { AVISO="El límite no puede pasar de 99"; return 1; }
  mkdir -p "$DIR/db"; touch "$DIR/db/limites"
  tmp="$DIR/db/.limites.tmp"
  grep -v "^$u " "$DIR/db/limites" > "$tmp" 2>/dev/null
  if (( 10#$l > 0 )); then
    printf '%s %s\n' "$u" $(( 10#$l )) >> "$tmp"
    MENSAJE="$u · ahora puede usar $(( 10#$l )) conexiones a la vez"
  else
    MENSAJE="$u · queda sin límite de conexiones"
  fi
  mv -f "$tmp" "$DIR/db/limites"
  cargar_cuentas
  return 0
}

alternar_bloqueo() {
  local u="${U_NOM[$SEL]}"
  if [ "${U_ESTADO[$SEL]}" = bloqueada ]; then
    if usermod -U "$u" 2>/tmp/kira-edit.err; then MENSAJE="$u desbloqueado"
    else AVISO="No se pudo desbloquear: $(head -1 /tmp/kira-edit.err 2>/dev/null)"; return 1; fi
  else
    if usermod -L "$u" 2>/tmp/kira-edit.err; then MENSAJE="$u bloqueado · no puede conectarse"
    else AVISO="No se pudo bloquear: $(head -1 /tmp/kira-edit.err 2>/dev/null)"; return 1; fi
  fi
  cargar_cuentas
  return 0
}

# Después de recargar, el índice elegido puede apuntar a otra cuenta si la
# lista cambió. Se vuelve a buscar por NOMBRE, que es lo que no se mueve.
reubicar() { # $1=nombre
  local i
  for i in "${!U_NOM[@]}"; do
    [ "${U_NOM[i]}" = "$1" ] && { SEL=$i; return 0; }
  done
  SEL=-1; PANTALLA=lista; AVISO="La cuenta $1 ya no existe"
  return 1
}

ejecutar() {
  local entrada="$1" idx nom
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    lista)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        77) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        88) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        *)
          if [[ "$entrada" =~ ^[0-9]+$ ]]; then
            idx=$(( 10#$entrada - 1 ))
            if (( idx >= 0 && idx < ${#U_NOM[@]} )); then SEL=$idx; PANTALLA=editar
            else AVISO="El número $entrada no existe en la lista"; fi
          else
            AVISO="Escribí el número de una cuenta, o 00 para volver"
          fi ;;
      esac ;;
    editar)
      nom="${U_NOM[$SEL]}"
      case "$entrada" in
        ""|0|00) PANTALLA=lista; SEL=-1 ;;
        1|01) renovar 30 && reubicar "$nom" ;;
        2|02) renovar 60 && reubicar "$nom" ;;
        3|03) renovar 90 && reubicar "$nom" ;;
        4|04) PIDE=dias;   PANTALLA=pedir ;;
        5|05) PIDE=clave;  PANTALLA=pedir ;;
        6|06) PIDE=limite; PANTALLA=pedir ;;
        7|07) alternar_bloqueo && reubicar "$nom" ;;
        *)    AVISO="Elegí una opción de la lista" ;;
      esac ;;
    pedir)
      nom="${U_NOM[$SEL]}"
      # Sólo "00" cancela, no "0" a secas: en el límite, 0 es un valor válido
      # y significa "sin límite". Tomándolo como cancelar era imposible
      # sacarle el tope a una cuenta.
      if [ "$entrada" = "00" ]; then PANTALLA=editar; PIDE=""; return; fi
      case "$PIDE" in
        dias)
          if [[ "$entrada" =~ ^[0-9]+$ ]] && (( 10#$entrada >= 1 && 10#$entrada <= 3650 )); then
            renovar $(( 10#$entrada )) && { reubicar "$nom"; PANTALLA=editar; PIDE=""; }
          else AVISO="Días: entre 1 y 3650"; fi ;;
        clave)
          cambiar_clave "$entrada" && { reubicar "$nom"; PANTALLA=editar; PIDE=""; } ;;
        limite)
          cambiar_limite "$entrada" && { reubicar "$nom"; PANTALLA=editar; PIDE=""; } ;;
      esac ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;
    *)
      # En la pantalla que pide una contraseña hay que aceptar letras y
      # símbolos; en las demás, sólo números.
      if [ "$PANTALLA" = pedir ] && [ "$PIDE" = clave ]; then
        case "$1" in [[:print:]]) (( ${#BUF} < 40 )) && BUF="$BUF$1" ;; esac
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