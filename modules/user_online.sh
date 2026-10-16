#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.05 · USUARIOS CONECTADOS
#  Quién está usando el servicio AHORA, desde qué IP, por qué puerto y desde
#  hace cuánto. Ordenado de más conexiones a menos: el que comparte la cuenta
#  queda primero, que es justo a quien estás buscando.
#  Uso:  bash modules/user_online.sh
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
POR_PAGINA=9
PAGINA=0
PANTALLA=lista            # lista · detalle · confirmar
SEL=-1
SEL_USR=""                # el elegido va por NOMBRE: la lista se reordena sola
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0; CARGA_ANT=0
HAY_PROXY=0               # alguien entra por 127.0.0.1 (SSL / WebSocket)

declare -a O_NOM=() O_CONEX=() O_IP1=() O_NIPS=() O_DESDE=() O_LIM=()
declare -A NOM_DE_UID=() LIMITE_DE=()
declare -a D_IP=() D_PUERTO=() D_SRV=() D_DESDE=()

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
# Una conexión = un proceso de sshd o dropbear corriendo COMO el usuario.
# (El por qué de contar así está explicado en modules/user.sh: `who` y `last`
# leen utmp, y un túnel de HTTP Injector entra sin terminal, así que en utmp
# no figura.) La IP del otro lado no está en /proc: eso sale de `ss`, cruzando
# por PID.
#
# OJO con el cruce: después de autenticar quedan DOS procesos con el mismo
# socket abierto — el padre, que sigue siendo de root, y el hijo, que ya es
# del usuario. `ss` puede nombrar a cualquiera de los dos, así que se guardan
# TODOS los pid de cada línea. Quedándose sólo con el primero, la mitad de las
# conexiones aparecían sin IP.
declare -A IP_DE_PID=() PTO_DE_PID=()
leer_sockets() {
  IP_DE_PID=(); PTO_DE_PID=()
  local pid pto ip
  # Sin -H: esa opción no existe en las versiones viejas de iproute2 y, si no
  # existe, `ss` no imprime NADA. El filtro por ESTAB ya descarta el título.
  while read -r pid pto ip; do
    [ -n "$pid" ] || continue
    IP_DE_PID[$pid]="$ip"; PTO_DE_PID[$pid]="$pto"
  done < <(ss -tnp 2>/dev/null | awk '
    # Columnas de `ss -tnp`:  1=State 2=Recv-Q 3=Send-Q 4=Local 5=Peer 6=Process
    $1 == "ESTAB" {
      loc = $4; rem = $5
      nl = split(loc, L, ":"); plocal = L[nl]
      nr = split(rem, R, ":"); ipr = rem; sub(":" R[nr] "$", "", ipr)
      gsub(/^\[|\]$/, "", ipr); sub(/^::ffff:/, "", ipr)
      if (plocal !~ /^[0-9]+$/) next
      resto = $0
      while (match(resto, /pid=[0-9]+/)) {
        print substr(resto, RSTART+4, RLENGTH-4), plocal, ipr
        resto = substr(resto, RSTART + RLENGTH)
      }
    }')
}

# Desde cuándo corre un proceso. El campo 22 de /proc/PID/stat son los tics
# desde que arrancó la máquina; btime de /proc/stat dice cuándo fue eso.
ARRANQUE=0; HZ=100
inicio_de() { # $1=/proc/PID  -> deja el resultado en INICIO
  local s resto
  INICIO=0
  read -r s < "$1/stat" 2>/dev/null || return
  resto="${s##*) }"
  local -a f=($resto)
  INICIO=$(( ARRANQUE + ${f[19]:-0} / HZ ))
}

servicio_de() { # $1=comm
  case "$1" in
    sshd|sshd-session|sshd-auth) printf 'SSH' ;;
    dropbear|dropbearmulti)      printf 'Dropbear' ;;
    *)                           printf '%s' "$1" ;;
  esac
}

es_local() { # $1=ip · una conexión que entra por loopback viene de un proxy
  case "$1" in 127.*|::1|'') return 0 ;; *) return 1 ;; esac
}

cargar() {
  O_NOM=(); O_CONEX=(); O_IP1=(); O_NIPS=(); O_DESDE=(); O_LIM=()
  NOM_DE_UID=(); LIMITE_DE=(); HAY_PROXY=0
  declare -A POR_USR=() IPS_USR=() PRIMERA=()

  local n uid resto
  while IFS=: read -r n resto uid resto; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid != 65534 )) || continue
    NOM_DE_UID[$uid]="$n"
  done < /etc/passwd

  local lu ll
  if [ -r "$DIR/db/limites" ]; then
    while read -r lu ll; do
      [ -n "$lu" ] && [[ "$ll" =~ ^[0-9]+$ ]] && LIMITE_DE[$lu]="$ll"
    done < "$DIR/db/limites"
  fi

  leer_sockets
  ARRANQUE=$(awk '/^btime/{print $2}' /proc/stat 2>/dev/null); [ -z "$ARRANQUE" ] && ARRANQUE=0
  HZ=$(getconf CLK_TCK 2>/dev/null); [ -z "$HZ" ] && HZ=100

  local p c k v u pid lip
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
    [ -n "$u" ] || continue
    pid="${p##*/}"

    inicio_de "$p"
    (( POR_USR[$u]++ ))
    if [ -z "${PRIMERA[$u]:-}" ] || (( INICIO < PRIMERA[$u] )); then PRIMERA[$u]=$INICIO; fi

    lip="${IP_DE_PID[$pid]:-}"
    if [ -n "$lip" ]; then
      es_local "$lip" && HAY_PROXY=1
      case " ${IPS_USR[$u]:-} " in
        *" $lip "*) ;;
        *) IPS_USR[$u]="${IPS_USR[$u]:-} $lip" ;;
      esac
    fi
  done

  # De más conexiones a menos.
  local linea x cuantas
  while read -r linea; do
    [ -z "$linea" ] && continue
    u="${linea#* }"
    O_NOM+=("$u")
    O_CONEX+=("${POR_USR[$u]}")
    cuantas=0
    for x in ${IPS_USR[$u]:-}; do (( cuantas++ )); done
    O_NIPS+=("$cuantas")
    set -- ${IPS_USR[$u]:-}
    O_IP1+=("${1:-—}")
    O_DESDE+=("${PRIMERA[$u]:-0}")
    O_LIM+=("${LIMITE_DE[$u]:-}")
  done < <(for u in "${!POR_USR[@]}"; do printf '%s %s\n' "${POR_USR[$u]}" "$u"; done | sort -rn)

  local tope=$(( (${#O_NOM[@]} + POR_PAGINA - 1) / POR_PAGINA ))
  (( tope == 0 )) && tope=1
  (( PAGINA >= tope )) && PAGINA=$(( tope - 1 ))

  # El elegido se vuelve a ubicar por nombre, no por posición.
  if [ -n "$SEL_USR" ]; then
    SEL=-1
    local i
    for i in "${!O_NOM[@]}"; do [ "${O_NOM[i]}" = "$SEL_USR" ] && { SEL=$i; break; }; done
  fi
}

# Las conexiones una por una del usuario elegido
cargar_detalle() { # $1=usuario
  D_IP=(); D_PUERTO=(); D_SRV=(); D_DESDE=()
  local u="$1" uid p c k v pid svc
  uid=$(id -u "$u" 2>/dev/null) || return
  leer_sockets
  for p in /proc/[0-9]*; do
    [ -r "$p/comm" ] || continue
    read -r c < "$p/comm" 2>/dev/null || continue
    case "$c" in
      sshd|sshd-session|sshd-auth|dropbear|dropbearmulti) ;;
      *) continue ;;
    esac
    v=""
    while read -r k v _; do [ "$k" = "Uid:" ] && break; done < "$p/status" 2>/dev/null
    [ "$v" = "$uid" ] || continue
    pid="${p##*/}"
    inicio_de "$p"
    svc="$(servicio_de "$c")"
    local ip="${IP_DE_PID[$pid]:-—}"
    es_local "$ip" && svc="$svc · proxy"
    D_IP+=("$ip"); D_PUERTO+=("${PTO_DE_PID[$pid]:-—}")
    D_SRV+=("$svc"); D_DESDE+=("$INICIO")
  done
}

# Siempre HH:MM:SS, con las horas sin cortar en 24. Es la misma forma que usa
# el módulo de borrar: así la columna queda alineada sola, sin que un "2h 15m"
# y un "45m" terminen uno debajo del otro con las letras cruzadas.
hace_cuanto() { # $1=epoch de inicio
  local t="$1" ahora r h m s
  (( t == 0 )) && { printf '—'; return; }
  printf -v ahora '%(%s)T' -1
  r=$(( ahora - t )); (( r < 0 )) && r=0
  h=$(( r / 3600 )); m=$(( (r % 3600) / 60 )); s=$(( r % 60 ))
  printf '%02d:%02d:%02d' "$h" "$m" "$s"
}

paginas() { local n=${#O_NOM[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

# Cortar = matar los procesos de sus conexiones. La cuenta no se toca: puede
# volver a entrar cuando quiera. Para que NO vuelva, hay que bloquearla.
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
# Fila de 74: 1 + nº 2 + 2 + usuario 18 + 2 + conex 5 + 2 + límite 6
#             + 2 + viene de 16 + 2 + ips 3 + 2 + conectado 10 + 1
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'USUARIO' 18)" "$(rpad 'CONEX' 5)" \
    "$(rpad 'LÍMITE' 6)" "$(pad 'VIENE DE' 16)" "$(rpad 'IPS' 3)" \
    "$(rpad 'CONECTADO' 10)" "$E_RST")"
}
fila_online() { # $1=número a mostrar $2=índice
  local n="$1" i="$2" lim txt_lim col_c col_ip col_l
  lim="${O_LIM[i]}"
  col_c="$E_BLD$E_OK"; col_l="$E_MUT"
  if [ -n "$lim" ]; then
    txt_lim="$lim"
    # Pasarse del límite significa que el vigilante todavía no lo cortó o que
    # el límite se fijó recién: en cualquier caso, hay que verlo en rojo.
    if (( ${O_CONEX[i]} > lim )); then col_c="$E_BLD$E_ERR"; col_l="$E_BLD$E_ERR"; fi
  else
    txt_lim="—"
  fi
  # Más de una IP es la señal de que la cuenta anda circulando entre varios.
  col_ip="$E_MUT"; (( ${O_NIPS[i]} > 1 )) && col_ip="$E_BLD$E_WARN"
  fila_ancha "$(printf ' %s%s%s  %s%s%s  %s%s  %s%s  %s%s  %s%s  %s%s%s ' \
    "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST" \
    "$E_TXT" "$(pad "${O_NOM[i]}" 18)" "$E_RST" \
    "$col_c" "$(rpad "${O_CONEX[i]}" 5)" \
    "$col_l" "$(rpad "$txt_lim" 6)" \
    "$E_INFO" "$(pad "${O_IP1[i]}" 16)" \
    "$col_ip" "$(rpad "${O_NIPS[i]}" 3)" \
    "$E_TXT" "$(rpad "$(hace_cuanto "${O_DESDE[i]}")" 10)" "$E_RST")"
}

pintar_lista() {
  local total=${#O_NOM[@]} pags; pags=$(paginas)
  local i desde fin
  desde=$(( PAGINA * POR_PAGINA ))
  fin=$(( desde + POR_PAGINA ))
  (( fin > total )) && fin=$total
  local conx=0
  for i in "${!O_CONEX[@]}"; do (( conx += O_CONEX[i] )); done

  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "USUARIOS CONECTADOS" "KIRA v$KIRA_VER"
  echo
  if   (( total == 0 )); then techo_ancho "NADIE CONECTADO AHORA MISMO"
  elif (( total == 1 )); then techo_ancho "1 EN LÍNEA · $conx CONEXIONES"
  else                        techo_ancho "$total EN LÍNEA · $conx CONEXIONES"; fi
  cab_tabla
  if (( total == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'No hay nadie conectado en este momento.' 72)")"
    for ((i=1; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  else
    for ((i=desde; i<fin; i++)); do fila_online $(( i + 1 )) "$i"; done
    for ((i=fin-desde; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  fi
  indicador_paginas "$pags" "$desde" "$fin" "$total"
  piso_ancho
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad 'Escribí el número de un usuario para ver desde dónde entra y cortarle.' 76)" "$E_RST"
  if (( HAY_PROXY )); then
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad 'Los que dicen 127.0.0.1 entran por SSL o WebSocket: su IP real no se ve.' 76)" "$E_RST"
  else
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad 'Dos IPS o más en la misma cuenta es la señal de que la están compartiendo.' 76)" "$E_RST"
  fi
  echo
  printf '  %s  %s\n' "$(opcion '77' '⏪' 'PÁGINA ANTERIOR')" "$(opcion '88' '⏩' 'PÁGINA SIGUIENTE')"
  opcion_salir
  echo
  linea_aviso
  prompt "Usuario:"
}

# El mismo indicador del módulo de borrar: los puntos dicen cuántas páginas
# hay y el texto va centrado abajo del todo.
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
  # Con la tabla vacía el renglón queda en blanco: el mensaje ya está adentro
  # del cuadro y repetirlo acá abajo no suma.
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

# Fila de 74: 1 + nº 2 + 2 + viene de 26 + 2 + puerto 7 + 2 + servicio 14
#             + 2 + conectado 15 + 1
MAX_DET=12
pintar_detalle() {
  local u="$SEL_USR" i lim=""
  (( SEL >= 0 )) && lim="${O_LIM[$SEL]}"
  local n=${#D_IP[@]}
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "USUARIOS CONECTADOS" "KIRA v$KIRA_VER"
  echo
  techo_ancho "$u · $n CONEXIONES · LÍMITE ${lim:-SIN TOPE}"
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'VIENE DE' 26)" "$(rpad 'PUERTO' 7)" \
    "$(pad 'SERVICIO' 14)" "$(rpad 'CONECTADO' 15)" "$E_RST")"
  local m=0 cip
  for i in "${!D_IP[@]}"; do
    (( m++ )); (( m > MAX_DET )) && break
    cip="$E_BLD$E_TXT"; es_local "${D_IP[i]}" && cip="$E_MUT"
    fila_ancha "$(printf ' %s%s%s  %s%s%s  %s%s  %s%s  %s%s%s ' \
      "$E_BLD$E_P1" "$(pad "$m" 2)" "$E_RST" \
      "$cip" "$(pad "${D_IP[i]}" 26)" "$E_RST" \
      "$E_P1" "$(rpad "${D_PUERTO[i]}" 7)" \
      "$E_MUT" "$(pad "${D_SRV[i]}" 14)" \
      "$E_TXT" "$(rpad "$(hace_cuanto "${D_DESDE[i]}")" 15)" "$E_RST")"
  done
  if (( m == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'Ya no tiene ninguna conexión abierta.' 72)")"
    m=1
  fi
  for ((i=m; i<MAX_DET; i++)); do fila_ancha "$(pad '' 74)"; done
  if (( n > MAX_DET )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad "y $(( n - MAX_DET )) conexiones más que no entran en pantalla" 72)")"
  else
    fila_ancha "$(pad '' 74)"
  fi
  piso_ancho
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  if [ -n "$lim" ] && (( n > lim )); then
    printf '  %s%s%s\n' "$E_BLD$E_WARN" \
      "$(pad "▸ Se pasó del límite: tiene $n abiertas y le tocan $lim." 76)" "$E_RST"
  else
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad 'Cortarle no borra la cuenta: puede volver a entrar cuando quiera.' 76)" "$E_RST"
  fi
  echo
  printf '  %s  %s\n' "$(opcion '01' '🔌' 'CORTARLE TODAS')" "$(pad '' 37)"
  opcion_salir "VOLVER A LA LISTA"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_confirmar() {
  local u="$SEL_USR" n=${#D_IP[@]}
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "USUARIOS CONECTADOS" "KIRA v$KIRA_VER"
  echo
  seccion "CORTAR CONEXIONES" "$E_ERR"
  echo
  printf '  %s%s%s\n' "$E_BLD$E_TXT" \
    "$(pad "Se le van a cortar las $n conexiones a $u." 76)" "$E_RST"
  echo
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'La cuenta sigue existiendo: puede volver a conectarse cuando quiera.' 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'Para que no vuelva, bloqueala desde el módulo 08.' 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '01' '✅' 'SÍ, CORTARLE')" "$(pad '' 37)"
  opcion_salir "NO, VOLVER"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar() {
  case "$PANTALLA" in
    detalle)   pintar_detalle ;;
    confirmar) pintar_confirmar ;;
    *)         pintar_lista ;;
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
        77) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        88) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        *)
          if [[ "$entrada" =~ ^[0-9]+$ ]]; then
            idx=$(( 10#$entrada - 1 ))
            if (( idx >= 0 && idx < ${#O_NOM[@]} )); then
              SEL=$idx; SEL_USR="${O_NOM[$idx]}"
              cargar_detalle "$SEL_USR"; PANTALLA=detalle
            else AVISO="El número $entrada no está en la lista"; fi
          else AVISO="Escribí el número de un usuario, o 00 para volver"; fi ;;
      esac ;;
    detalle)
      case "$entrada" in
        ""|0|00) PANTALLA=lista; SEL=-1; SEL_USR="" ;;
        1|01)
          if (( ${#D_IP[@]} == 0 )); then AVISO="Ya no tiene conexiones abiertas"
          else PANTALLA=confirmar; fi ;;
        *) AVISO="Elegí 01 para cortarle o 00 para volver" ;;
      esac ;;
    confirmar)
      case "$entrada" in
        1|01)
          n=$(cortar_conexiones "$SEL_USR")
          MENSAJE="$SEL_USR · se le cortaron $n conexiones"
          SEL=-1; SEL_USR=""; PANTALLA=lista; cargar ;;
        ""|0|00) PANTALLA=detalle ;;
        *)       AVISO="Elegí 01 para cortar o 00 para volver" ;;
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
  # El reloj de "CONECTADO" corre, así que se redibuja cada segundo. Los datos
  # se releen cada 3: recorrer /proc entero en cada vuelta es gasto al pedo.
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; redibujar=1; fi
  if (( ahora - CARGA_ANT >= 3 )); then
    case "$PANTALLA" in
      lista) cargar ;;
      detalle|confirmar) [ -n "$SEL_USR" ] && { cargar; cargar_detalle "$SEL_USR"; } ;;
    esac
    CARGA_ANT=$ahora; redibujar=1
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