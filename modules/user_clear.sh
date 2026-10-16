#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.02 · BORRAR USUARIO(S)
#  Lista las cuentas, se marcan las que se quieren borrar y se confirma.
#  Uso:  bash modules/user_clear.sh
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
ui_exige banda cabecera cachear_cabecera datos_sistema seccion encabezado pad rpad volcar \
         kira_borrar_clave

if [ "$(id -u)" -ne 0 ]; then
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para borrar usuarios\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
POR_PAGINA=10
PAGINA=0
AVISO=""
PANTALLA=lista            # lista · confirmar · resultado
UMBRAL_VENCE=7

declare -a U_NOM=() U_VENCE=() U_VTO=() U_CONEX=() U_ESTADO=()
# OJO: las marcas van por NOMBRE DE USUARIO, no por posición en la lista.
# La pantalla se refresca sola, y si una cuenta vence o alguien se conecta,
# el orden puede cambiar entre un refresco y otro. Guardadas por posición,
# el [x] terminaría apuntando a OTRO usuario y se borraría al que no era.
declare -A MARCADA=() NOM_DE_UID=()
BORRADAS=0; FALLADAS=0
declare -a DETALLE=()

M_IZQ=$'\e[38;2;110;46;84m'      # rosa apagado
M_DER=$'\e[38;2;96;76;28m'       # ámbar apagado
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
# Conexiones abiertas por usuario. Igual que en el resto del panel: por DUEÑO
# del proceso, no por utmp, porque los túneles de HTTP Injector entran sin
# terminal y en utmp no figuran.
declare -A CON_USR=()
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
  U_NOM=(); U_VENCE=(); U_VTO=(); U_CONEX=(); U_ESTADO=(); NOM_DE_UID=()
  declare -A ES_CLIENTE=()

  local n uid resto
  while IFS=: read -r n resto uid resto; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid != 65534 )) || continue
    NOM_DE_UID[$uid]="$n"; ES_CLIENTE[$n]=1
  done < /etc/passwd

  cargar_conexiones

  # Qué cuentas son de prueba, para avisarlo en la lista: borrar una de ésas
  # no es lo mismo que borrar un cliente que pagó.
  declare -A ES_DEMO=()
  local du dt
  if [ -r "$DIR/db/demos" ]; then
    while read -r du dt; do [ -n "$du" ] && ES_DEMO[$du]=1; done < "$DIR/db/demos"
  fi

  local hoy; hoy=$(( $(date +%s) / 86400 ))
  local nom clave c3 c4 c5 c6 c7 vto est dias fecha epoca

  # Se recorre /etc/shadow, que es donde están la clave y el vencimiento.
  # OJO: shadow NO tiene el UID. Los campos son nombre, clave, último cambio,
  # mínimo, máximo, aviso, inactivo, VENCIMIENTO. Quién es cliente se decide
  # con la lista que se armó arriba desde passwd.
  while IFS=: read -r nom clave c3 c4 c5 c6 c7 vto resto; do
    [ -n "${ES_CLIENTE[$nom]:-}" ] || continue

    # shadow guarda el vencimiento como NÚMERO DE DÍA, no como fecha y hora.
    # La cuenta deja de andar a las 00:00 UTC de ese día, que en Lima son las
    # 19:00 del día anterior. Por eso se guarda el instante exacto en epoch y
    # se muestra en hora local: así la fecha que ves es cuando corta de verdad.
    if [[ "$vto" =~ ^[0-9]+$ ]]; then
      epoca=$(( vto * 86400 ))
      fecha=$(date -d "@$epoca" '+%d/%m/%Y' 2>/dev/null)
      dias=$(( vto - hoy ))
    else
      epoca=0; fecha="sin fecha"; dias=99999
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

    U_NOM+=("$nom"); U_VENCE+=("$fecha"); U_VTO+=("$epoca")
    U_CONEX+=("${CON_USR[$nom]:-0}"); U_ESTADO+=("$est")
  done < /etc/shadow
}

# Lo que falta para que la cuenta deje de andar. Se calcula al DIBUJAR, no
# al cargar: así baja de a un segundo sin tener que releer /etc/shadow.
cuenta_regresiva() { # $1=epoch del vencimiento
  local v="$1" ahora r d h m sg
  (( v == 0 )) && { printf '—'; return; }
  printf -v ahora '%(%s)T' -1
  r=$(( v - ahora ))
  # Ya vencida: 00:00:00 en vez de un texto. Mantiene la forma de la columna
  # y dice lo que hay que decir, que no le queda nada. Un "--:--:--" querría
  # decir "no se sabe", y sí se sabe.
  (( r <= 0 )) && { printf '00:00:00'; return; }
  # El reloj sólo se muestra cuando falta menos de dos días. Todas las cuentas
  # vencen en el MISMO instante del día (00:00 UTC), así que las horas,
  # minutos y segundos son idénticos en todas las filas: repetirlos en cada
  # renglón no dice nada y parece un error. Lo que de verdad distingue a una
  # cuenta de otra son los días.
  if (( r >= 172800 )); then
    d=$(( r / 86400 ))
    (( d >= 1000 )) && { printf '%dd' "$d"; return; }
    printf '%d días' "$d"; return
  fi
  # Menos de dos días: las horas NO se cortan en 24, siguen contando (31:20:59).
  # Así entra en la columna y encima se lee mejor: "le quedan 31 horas" dice
  # más que "1 día y 7 horas".
  h=$(( r / 3600 ));  r=$(( r % 3600 ))
  m=$(( r / 60 ));    sg=$(( r % 60 ))
  printf '%02d:%02d:%02d' "$h" "$m" "$sg"
}

marcadas_total() {
  local n=0 k
  for k in "${!MARCADA[@]}"; do [ "${MARCADA[$k]}" = 1 ] && (( n++ )); done
  printf '%s' "$n"
}
paginas() { local n=${#U_NOM[@]}; printf '%s' $(( (n + POR_PAGINA - 1) / POR_PAGINA )); }

# ============================================================== PANTALLA ====
# Fila de 78: 2 + nº 2 + 1 + marca 3 + 1 + usuario 20 + 1 + fecha 11
#             + 1 + días 9 + 1 + conex 7 + 1 + estado 18
cab_tabla() {
  fila_ancha "$(printf ' %s%s  %s  %s  %s  %s  %s  %s%s ' "$E_MUT" \
    "$(pad 'Nº' 2)" "$(pad 'SEL' 3)" "$(pad 'USUARIO' 18)" "$(pad 'FINALIZA' 10)" \
    "$(rpad 'TERMINA' 10)" "$(rpad 'CONEX' 5)" "$(rpad 'ESTADO' 12)" "$E_RST")"
}

color_estado() {
  case "$1" in
    vencida)         printf '%s' "$E_ERR" ;;
    bloqueada)       printf '%s' "$E_ERR" ;;
    pronto)          printf '%s' "$E_WARN" ;;
    prueba)          printf '%s' "$E_P2" ;;
    activa)          printf '%s' "$E_OK" ;;
    *)               printf '%s' "$E_MUT" ;;
  esac
}

fila_usuario() { # $1=índice global
  # Mismo cuidado de arriba: `n` no puede calcularse en la misma línea que
  # `i`, porque todavía no lo ve. Acá andaba de casualidad, porque el que
  # llama usa una variable que también se llama i.
  local i="$1" marca col fondo="" n
  n=$(( i + 1 ))
  if [ "${MARCADA[${U_NOM[i]}]:-}" = 1 ]; then marca="[x]"; fondo="$B_SEL"; else marca="[ ]"; fi
  col="$(color_estado "${U_ESTADO[i]}")"
  local resta; resta="$(cuenta_regresiva "${U_VTO[i]}")"
  # El color sale de la FECHA, no del texto: ahora que una vencida se escribe
  # 00:00:00, mirar la cadena ya no alcanza para distinguirla.
  local colr="$E_TXT" ahora_f falta
  printf -v ahora_f '%(%s)T' -1
  falta=$(( ${U_VTO[i]:-0} - ahora_f ))
  if   (( ${U_VTO[i]:-0} == 0 )); then colr="$E_MUT"
  elif (( falta <= 0 ));          then colr="$E_BLD$E_ERR"
  elif (( falta < 172800 ));      then colr="$E_BLD$E_WARN"
  fi
  fila_ancha "$(printf '%s %s%s%s  %s%s%s  %s%s%s  %s%s  %s%s%s  %s%s  %s%s%s %s' \
    "$fondo" "$E_BLD$E_P1" "$(pad "$n" 2)" "$E_RST$fondo" \
    "$E_BLD$E_ERR" "$marca" "$E_RST$fondo" \
    "$E_TXT" "$(pad "${U_NOM[i]}" 18)" "$E_RST$fondo" \
    "$E_MUT" "$(pad "${U_VENCE[i]}" 10)" \
    "$colr" "$(rpad "$resta" 10)" "$E_RST$fondo" \
    "$E_TXT" "$(rpad "${U_CONEX[i]}" 5)" \
    "$col" "$(rpad "${U_ESTADO[i]}" 12)" "$E_RST$fondo" "$E_RST")"
}

linea_aviso() {
  if [ -n "$AVISO" ]; then printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  else printf '  %s\n' "$(pad '' 76)"; fi
}

# ====================================================== MARCO A LO ANCHO ===
# La librería sólo trae cajas de media pantalla, de a pares. Acá hace falta
# una sola de 78, así que se arma a mano. Las cuentas: 2 de margen + 1 del
# borde + 74 de contenido + 1 del borde = 78.
M_TABLA=$'\e[38;2;110;46;84m'

techo_ancho() { # $1=título, centrado en el borde de arriba
  local t=" $1 " hueco izq der
  hueco=$(( 74 - ${#t} ))
  izq=$(( hueco / 2 )); der=$(( hueco - izq ))
  printf '  %s╭%s%s%s%s%s%s%s╮%s\n' "$M_TABLA" "$(rep '─' "$izq")" \
    "$E_RST$B_CHIP$E_BLD$E_PINK" "$t" "$E_RST$M_TABLA" "$(rep '─' "$der")" \
    "" "$M_TABLA" "$E_RST"
}
fila_ancha() { # $1=contenido ya medido en 74 columnas
  printf '  %s│%s%s%s│%s\n' "$M_TABLA" "$E_RST" "$1" "$M_TABLA" "$E_RST"
}
piso_ancho() { printf '  %s╰%s╯%s\n' "$M_TABLA" "$(rep '─' 74)" "$E_RST"; }

# Media fila de opción: 5 del número + 1 + 31 del texto = 37.
# El número va a ancho fijo porque "99" y "01-10" miden distinto y, sin
# igualarlos, la segunda columna queda escalonada.
opcion() { # $1=número $2=emoji $3=texto
  # Mismo ritmo que el menú principal: 2 del número + 1 + 2 del emoji + 1 +
  # 31 del texto = 37. El número iba a ancho 5 de cuando decía "41-46"; con
  # números de dos cifras eso dejaba al emoji flotando lejos.
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
# Fila entera: 2 + 5 + 1 + 70 = 78
opcion_ancha() { # $1=número $2=texto
  printf '  %s%s%s %s%s%s\n' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_BLD$E_TXT" "$(pad "$2" 73)" "$E_RST"
}

# La salida va sola, abajo y a todo el ancho, igual que en el menú principal:
# el 00 en rojo y con puerta. Compartiendo renglón con otra opción, el emoji
# le comería 3 columnas al texto y las dos columnas quedarían escalonadas.
# 2 + 5 del número + 1 + 2 del emoji + 2 + 66 del texto = 78
opcion_salir() {
  # 2 de margen + 2 del número + 1 + 2 del emoji + 1 + 70 del texto = 78
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_ERR" "$(pad '00' 2)" "$E_RST" \
    "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad 'VOLVER AL PANEL' 70)" "$E_RST"
}

# Debajo de la lista, de un vistazo: en qué página estás, cuántas hay y qué
# tocar para seguir. Sin esto no había forma de saber que había más cuentas
# más abajo; la lista terminaba y parecía que eso era todo.
# Los puntos son los mismos ● y ○ que el menú usa para ON y OFF.
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
  # Centrado a mano dentro de las 74 del marco: los códigos de color ocupan
  # caracteres pero no columnas, así que hay que medir el texto visible.
  local izq=$(( (74 - vis) / 2 ))
  (( izq < 1 )) && izq=1
  local der=$(( 74 - izq - vis ))
  (( der < 0 )) && der=0
  if (( vis > ${#medio} )); then
    fila_ancha "$(printf '%*s%s   %s%s%s%*s' "$izq" '' "$puntos" "$E_MUT" "$medio" "$E_RST" "$der" '')"
  else
    fila_ancha "$(printf '%*s%s%s%s%*s' "$izq" '' "$E_MUT" "$medio" "$E_RST" "$der" '')"
  fi
}

pintar_lista() {
  local total=${#U_NOM[@]} pags; pags=$(paginas)
  (( pags == 0 )) && pags=1
  # OJO: en `local a=$X b=$((a+1))` bash expande TODAS las asignaciones antes
  # de aplicar ninguna, así que b NO ve a `a`. Acá eso dejaba fin=10 siempre
  # y de la página 2 en adelante la lista salía vacía. Van en líneas aparte.
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
  encabezado "BORRAR USUARIOS" "KIRA v$KIRA_VER"
  echo
  techo_ancho "CUENTAS"
  cab_tabla
  if (( total == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'No hay cuentas de clientes en esta VPS.' 72)")"
  else
    for ((i=desde; i<fin; i++)); do fila_usuario "$i"; done
  fi
  # Relleno para que el marco no cambie de alto entre páginas
  for ((i=fin-desde; i<POR_PAGINA; i++)); do fila_ancha "$(pad '' 74)"; done
  indicador_paginas "$pags" "$desde" "$fin" "$total"
  piso_ancho
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad "Escribí el número de la cuenta para elegirla. Podés poner varias: $(( desde + 1 )) $(( desde + 2 ))" 76)" "$E_RST"
  echo
  local nsel; nsel=$(marcadas_total)
  local txt99='BORRAR LAS ELEGIDAS'
  (( nsel > 0 )) && txt99="BORRAR LAS ELEGIDAS ($nsel)"
  printf '  %s  %s\n' "$(opcion '99' '🧹' "$txt99")" "$(opcion '88' '⏩' 'PÁGINA SIGUIENTE')"
  printf '  %s  %s\n' "$(opcion '77' '⏪' 'PÁGINA ANTERIOR')" "$(pad '' 37)"
  opcion_salir
  echo
  linea_aviso
  prompt
}

pintar_confirmar() {
  local k i n=0
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BORRAR USUARIOS" "KIRA v$KIRA_VER"
  echo
  seccion "ESTO NO SE PUEDE DESHACER" "$E_ERR"
  echo
  printf '  %s%s%s\n' "$E_BLD$E_TXT" "$(pad "Se van a borrar estas $(marcadas_total) cuentas:" 76)" "$E_RST"
  echo
  for i in "${!U_NOM[@]}"; do
    [ "${MARCADA[${U_NOM[i]}]:-}" = 1 ] || continue
    (( n++ ))
    if (( n > 12 )); then
      printf '  %s%s%s\n' "$E_MUT" "$(pad "… y $(( $(marcadas_total) - 12 )) más" 76)" "$E_RST"
      break
    fi
    printf '  %s%s%s %s%s%s %s%s%s\n' \
      "$E_BLD$E_ERR" "$(pad '•' 2)" "$E_RST" \
      "$E_BLD$E_TXT" "$(pad "${U_NOM[i]}" 22)" "$E_RST" \
      "$E_MUT" "$(pad "${U_ESTADO[i]} · ${U_CONEX[i]} conexiones abiertas" 50)" "$E_RST"
  done
  for ((i=n; i<12; i++)); do printf '  %s\n' "$(pad '' 76)"; done
  echo
  printf '  %s%s%s\n' "$E_WARN" "$(pad 'Si están conectados, se les corta la conexión en el momento.' 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '01' '✅' 'SÍ, BORRARLAS')" "$(pad '' 37)"
  opcion_salir
  echo
  linea_aviso
  prompt
}

pintar_resultado() {
  local i n=0
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BORRAR USUARIOS" "KIRA v$KIRA_VER"
  echo
  seccion "RESULTADO" "$E_OK"
  echo
  printf '  %s%s%s\n' "$E_BLD$E_OK" "$(pad "✔ $BORRADAS cuentas borradas" 76)" "$E_RST"
  if (( FALLADAS > 0 )); then
    printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $FALLADAS no se pudieron borrar" 76)" "$E_RST"
  else
    printf '  %s\n' "$(pad '' 76)"
  fi
  echo
  for i in "${!DETALLE[@]}"; do
    (( n++ )); (( n > 14 )) && break
    printf '  %s%s%s\n' "$E_MUT" "$(pad "${DETALLE[i]}" 76)" "$E_RST"
  done
  for ((i=n; i<14; i++)); do printf '  %s\n' "$(pad '' 76)"; done
  echo
  opcion_salir
  echo
  linea_aviso
  prompt
}

pintar() {
  case "$PANTALLA" in
    confirmar)  pintar_confirmar ;;
    resultado)  pintar_resultado ;;
    *)          pintar_lista ;;
  esac
}

# El prompt se dibuja DENTRO del cuadro, con lo tecleado y un cursor propio.
# Antes se usaba `read -r` bloqueante: la pantalla quedaba congelada hasta que
# se apretaba ENTER, así que las conexiones y los días no se movían nunca.
prompt() {
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# Se lee tecla por tecla para poder repintar mientras tanto. Se aceptan
# espacios porque la idea es poder escribir varios números de una: "41 42".
procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    [0-9])         (( ${#BUF} < 24 )) && BUF="$BUF$1" ;;
    ' ')           [ -n "$BUF" ] && [ "${BUF: -1}" != " " ] && BUF="$BUF " ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;   # descarta flechas
  esac
}

# =============================================================== BORRADO ====
borrar_una() { # $1=nombre -> 0 ok, 1 error
  local u="$1" p c k v uid

  # Primero se le cortan las conexiones. Si quedan procesos suyos vivos,
  # userdel falla con "user is currently used by process" y la cuenta queda
  # a medio borrar: sin poder entrar pero todavía en el sistema.
  uid=$(id -u "$u" 2>/dev/null) || { DETALLE+=("$u · no existe"); return 1; }
  for p in /proc/[0-9]*; do
    [ -r "$p/comm" ] || continue
    read -r c < "$p/comm" 2>/dev/null || continue
    v=""
    while read -r k v _; do [ "$k" = "Uid:" ] && break; done < "$p/status" 2>/dev/null
    [ "$v" = "$uid" ] && kill -9 "${p##*/}" 2>/dev/null
  done
  sleep 0.2

  if ! userdel "$u" 2>/tmp/kira-del.err; then
    DETALLE+=("$u · $(head -1 /tmp/kira-del.err 2>/dev/null)")
    return 1
  fi

  # Y se lo saca de los archivos del panel, para que no quede un límite
  # huérfano que después se le aplique a otro usuario con el mismo nombre.
  local f tmp
  for f in "$DIR/db/limites" "$DIR/db/demos" "$DIR/db/consumo"; do
    [ -r "$f" ] || continue
    tmp="$f.tmp"
    grep -v "^$u " "$f" > "$tmp" 2>/dev/null
    mv -f "$tmp" "$f"
  done
  # Las claves van aparte: ese archivo tiene que quedar en 600 y el rodeo del
  # archivo temporal de arriba lo dejaría en 644, legible por cualquiera.
  kira_borrar_clave "$DIR" "$u"

  DETALLE+=("$u · borrada")
  return 0
}

borrar_marcadas() {
  BORRADAS=0; FALLADAS=0; DETALLE=()
  mkdir -p "$DIR/db"
  local i fecha; printf -v fecha '%(%F %H:%M)T' -1
  for i in "${!U_NOM[@]}"; do
    [ "${MARCADA[${U_NOM[i]}]:-}" = 1 ] || continue
    if borrar_una "${U_NOM[i]}"; then
      (( BORRADAS++ ))
      printf '%s %s\n' "$fecha" "${U_NOM[i]}" >> "$DIR/db/borrados"
    else
      (( FALLADAS++ ))
    fi
  done
  MARCADA=()
  cargar_cuentas
  PAGINA=0
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

BUF=""
SEG_ANT=0
CARGA_ANT=0

# Lo que hace cada opción, una vez que se apretó ENTER.
ejecutar() {
  local entrada="$1" tok idx nom_sel
  AVISO=""
  case "$PANTALLA" in
    lista)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        77) (( PAGINA > 0 )) && PAGINA=$(( PAGINA - 1 )) || AVISO="Ya estás en la primera página" ;;
        88) (( PAGINA + 1 < $(paginas) )) && PAGINA=$(( PAGINA + 1 )) || AVISO="Ya estás en la última página" ;;
        99) if (( $(marcadas_total) == 0 )); then AVISO="No elegiste ninguna cuenta"
            else PANTALLA=confirmar; fi ;;
        *)
          # Se aceptan varios números de una: "41 42 44"
          for tok in $entrada; do
            [[ "$tok" =~ ^[0-9]+$ ]] || { AVISO="Escribí números, o 00 para volver"; continue; }
            idx=$(( 10#$tok - 1 ))
            if (( idx >= 0 && idx < ${#U_NOM[@]} )); then
              nom_sel="${U_NOM[$idx]}"
              if [ "${MARCADA[$nom_sel]:-}" = 1 ]; then unset "MARCADA[$nom_sel]"
              else MARCADA[$nom_sel]=1; fi
            else
              AVISO="El número $tok no existe en la lista"
            fi
          done ;;
      esac ;;
    confirmar)
      case "$entrada" in
        1|01)    borrar_marcadas; PANTALLA=resultado ;;
        ""|0|00) PANTALLA=lista ;;
        *)       AVISO="Elegí 01 para borrar o 00 para volver" ;;
      esac ;;
    resultado)
      clear; exit 0 ;;
  esac
}

while true; do
  # Dos ritmos distintos, a propósito:
  #  · se REDIBUJA cada segundo, para que la cuenta regresiva baje de a uno;
  #    eso es sólo aritmética con la fecha ya guardada, no cuesta nada.
  #  · se RELEE /etc/shadow cada 5 segundos, que es lo caro y lo que casi
  #    nunca cambia. Releerlo una vez por segundo con 90 cuentas sería gastar
  #    al pedo para ver el mismo dato.
  # En la pantalla de confirmación no se recarga: ahí ya se decidió qué se
  # borra y la lista no debe cambiarse debajo de los pies.
  printf -v ahora '%(%s)T' -1
  redibujar=0
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; redibujar=1; fi
  if [ "$PANTALLA" = lista ] && (( ahora - CARGA_ANT >= 5 )); then
    cargar_cuentas
    CARGA_ANT=$ahora
    redibujar=1
    # Se sueltan las marcas de cuentas que ya no existen, para que no quede
    # elegida una que alguien borró por otro lado.
    for nom_sel in "${!MARCADA[@]}"; do
      hay=0
      for tok in "${U_NOM[@]}"; do [ "$tok" = "$nom_sel" ] && { hay=1; break; }; done
      (( hay )) || unset "MARCADA[$nom_sel]"
    done
  fi

  (( redibujar )) && render
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0          # stdin cerrado: salir en vez de girar en vacío
  fi
done