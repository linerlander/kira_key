#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.06 · BANNER SSH
#  El mensaje que ve el cliente al conectarse.
#
#  SOBRE EL COLOR. El banner viaja como texto antes de que el cliente se
#  autentique, pero las apps de túnel (HTTP Injector y compañía) lo muestran
#  en una ventana de Android y le pasan el texto por el intérprete de HTML del
#  sistema. Por eso el color se pone con etiquetas <font color="#RRGGBB">, que
#  es lo que usa todo el ambiente, y NO con códigos de color de terminal: esos
#  sí llegan crudos y se ven como basura.
#
#  Una terminal común (PuTTY, el ssh de la compu) no interpreta HTML y muestra
#  las etiquetas a la vista. Por eso el color se puede apagar con la opción 05
#  y queda el mismo banner en texto pelado.
#
#  Uso:  bash modules/ssh_banner.sh
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
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para cambiar el banner\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
ARCHIVO="/etc/kira-banner.txt"
SSHD="/etc/ssh/sshd_config"
DROPIN="/etc/ssh/sshd_config.d"
DB_DEFAULT="/etc/default/dropbear"
MAX_LINEAS=9
ANCHO_LINEA=30

PANTALLA=inicio           # inicio · escribir · plantillas · confirmar
ACCION=""
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0
ORIGEN=""; BANNER_FILE=""
HAY_DROPBEAR=0; DB_LISTO=0
MODO_APP=1                # 1 = con etiquetas y color · 0 = texto pelado
CENTRADO=1                # 1 = el banner va centrado en la pantalla
PLANT_SEL=1
PLANT_N=10
declare -a LINEAS=()      # lo que hay guardado, tal cual está en el archivo
declare -a NUEVO=()       # lo que se está escribiendo
declare -a RESPALDOS=()   # "archivo|copia" para poder volver atrás

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ============================================================ PALETA WEB ====
# Tonos medios a propósito: se leen tanto sobre fondo oscuro como sobre fondo
# claro, porque no sabemos con qué tema tiene la app cada cliente. Por eso
# tampoco se usa blanco ni negro: cualquiera de los dos desaparece en la mitad
# de los equipos.
# Colores BRILLANTES. La ventana donde la app muestra el mensaje es oscura, y
# los tonos medios que había antes salían apagados. Estos son los mismos que
# usan los banners que se ven bien en el ambiente.
declare -A BC=(
  [verde]="00FF00"   [amarillo]="FFFF00" [cian]="00FFFF"
  [rosa]="FF55FF"    [rojo]="FF5555"     [naranja]="FFAA00"
  [blanco]="FFFFFF"  [violeta]="AA88FF"  [azul]="55AAFF"
)
ansi_de_hex() { # $1=RRGGBB · el mismo tono, para la vista previa
  local h="$1"
  [ "${#h}" -ne 6 ] && h="00B8D4"
  printf '\e[1m\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# ====================================================== TEXTO Y ETIQUETAS ===
# Nombres de color que puede traer un banner viejo hecho con otro panel.
nombre_a_hex() { # $1=nombre o #hex
  local c="${1,,}"
  case "$c" in
    '#'*)              printf '%s' "${c#\#}" ;;
    red)               printf 'E53935' ;;
    green|lime)        printf '00A86B' ;;
    blue)              printf '1E88E5' ;;
    yellow|orange|gold) printf 'FF8F00' ;;
    cyan|aqua)         printf '00B8D4' ;;
    magenta|fuchsia|pink) printf 'EC407A' ;;
    purple|violet)     printf '7C4DFF' ;;
    white)             printf 'E2E8F0' ;;
    gray|grey)         printf '64748B' ;;
    *)                 printf '00B8D4' ;;
  esac
}

# El texto sin ninguna etiqueta: es lo que hay que medir para que el marco de
# la vista previa cierre donde tiene que cerrar.
sin_etiquetas() { # $1=línea
  local t="$1"
  # El <br> del final cierra ESTE renglón, no agrega nada: se tira. Los que
  # quedaran en el medio sí son un espacio. Si no se distinguen, el de la
  # punta deja un espacio de sobra y el marco de la vista previa se corre
  # una columna.
  t="${t%<br>}"
  t="${t//<br>/ }"; t="${t//<BR>/ }"; t="${t//<br\/>/ }"; t="${t//<br \/>/ }"
  while [[ "$t" == *"<"*">"* ]]; do t="${t%%<*}${t#*>}"; done
  t="${t//$'\e'/}"
  t="${t//&nbsp;/ }"; t="${t//&amp;/&}"; t="${t//&lt;/<}"; t="${t//&gt;/>}"
  t="${t//$'\t'/ }"; t="${t//$'\r'/}"
  while [[ "$t" == *' ' ]]; do t="${t% }"; done
  printf '%s' "$t"
}

# Lo mismo, pero DEJANDO el color: las etiquetas HTML se cambian por los
# códigos que entiende la terminal, nada más que para dibujar la vista previa.
# Así lo que ves en el recuadro es lo que ve tu cliente en el celular, en vez
# de un montón de etiquetas.
colorear() { # $1=línea
  local t="$1" salida="" resto eti hex
  t="${t%<br>}"
  t="${t//<br>/ }"; t="${t//<BR>/ }"; t="${t//<br\/>/ }"; t="${t//<br \/>/ }"
  t="${t//$'\e'/}"; t="${t//$'\t'/ }"; t="${t//$'\r'/}"
  resto="$t"
  while [[ "$resto" == *"<"*">"* ]]; do
    salida="$salida${resto%%<*}"            # lo que hay antes de la etiqueta
    resto="${resto#*<}"
    eti="${resto%%>*}"                      # la etiqueta, sin < ni >
    resto="${resto#*>}"
    case "${eti,,}" in
      font*color=*)
        hex="${eti#*=}"; hex="${hex//\"/}"; hex="${hex//\'/}"; hex="${hex%% *}"
        salida="$salida$(ansi_de_hex "$(nombre_a_hex "$hex")")" ;;
      /font)      salida="$salida$E_RST$E_BLD$E_TXT" ;;
      b|strong)   salida="$salida$E_BLD" ;;
      /b|/strong) salida="$salida$E_RST$E_TXT" ;;
      i|em)       salida="$salida"$'\e[3m' ;;
      /i|/em)     salida="$salida"$'\e[23m' ;;
      tt|/tt)     ;;   # la terminal ya es de ancho fijo: no hay nada que hacer
      div*|/div)  ;;   # el centrado lo resuelve la vista previa, no la etiqueta
    esac
  done
  salida="$salida$resto"
  salida="${salida//&nbsp;/ }"; salida="${salida//&amp;/&}"
  salida="${salida//&lt;/<}";   salida="${salida//&gt;/>}"
  printf '%s' "$salida"
}

# ========================================================= ANCHO CON EMOJIS =
# pad() de la librería cuenta CARACTERES, y un emoji ocupa DOS columnas. Con
# tres emojis en un renglón, el borde derecho del marco se corre tres lugares.
# El truco para medirlo barato: se sacan de un saque todos los caracteres
# anchos con una sola expansión, y la diferencia de largo dice cuántos había.
ANCHO_V=0
ancho_visual() { # $1=texto -> deja el resultado en ANCHO_V
  local s="$1" sin n
  n=${#s}
  sin="${s//[$'\U1F300'-$'\U1FAFF']/}"   # ahí viven casi todos los emojis
  n=$(( n + ${#s} - ${#sin} ))
  sin="${s//[✅⭐]/}"                      # los pocos que caen fuera del rango
  n=$(( n + ${#s} - ${#sin} ))
  ANCHO_V=$n
}
pad_v() { # $1=texto $2=columnas · recorta y rellena contando los emojis
  local s="$1" w="$2"
  ancho_visual "$s"
  while (( ANCHO_V > w )) && (( ${#s} > 0 )); do
    s="${s:0:${#s}-1}"; ancho_visual "$s"
  done
  printf '%s%*s' "$s" $(( w - ANCHO_V )) ''
}

# ================================================================ DATOS =====
# De dónde sale el banner que se está usando DE VERDAD. No alcanza con mirar
# sshd_config: las distros nuevas traen "Include /etc/ssh/sshd_config.d/*.conf"
# arriba de todo, y OpenSSH se queda con el PRIMER valor que encuentra. Si el
# proveedor dejó un Banner ahí adentro, el de sshd_config no se usa nunca.
#
# OJO: esta función NO imprime el resultado, lo deja en dos variables. Si
# imprimiera y se llamara con $( ), eso corre en un subshell y el ORIGEN que
# asigna se perdería al volver.
banner_actual() {
  ORIGEN=""; BANNER_FILE=""
  local f linea
  if [ -d "$DROPIN" ]; then
    for f in "$DROPIN"/*.conf; do
      [ -r "$f" ] || continue
      linea=$(awk 'tolower($1)=="banner" && $2!="none" {print $2; exit}' "$f" 2>/dev/null)
      [ -n "$linea" ] && { ORIGEN="$f"; BANNER_FILE="$linea"; return; }
    done
  fi
  linea=$(awk 'tolower($1)=="banner" && $2!="none" {print $2; exit}' "$SSHD" 2>/dev/null)
  [ -n "$linea" ] && { ORIGEN="$SSHD"; BANNER_FILE="$linea"; }
}

cargar() {
  LINEAS=()
  local l
  banner_actual
  [ -n "$BANNER_FILE" ] && [ -r "$BANNER_FILE" ] && \
    while IFS= read -r l; do LINEAS+=("$l"); done < "$BANNER_FILE"

  HAY_DROPBEAR=0; DB_LISTO=0
  if [ -s /etc/dropbear/dropbear.conf ] || [ -r "$DB_DEFAULT" ] || \
     command -v dropbear >/dev/null 2>&1; then
    HAY_DROPBEAR=1
    grep -q -- "-b $ARCHIVO" "$DB_DEFAULT" 2>/dev/null && DB_LISTO=1
  fi
}

tiene_color() {
  local l
  for l in "${LINEAS[@]}"; do case "${l,,}" in *'<font'*) return 0 ;; esac; done
  return 1
}
tiene_etiquetas() {
  local l
  for l in "${LINEAS[@]}"; do case "$l" in *'<'*'>'*) return 0 ;; esac; done
  return 1
}
# Los códigos de color de TERMINAL sí son un problema: ninguna app de túnel
# los interpreta y llegan crudos a la pantalla del cliente.
tiene_ansi() {
  local l
  for l in "${LINEAS[@]}"; do case "$l" in *$'\e'*) return 0 ;; esac; done
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

opcion() { # $1=número $2=emoji $3=texto
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
}
opcion_off() {
  printf '%s%s%s %s%s%s %s%s%s' "$E_MUT" "$(pad "$1" 2)" "$E_RST" \
         "$E_MUT" "$2" "$E_RST" "$E_MUT" "$(pad "$3" 31)" "$E_RST"
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
# La vista previa muestra el banner como lo muestra el celular: las etiquetas
# se traducen a códigos de terminal nada más que para dibujar el recuadro.
# Confirmado contra HTTP Injector: color, negrita y cursiva se ven.
# Convierte lo que hay en el ARCHIVO en los renglones que el CLIENTE ve. No
# es lo mismo: la app toma los saltos de línea de verdad como simples espacios
# y corta donde encuentra un <br> o donde termina un bloque. Si la vista
# previa partiera por las líneas del archivo, mostraría otra cosa.
declare -a RENGLONES=()
expandir() { # $@ = líneas del archivo
  RENGLONES=()
  local l todo="" hay_html=0
  for l in "$@"; do
    case "$l" in *'<br>'*|*'<BR>'*|*'<div'*|*'<p '*|*'<p>'*) hay_html=1 ;; esac
  done
  if (( ! hay_html )); then
    for l in "$@"; do RENGLONES+=("$l"); done
    return
  fi
  for l in "$@"; do todo="$todo$l"; done
  todo="${todo//<br>/$'\n'}"; todo="${todo//<BR>/$'\n'}"
  todo="${todo//<br\/>/$'\n'}"; todo="${todo//<br \/>/$'\n'}"
  todo="${todo//<\/div>/$'\n'}"; todo="${todo//<\/p>/$'\n'}"
  while IFS= read -r l; do
    # el cierre del último bloque deja un renglón vacío al final
    [ -z "$l" ] && continue
    RENGLONES+=("$l")
  done <<< "$todo"
}

vista_previa() { # $@ = líneas tal cual van al archivo
  local l n=0 txt pintada
  expandir "$@"
  for l in "${RENGLONES[@]}"; do
    (( n++ )); (( n > MAX_LINEAS )) && break
    txt="$(sin_etiquetas "$l")"
    ancho_visual "$txt"
    if (( ANCHO_V > 68 )); then
      fila_ancha "$(printf '   %s%s   ' "$E_BLD$E_TXT" "$(pad_v "$txt" 68)")"
    else
      pintada="$(colorear "$l")"
      # Si el banner va centrado, la vista previa también lo centra: el hueco
      # que sobra se reparte entre los dos lados en vez de irse todo al de la
      # derecha. Es la única forma de que lo que ves acá sea lo que vas a ver
      # en el celular.
      local izq=0 der
      if (( CENTRADO )); then izq=$(( (68 - ANCHO_V) / 2 )); fi
      der=$(( 68 - ANCHO_V - izq ))
      fila_ancha "$(printf '   %*s%s%s%s%*s   ' "$izq" '' "$E_BLD$E_TXT" "$pintada" "$E_RST" "$der" '')"
    fi
  done
  if (( n == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'Sin banner: el cliente no ve ningún mensaje al conectarse.' 72)")"
    n=1
  fi
  local i
  for ((i=n; i<MAX_LINEAS; i++)); do fila_ancha "$(pad '' 74)"; done
}

diagnostico() {
  if tiene_ansi; then
    printf '  %s%s%s\n' "$E_BLD$E_ERR" \
      "$(pad '✖ Tiene códigos de color de terminal: el celular los ve como basura.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad '  La opción 03 los saca y deja el texto limpio.' 76)" "$E_RST"
  elif tiene_color; then
    printf '  %s%s%s\n' "$E_OK" \
      "$(pad '✔ Con color: así lo ven HTTP Injector y las demás apps de túnel.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad "  Puesto desde: ${ORIGEN:-ninguno}" 76)" "$E_RST"
  elif (( ${#LINEAS[@]} == 0 )); then
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad 'Un banner sirve para que el cliente sepa a quién escribirle si falla algo.' 76)" "$E_RST"
    printf '  %s\n' "$(pad '' 76)"
  else
    printf '  %s%s%s\n' "$E_TXT" \
      "$(pad '▸ En texto pelado, sin color. Se ve igual en cualquier cliente.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad "  Puesto desde: ${ORIGEN:-ninguno}" 76)" "$E_RST"
  fi
}

# El interruptor, con su estado a la vista. No es "color sí / color no": es
# para QUÉ cliente se guarda. La app necesita <br> para respetar los renglones;
# una terminal muestra ese <br> a la vista y no lo necesita.
fila_color() {
  local e t c
  if (( MODO_APP )); then e="📱"; t="MODO APP · HTTP Injector y similares"; c="$E_BLD$E_OK"
  else                    e="💻"; t="MODO TERMINAL · PuTTY, ssh de la compu"; c="$E_BLD$E_WARN"; fi
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_P1" "$(pad '88' 2)" "$E_RST" "$E_P2" "$e" "$E_RST" \
    "$c" "$(pad "$t" 70)" "$E_RST"
  if (( CENTRADO )); then e="🎯"; t="CENTRADO · el banner va al medio"; c="$E_BLD$E_OK"
  else                    e="📏"; t="PEGADO A LA IZQUIERDA"; c="$E_BLD$E_WARN"; fi
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_P1" "$(pad '66' 2)" "$E_RST" "$E_P2" "$e" "$E_RST" \
    "$c" "$(pad "$t" 70)" "$E_RST"
}

marco_superior() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BANNER SSH" "KIRA v$KIRA_VER"
  echo
}

pintar_inicio() {
  marco_superior
  techo_ancho "ASÍ LO VE TU CLIENTE"
  vista_previa "${LINEAS[@]}"
  piso_ancho
  echo
  diagnostico
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion '01' '✨' 'USAR UNA PLANTILLA')" "$(opcion '02' '📝' 'ESCRIBIR UNO NUEVO')"
  if tiene_etiquetas || tiene_ansi; then
    printf '  %s  %s\n' "$(opcion '03' '🧽' 'SACARLE EL COLOR')" "$(opcion '04' '🧹' 'QUITAR EL BANNER')"
  else
    printf '  %s  %s\n' "$(opcion_off '03' '🧽' 'SACARLE EL COLOR')" "$(opcion '04' '🧹' 'QUITAR EL BANNER')"
  fi
  fila_color
  if (( HAY_DROPBEAR )) && (( ! DB_LISTO )); then
    printf '  %s  %s\n' "$(opcion '05' '🔗' 'APLICARLO EN DROPBEAR')" "$(pad '' 37)"
  elif (( DB_LISTO )); then
    printf '  %s  %s\n' "$(opcion_off '05' '🔗' 'DROPBEAR YA LO USA')" "$(pad '' 37)"
  else
    printf '  %s  %s\n' "$(pad '' 37)" "$(pad '' 37)"
  fi
  opcion_salir
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_escribir() {
  local -a v=()
  mapfile -t v < <(envolver_lineas "${NUEVO[@]}")
  marco_superior
  techo_ancho "LO QUE LLEVÁS ESCRITO · ${#NUEVO[@]} DE $MAX_LINEAS LÍNEAS"
  vista_previa "${v[@]}"
  piso_ancho
  echo
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad "Escribí una línea y dale ENTER. Entran hasta $MAX_LINEAS de $ANCHO_LINEA caracteres." 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'ENTER en blanco termina y guarda. El color se lo pone el panel solo.' 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '99' '🔙' 'BORRAR LA ÚLTIMA LÍNEA')" "$(pad '' 37)"
  opcion_salir "CANCELAR SIN GUARDAR"
  echo
  linea_aviso
  prompt "Línea:"
}

# Media fila de plantilla. La elegida va en rosa; las que usan caracteres de
# dibujo, en ámbar.
opcion_plant() { # $1=número
  local n="$1" c nn
  printf -v nn '%02d' "$n"
  if   (( PLANT_SEL == n ));   then c="$E_BLD$E_PINK"
  elif plant_especial "$n";    then c="$E_WARN"
  else                              c="$E_BLD$E_TXT"; fi
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$nn" 2)" "$E_RST" \
         "$E_P2" "$(plant_emoji "$n")" "$E_RST" "$c" "$(pad "$(plant_nombre "$n")" 31)" "$E_RST"
}

pintar_plantillas() {
  local -a muestra=()
  mapfile -t muestra < <(plantilla "$PLANT_SEL")
  marco_superior
  techo_ancho "ASÍ LA VERÍA TU CLIENTE · $(plant_nombre "$PLANT_SEL")"
  vista_previa "${muestra[@]}"
  piso_ancho
  echo
  printf '  %s%s%s\n' "$E_OK" \
    "$(pad '✔ Renglones cortos y emojis: entra y se ve igual en cualquier celular.' 76)" "$E_RST"
  echo
  seccion "ELEGÍ UNA" "$E_P1"
  echo
  printf '  %s  %s\n' "$(opcion_plant 1)" "$(opcion_plant 2)"
  printf '  %s  %s\n' "$(opcion_plant 3)" "$(opcion_plant 4)"
  printf '  %s  %s\n' "$(opcion_plant 5)" "$(opcion_plant 6)"
  printf '  %s  %s\n' "$(opcion_plant 7)" "$(opcion_plant 8)"
  printf '  %s  %s\n' "$(opcion_plant 9)" "$(opcion_plant 10)"
  echo
  fila_color
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_P1" "$(pad '77' 2)" "$E_RST" "$E_P2" "🧪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad 'PROBAR SI TU APP HACE COLOR' 70)" "$E_RST"
  printf '  %s%s%s %s%s%s %s%s%s\n' \
    "$E_BLD$E_OK" "$(pad '99' 2)" "$E_RST" "$E_P2" "💾" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad 'DEJAR ESTA PUESTA' 70)" "$E_RST"
  opcion_salir "VOLVER SIN CAMBIAR NADA"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_confirmar() {
  local t1 t2 t3 bot
  case "$ACCION" in
    quitar)
      t1="El cliente no va a ver ningún mensaje al conectarse."
      t2="No afecta las conexiones: sólo se saca el texto de bienvenida."
      t3=""
      bot="SÍ, QUITARLO" ;;
    limpiar)
      t1="Se le sacan las etiquetas y queda el texto pelado, sin color."
      t2="Sirve si tus clientes entran con una terminal y no con una app."
      t3="Se le puede volver a poner color desde las plantillas."
      bot="SÍ, SACARLE EL COLOR" ;;
    dropbear)
      t1="Dropbear necesita que el archivo se le pase al arrancar."
      t2="Para eso hay que reiniciarlo, y eso CORTA las conexiones que tenga."
      t3="Las de OpenSSH no se tocan. Después, cambiar el texto ya no corta nada."
      bot="SÍ, REINICIAR DROPBEAR" ;;
  esac
  marco_superior
  seccion "CONFIRMÁ" "$E_ERR"
  echo
  printf '  %s%s%s\n' "$E_BLD$E_TXT" "$(pad "$t1" 76)" "$E_RST"
  echo
  printf '  %s%s%s\n' "$E_MUT" "$(pad "$t2" 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" "$(pad "$t3" 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '01' '✅' "$bot")" "$(pad '' 37)"
  opcion_salir "NO, VOLVER"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar() {
  case "$PANTALLA" in
    escribir)   pintar_escribir ;;
    plantillas) pintar_plantillas ;;
    confirmar)  pintar_confirmar ;;
    *)          pintar_inicio ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# =============================================================== PLANTILLAS =
# Cada renglón se declara como "color|texto". De esa única definición salen
# las dos versiones: la de color, con etiquetas, y la pelada. Así no hay dos
# listas que mantener a la par, que es como se desfasan las cosas.
#
# Los emojis son todos de Unicode 6.0 (2010): están en cualquier Android o
# iPhone que se siga usando. Los nuevitos salen como cuadradito en equipos de
# hace cuatro años, así que no entra ninguno.
#
# Y nada de marcos cerrados con emojis adentro: el ancho de un emoji cambia
# con la tipografía del equipo y el borde derecho nunca cerraría parejo. Por
# eso los marcos son reglas de arriba y abajo, que siempre salen derechas.
plant_nombre() { # $1=número
  case "$1" in
    1)  printf 'PREMIUM VIP' ;;     2)  printf 'LOGO KIRA' ;;
    3)  printf 'TARJETA DORADA' ;;  4)  printf 'SEGURIDAD' ;;
    5)  printf 'ARCOÍRIS' ;;        6)  printf 'LAS REGLAS' ;;
    7)  printf 'VELOCIDAD' ;;       8)  printf 'MINIMAL' ;;
    9)  printf 'BIENVENIDA' ;;      10) printf 'PANEL DE ESTADO' ;;
  esac
}
plant_emoji() { # $1=número
  case "$1" in
    1) printf '🚀' ;; 2) printf '🔠' ;; 3) printf '👑' ;; 4) printf '🔐' ;;
    5) printf '🌈' ;; 6) printf '📜' ;; 7) printf '📶' ;; 8) printf '📌' ;;
    9) printf '🎉' ;; 10) printf '📊' ;;
  esac
}
plant_especial() { return 1; }

# CÓMO ESTÁN ARMADAS, Y POR QUÉ ASÍ:
#
# · Cada renglón se declara "color|estilo|texto". El estilo es n normal,
#   b negrita, i cursiva. De esa única definición salen las dos versiones:
#   la de la app, con etiquetas, y la pelada para terminal.
#
# · Las reglas son de 37 caracteres de teclado (= - * ~). Ese largo entra
#   justo en el ancho de la ventana de la app sin partirse. Los caracteres
#   de dibujo (═ ━ ─) son MÁS ANCHOS en la tipografía del celular y se
#   partían a mitad de camino: por eso no se usan.
#
# · Los títulos llevan espacios adelante para quedar centrados sobre la
#   regla. La tipografía es de ancho variable, así que el centrado es al
#   ojo: un espacio mide como medio "=".
#
# · Nada de dibujos armados con caracteres. Un logo de bloques sale
#   deformado sí o sí cuando la tipografía no es de ancho fijo.
plant_def() { # $1=número · imprime "color|estilo|texto" por renglón
  local ip="${IP_PUB:-tu servidor}"
  case "$1" in
    2)  printf '%s\n' \
          'cian|m|██╗  ██╗██╗██████╗  █████╗' \
          'cian|m|██║ ██╔╝██║██╔══██╗██╔══██╗' \
          'azul|m|█████╔╝ ██║██████╔╝███████║' \
          'violeta|m|██╔═██╗ ██║██╔══██╗██╔══██║' \
          'violeta|m|██║  ██╗██║██║  ██║██║  ██║' \
          'rosa|m|╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝' \
          'blanco|b|ADMINISTRADOR DE VPS · SSH' \
          "verde|n|🌐 Servidor : $ip" \
          "amarillo|n|💬 Soporte  : $KIRA_SOP" ;;

    3)  printf '%s\n' \
          'amarillo|n|*************************************' \
          'amarillo|b|👑 K I R A   V I P 👑' \
          'amarillo|n|*************************************' \
          'blanco|b|💎 Acceso premium activado' \
          'verde|b|📶 Alta velocidad, sin cortes' \
          "cian|n|🌐 Servidor : $ip" \
          "cian|n|💬 Soporte  : $KIRA_SOP" \
          'amarillo|n|*************************************' ;;

    4)  printf '%s\n' \
          'verde|n|=====================================' \
          'verde|b|🔐 K I R A   S S H 🔐' \
          'verde|n|=====================================' \
          "blanco|n|🌐 Servidor : $ip" \
          "blanco|n|💬 Soporte  : $KIRA_SOP" \
          'rojo|b|🚫 Prohibido compartir la cuenta' \
          'verde|n|=====================================' ;;

    5)  printf '%s\n' \
          'rojo|n|=====================================' \
          'amarillo|b|🌈 K I R A   S S H' \
          'verde|n|=====================================' \
          "cian|n|📡 Servidor : $ip" \
          "violeta|n|🔑 Soporte  : $KIRA_SOP" \
          'amarillo|b|✅ Conexion establecida' \
          'rosa|n|=====================================' ;;

    6)  printf '%s\n' \
          'amarillo|n|-------------------------------------' \
          'cian|b|📜 K I R A  ·  R E G L A S' \
          'amarillo|n|-------------------------------------' \
          'blanco|b|🔒 Una sola conexion por cuenta' \
          'rojo|b|🚫 Prohibido revender el acceso' \
          'rojo|b|🚫 Prohibido el abuso de la red' \
          'amarillo|n|-------------------------------------' \
          "cian|i|💬 Soporte : $KIRA_SOP" ;;

    7)  printf '%s\n' \
          'cian|n|=====================================' \
          'verde|b|🚀 K I R A   S S H' \
          'cian|n|=====================================' \
          'verde|b|[############################] 100%' \
          'amarillo|n|📶 Velocidad al maximo' \
          "blanco|n|🌐 $ip   ·   💬 $KIRA_SOP" \
          'rosa|i|🔥 Gracias por elegirnos' ;;

    8)  printf '%s\n' \
          'cian|b|🔥 KIRA SSH' \
          'blanco|i|conexion establecida' \
          "amarillo|n|💬 $KIRA_SOP" ;;

    9)  printf '%s\n' \
          'rosa|n|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' \
          'amarillo|b|🎉 B I E N V E N I D O 🎉' \
          'cian|b|K I R A   S S H' \
          'rosa|n|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' \
          "verde|n|🌍 Servidor : $ip" \
          "blanco|n|💬 Soporte  : $KIRA_SOP" \
          'cian|i|🙌 Gracias por confiar en nosotros' ;;

    10) printf '%s\n' \
          'cian|b|💠 K I R A   S S H' \
          'cian|n|-------------------------------------' \
          "blanco|n|📡 Servidor   : $ip" \
          'verde|b|✅ Estado     : ACTIVO' \
          "amarillo|n|🔑 Soporte    : $KIRA_SOP" \
          'blanco|n|🕐 Disponible : 24 / 7' \
          'cian|n|-------------------------------------' \
          'verde|i|🔥 Alta velocidad garantizada' ;;

    *)  printf '%s\n' \
          'verde|n|=====================================' \
          'amarillo|b|🚀 K I R A   P R E M I U M 🚀' \
          'verde|n|=====================================' \
          'blanco|b|✔ Conexion estable y alta velocidad' \
          'blanco|b|✔ Prohibido Torrent / SPAM / DDOS' \
          "cian|n|✔ Servidor : $ip" \
          "cian|n|✔ Soporte  : $KIRA_SOP" \
          'amarillo|i|¡Gracias por preferir nuestro servicio!' \
          'verde|n|=====================================' ;;
  esac
}

# Un banner de PRUEBA, por si hace falta comprobar algo en otro cliente.
plantilla_prueba() {
  local e=$'\033'
  printf '%s\n' \
    'PRUEBA DE COLOR KIRA<br>' \
    '<font color="#FF0000">1 rojo hex</font><br>' \
    '<font color="red">2 rojo nombre</font><br>' \
    '<b>3 negrita</b><br>' \
    '<span style="color:#00CC00">4 verde span</span><br>' \
    "${e}[31m5 rojo terminal${e}[0m<br>" \
    "${e}[1;32m6 verde terminal${e}[0m<br>" \
    '7 este sale blanco<br>' \
    '8 el emoji pinta 🔴🔵<br>'
}

# Le pone la ropa de color y estilo a un tramo de texto, sin tocar los saltos
# de renglón. Eso lo resuelve plantilla(), que es la que sabe si va todo en un
# bloque centrado o renglón por renglón.
#
# El ANCHO FIJO va con <tt>. Es lo que le faltaba al logo: la tipografía
# normal del celular es de ancho variable y deforma cualquier dibujo hecho con
# caracteres. <tt> pide la de ancho fijo y las columnas se alinean.
vestir_tramo() { # $1=texto $2=color $3=estilo (n|b|i|m)
  if (( ! MODO_APP )); then printf '%s' "$1"; return; fi
  local ini="" fin=""
  case "$3" in
    b) ini="<b>";  fin="</b>" ;;
    i) ini="<i>";  fin="</i>" ;;
    m) ini="<tt>"; fin="</tt>" ;;
  esac
  printf '%s<font color="#%s">%s</font>%s' "$ini" "${BC[$2]:-00FFFF}" "$1" "$fin"
}

# Lo que el dueño escribe a mano pasa por el mismo molde que las plantillas:
# un solo bloque centrado, o renglón por renglón si el centrado está apagado.
envolver_lineas() { # $@ = textos pelados · imprime lo que va al archivo
  (( $# == 0 )) && return 0
  local l
  if (( MODO_APP )) && (( CENTRADO )); then
    local salida='<div align="center">' primero=1
    for l in "$@"; do
      (( primero )) || salida="$salida<br>"
      primero=0
      salida="$salida$(vestir_tramo "$l" cian n)"
    done
    printf '%s</div>\n' "$salida"
  else
    for l in "$@"; do
      vestir_tramo "$l" cian n
      (( MODO_APP )) && printf '<br>'
      printf '\n'
    done
  fi
}

plantilla() { # $1=número · lo que va a parar al archivo
  local linea col est txt
  if (( MODO_APP )) && (( CENTRADO )); then
    # TODO el banner en UN SOLO bloque centrado, con <br> entre renglón y
    # renglón. Si cada renglón fuera su propio <div>, la app le agrega un
    # renglón en blanco detrás de cada uno —así es como separa párrafos— y el
    # banner sale todo desparramado. Un bloque solo queda centrado y juntito.
    #
    # Y sale todo en UNA línea del archivo a propósito: los saltos de línea de
    # verdad la app los toma como espacios, y uno suelto después de un <br>
    # correría el centrado medio carácter.
    local salida='<div align="center">' primero=1
    while IFS= read -r linea; do
      col="${linea%%|*}"; linea="${linea#*|}"
      est="${linea%%|*}"; txt="${linea#*|}"
      (( primero )) || salida="$salida<br>"
      primero=0
      salida="$salida$(vestir_tramo "$txt" "$col" "$est")"
    done < <(plant_def "$1")
    printf '%s</div>\n' "$salida"
  else
    # Sin centrar (o en modo terminal): un renglón del archivo por renglón del
    # banner, que es más fácil de leer si algún día lo abrís a mano.
    while IFS= read -r linea; do
      col="${linea%%|*}"; linea="${linea#*|}"
      est="${linea%%|*}"; txt="${linea#*|}"
      vestir_tramo "$txt" "$col" "$est"
      (( MODO_APP )) && printf '<br>'
      printf '\n'
    done < <(plant_def "$1")
  fi
}

# ================================================================ ACCIONES ==
# Se guarda una copia de cada archivo que se toca, para poder volver atrás si
# sshd rechaza la configuración. Un sshd que no arranca te deja afuera de tu
# propia VPS: es el único error de este módulo que no tendría arreglo.
respaldar() { # $1=archivo
  local c="$1.kira-backup.$(date +%Y%m%d%H%M%S)"
  cp -a "$1" "$c" 2>/dev/null && RESPALDOS+=("$1|$c")
}
deshacer() {
  local r f c
  for r in "${RESPALDOS[@]}"; do
    f="${r%%|*}"; c="${r#*|}"
    [ -r "$c" ] && cp -a "$c" "$f" 2>/dev/null
  done
}

# Deja Banner apuntando a nuestro archivo y se asegura de que GANE. OpenSSH se
# queda con el primer valor que encuentra, así que la línea va arriba de todo
# —antes del Include— y se borran las que haya en los archivos incluidos.
# Nunca se agrega al final: si el archivo termina en un bloque Match, la línea
# quedaría adentro de ese bloque y no se aplicaría a todos.
poner_directiva() {
  RESPALDOS=()
  local f tmp
  if [ -d "$DROPIN" ]; then
    for f in "$DROPIN"/*.conf; do
      [ -r "$f" ] || continue
      grep -qi "^[[:space:]]*Banner[[:space:]]" "$f" 2>/dev/null || continue
      respaldar "$f"
      tmp="$f.kira.tmp"
      grep -vi "^[[:space:]]*Banner[[:space:]]" "$f" > "$tmp" 2>/dev/null && mv -f "$tmp" "$f"
    done
  fi
  respaldar "$SSHD"
  tmp="$SSHD.kira.tmp"
  {
    printf '# KIRA · banner de bienvenida\n'
    printf 'Banner %s\n' "$ARCHIVO"
    grep -vi "^[[:space:]]*Banner[[:space:]]" "$SSHD" 2>/dev/null | \
      grep -v '^# KIRA · banner de bienvenida$'
  } > "$tmp" 2>/dev/null || { AVISO="No pude escribir $SSHD"; return 1; }
  mv -f "$tmp" "$SSHD"
  recargar_ssh || { deshacer; return 1; }
  return 0
}

sacar_directiva() {
  RESPALDOS=()
  local f tmp
  if [ -d "$DROPIN" ]; then
    for f in "$DROPIN"/*.conf; do
      [ -r "$f" ] || continue
      grep -qi "^[[:space:]]*Banner[[:space:]]" "$f" 2>/dev/null || continue
      respaldar "$f"
      tmp="$f.kira.tmp"
      grep -vi "^[[:space:]]*Banner[[:space:]]" "$f" > "$tmp" 2>/dev/null && mv -f "$tmp" "$f"
    done
  fi
  if grep -qi "^[[:space:]]*Banner[[:space:]]" "$SSHD" 2>/dev/null; then
    respaldar "$SSHD"
    tmp="$SSHD.kira.tmp"
    grep -vi "^[[:space:]]*Banner[[:space:]]" "$SSHD" 2>/dev/null | \
      grep -v '^# KIRA · banner de bienvenida$' > "$tmp" && mv -f "$tmp" "$SSHD"
  fi
  recargar_ssh || { deshacer; return 1; }
  return 0
}

# OJO: acá NO se limpia nada. Las etiquetas de color son parte del banner y
# sacárselas al guardar sería borrar justo lo que se quiso poner. Lo que el
# dueño escribe a mano ya viene filtrado desde el teclado.
escribir_archivo() { # $@ = líneas
  local l
  : > "$ARCHIVO" 2>/dev/null || { AVISO="No pude escribir $ARCHIVO"; return 1; }
  for l in "$@"; do printf '%s\n' "$l" >> "$ARCHIVO"; done
  chmod 644 "$ARCHIVO" 2>/dev/null
  return 0
}

guardar_banner() { # $@ = líneas
  escribir_archivo "$@" || return 1
  poner_directiva  || return 1
  cargar
  return 0
}

quitar_banner() {
  sacar_directiva || return 1
  rm -f "$ARCHIVO"
  cargar
  return 0
}

# Primero se comprueba que la configuración sea válida. Recargar un sshd roto
# es la forma más rápida de quedarte sin entrar a tu propia VPS.
recargar_ssh() {
  if command -v sshd >/dev/null 2>&1; then
    if ! sshd -t 2>/tmp/kira-banner.err; then
      AVISO="sshd rechazó la configuración: $(head -1 /tmp/kira-banner.err 2>/dev/null)"
      return 1
    fi
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || \
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
  else
    service ssh reload 2>/dev/null || service sshd reload 2>/dev/null
  fi
  return 0
}

# Dropbear no lee sshd_config: el banner se le pasa con -b al arrancar. Una
# vez puesto el argumento, cambiar el TEXTO ya no necesita reiniciar nada,
# porque lee el archivo en cada conexión.
poner_dropbear() {
  [ -r "$ARCHIVO" ] || { AVISO="Primero poné un banner con la opción 01 o 02"; return 1; }
  [ -r "$DB_DEFAULT" ] || { AVISO="No encontré $DB_DEFAULT · ¿dropbear está instalado?"; return 1; }
  RESPALDOS=()
  respaldar "$DB_DEFAULT"
  local tmp="$DB_DEFAULT.kira.tmp" actual
  actual=$(awk -F'"' '/^[[:space:]]*DROPBEAR_EXTRA_ARGS=/{print $2; exit}' "$DB_DEFAULT" 2>/dev/null)
  actual=$(printf '%s' "$actual" | sed -E 's/-b[[:space:]]+[^[:space:]]+//g; s/  +/ /g; s/^ //; s/ $//')
  {
    grep -v "^[[:space:]]*DROPBEAR_EXTRA_ARGS=" "$DB_DEFAULT"
    printf 'DROPBEAR_EXTRA_ARGS="%s"\n' "$(printf '%s -b %s' "$actual" "$ARCHIVO" | sed 's/^ //')"
  } > "$tmp" 2>/dev/null || { AVISO="No pude escribir $DB_DEFAULT"; return 1; }
  mv -f "$tmp" "$DB_DEFAULT"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart dropbear 2>/dev/null || { deshacer; AVISO="No pude reiniciar dropbear"; return 1; }
  else
    service dropbear restart 2>/dev/null || { deshacer; AVISO="No pude reiniciar dropbear"; return 1; }
  fi
  cargar
  return 0
}

# ================================================================= LÓGICA ===
ejecutar() {
  local entrada="$1"
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    inicio)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        1|01) PANTALLA=plantillas ;;
        2|02) NUEVO=(); PANTALLA=escribir ;;
        3|03)
          if tiene_etiquetas || tiene_ansi; then ACCION=limpiar; PANTALLA=confirmar
          else AVISO="Tu banner ya está pelado, no tiene nada que sacarle"; fi ;;
        4|04)
          if (( ${#LINEAS[@]} == 0 )); then AVISO="No hay ningún banner puesto"
          else ACCION=quitar; PANTALLA=confirmar; fi ;;
        88)
          if (( MODO_APP )); then MODO_APP=0; MENSAJE="Color apagado · las plantillas se guardan peladas"
          else MODO_APP=1; MENSAJE="Color encendido · las plantillas se guardan con etiquetas"; fi ;;
        66)
          if (( CENTRADO )); then CENTRADO=0; MENSAJE="Ahora queda pegado a la izquierda"
          else CENTRADO=1; MENSAJE="Ahora va centrado"; fi ;;
        5|05)
          if (( ! HAY_DROPBEAR )); then AVISO="No veo dropbear instalado en esta VPS"
          elif (( DB_LISTO ));     then AVISO="Dropbear ya está usando este banner"
          else ACCION=dropbear; PANTALLA=confirmar; fi ;;
        *) AVISO="Elegí una opción de la lista" ;;
      esac ;;

    escribir)
      case "$entrada" in
        00) NUEVO=(); PANTALLA=inicio; return ;;
        99)
          if (( ${#NUEVO[@]} == 0 )); then AVISO="Todavía no escribiste ninguna línea"
          else unset "NUEVO[$(( ${#NUEVO[@]} - 1 ))]"; NUEVO=("${NUEVO[@]}"); fi
          return ;;
      esac
      if [ -z "$entrada" ]; then
        if (( ${#NUEVO[@]} == 0 )); then
          AVISO="No escribiste nada todavía · 00 para cancelar"
        else
          local -a l=()
          mapfile -t l < <(envolver_lineas "${NUEVO[@]}")
          if guardar_banner "${l[@]}"; then
            MENSAJE="Banner guardado · ${#NUEVO[@]} líneas · ya lo ven los que entren"
            NUEVO=(); PANTALLA=inicio
          fi
        fi
        return
      fi
      if (( ${#NUEVO[@]} >= MAX_LINEAS )); then
        AVISO="Ya llegaste a $MAX_LINEAS líneas · ENTER en blanco para guardar"
      else
        NUEVO+=("${entrada:0:$ANCHO_LINEA}")
      fi ;;

    plantillas)
      case "$entrada" in
        ""|0|00) PANTALLA=inicio ;;
        88)
          if (( MODO_APP )); then MODO_APP=0; MENSAJE="Color apagado"
          else MODO_APP=1; MENSAJE="Color encendido"; fi ;;
        66)
          if (( CENTRADO )); then CENTRADO=0; MENSAJE="Ahora queda pegado a la izquierda"
          else CENTRADO=1; MENSAJE="Ahora va centrado"; fi ;;
        77)
          local -a pr=()
          mapfile -t pr < <(plantilla_prueba)
          if guardar_banner "${pr[@]}"; then
            MENSAJE="Banner de prueba puesto · conectate del celular y mirá cuáles salen pintadas"
            PANTALLA=inicio
          fi ;;
        99)
          local -a m=()
          mapfile -t m < <(plantilla "$PLANT_SEL")
          if guardar_banner "${m[@]}"; then
            MENSAJE="Banner puesto · plantilla $(plant_nombre "$PLANT_SEL")"
            PANTALLA=inicio
          fi ;;
        *)
          if [[ "$entrada" =~ ^[0-9]+$ ]] && (( 10#$entrada >= 1 && 10#$entrada <= PLANT_N )); then
            PLANT_SEL=$(( 10#$entrada ))
          else
            AVISO="Elegí del 01 al $PLANT_N · 77 prueba · 99 para dejarla puesta"
          fi ;;
      esac ;;

    confirmar)
      case "$entrada" in
        1|01)
          case "$ACCION" in
            quitar)   quitar_banner && MENSAJE="Banner quitado" ;;
            limpiar)
              local -a l=()
              local x
              for x in "${LINEAS[@]}"; do l+=("$(sin_etiquetas "$x")"); done
              MODO_APP=0
              guardar_banner "${l[@]}" && MENSAJE="Banner pelado · ya sin etiquetas" ;;
            dropbear) poner_dropbear && MENSAJE="Dropbear también muestra el banner" ;;
          esac
          [ -z "$AVISO" ] && PANTALLA=inicio ;;
        ""|0|00) PANTALLA=inicio ;;
        *)       AVISO="Elegí 01 para seguir o 00 para volver" ;;
      esac ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;
    *)
      # En la pantalla de escribir entran letras; en el resto, sólo números.
      # Los signos < y > se descartan al teclearlos: si el dueño escribe una
      # etiqueta a mano, lo único que logra es romper el color que el módulo
      # le pone solo.
      if [ "$PANTALLA" = escribir ]; then
        case "$1" in
          '<'|'>') ;;
          [[:print:]]) (( ${#BUF} < ANCHO_LINEA )) && BUF="$BUF$1" ;;
        esac
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
cargar
# OJO: acá había una "detección automática" que, si el banner que ya estaba
# puesto no tenía etiquetas, apagaba sola el modo app. El resultado era que
# el dueño elegía una plantilla de color y se guardaba pelada, sin color y
# sin <br>, sin que nada se lo dijera. Arranca SIEMPRE en modo app, que es
# para lo que se usa esto; si hace falta el otro, está el 88 a la vista.

while true; do
  printf -v ahora '%(%s)T' -1
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; render; fi
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done