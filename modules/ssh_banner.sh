#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.06 · BANNER SSH
#  El mensaje que ve el cliente al conectarse. Va en TEXTO PLANO: SSH manda
#  texto, no una página web, así que las etiquetas HTML y los códigos de color
#  llegan crudos al inyector y se ven como basura.
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
MAX_LINEAS=8
ANCHO_LINEA=60

PANTALLA=inicio           # inicio · escribir · plantillas · confirmar
ACCION=""                 # qué va a confirmar la pantalla de confirmar
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0
ORIGEN=""                 # de qué archivo sale el banner que se está usando
HAY_DROPBEAR=0; DB_LISTO=0
declare -a LINEAS=()      # lo que hay guardado
declare -a NUEVO=()       # lo que se está escribiendo
declare -a RESPALDOS=()   # "archivo|copia" para poder volver atrás

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
# De dónde sale el banner que se está usando DE VERDAD. No alcanza con mirar
# sshd_config: las distros nuevas traen "Include /etc/ssh/sshd_config.d/*.conf"
# arriba de todo, y OpenSSH se queda con el PRIMER valor que encuentra. Si el
# proveedor dejó un Banner ahí adentro, el de sshd_config no se usa nunca.
#
# OJO: esta función NO imprime el resultado, lo deja en dos variables. Si
# imprimiera y se llamara con $( ), eso corre en un subshell y el ORIGEN que
# asigna se perdería al volver: el panel diría siempre "ninguno".
BANNER_FILE=""
banner_actual() {
  ORIGEN=""; BANNER_FILE=""
  local f linea
  # Primero los incluidos, en el orden en que los lee sshd.
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

  # ¿Hay dropbear? No usa sshd_config: el banner se le pasa por argumento.
  HAY_DROPBEAR=0; DB_LISTO=0
  if [ -s /etc/dropbear/dropbear.conf ] || [ -r "$DB_DEFAULT" ] || \
     command -v dropbear >/dev/null 2>&1; then
    HAY_DROPBEAR=1
    grep -q -- "-b $ARCHIVO" "$DB_DEFAULT" 2>/dev/null && DB_LISTO=1
  fi
}

# ¿Tiene HTML adentro? Es el error más común: queda del panel anterior y el
# cliente ve las etiquetas crudas.
tiene_html() {
  local l
  for l in "${LINEAS[@]}"; do case "$l" in *'<'*'>'*) return 0 ;; esac; done
  return 1
}
tiene_ansi() {
  local l
  for l in "${LINEAS[@]}"; do case "$l" in *$'\e'*) return 0 ;; esac; done
  return 1
}

# Deja sólo lo que el cliente puede leer: fuera etiquetas y códigos de color.
limpiar_texto() { # $1=línea
  local t="$1"
  t="${t//<br>/ }"; t="${t//<BR>/ }"; t="${t//<br\/>/ }"; t="${t//<br \/>/ }"
  while [[ "$t" == *"<"*">"* ]]; do t="${t%%<*}${t#*>}"; done
  t="${t//$'\e'/}"
  t="${t//&nbsp;/ }"; t="${t//&amp;/&}"; t="${t//&lt;/<}"; t="${t//&gt;/>}"
  t="${t//$'\t'/ }"; t="${t//$'\r'/}"
  # Sólo se recorta por la derecha. Los espacios de la izquierda se respetan:
  # son los que centran el texto, y comérselos desarma cualquier plantilla.
  while [[ "$t" == *' ' ]]; do t="${t% }"; done
  printf '%s' "$t"
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
opcion_off() { # una opción que ahora no se puede usar
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
# El banner se muestra ya limpio: así como se ve acá es como se ve allá.
vista_previa() { # $@ = líneas
  local l n=0 limpio
  for l in "$@"; do
    (( n++ )); (( n > MAX_LINEAS )) && break
    limpio="$(limpiar_texto "$l")"
    fila_ancha "$(printf '   %s%s   ' "$E_BLD$E_TXT" "$(pad "$limpio" 68)")"
  done
  if (( n == 0 )); then
    fila_ancha "$(printf ' %s%s ' "$E_MUT" "$(pad 'Sin banner: el cliente no ve ningún mensaje al conectarse.' 72)")"
    n=1
  fi
  local i
  for ((i=n; i<MAX_LINEAS; i++)); do fila_ancha "$(pad '' 74)"; done
}

diagnostico() {
  if tiene_html; then
    printf '  %s%s%s\n' "$E_BLD$E_ERR" \
      "$(pad '✖ Tu banner tiene etiquetas HTML y el cliente las ve crudas.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad '  Arriba está ya limpio. La opción 03 lo deja así de verdad.' 76)" "$E_RST"
  elif tiene_ansi; then
    printf '  %s%s%s\n' "$E_BLD$E_WARN" \
      "$(pad '▸ Tiene códigos de color: HTTP Injector los muestra como basura.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad '  La opción 03 los saca y deja sólo el texto.' 76)" "$E_RST"
  elif (( ${#LINEAS[@]} == 0 )); then
    printf '  %s%s%s\n' "$E_MUT" \
      "$(pad 'Un banner sirve para que el cliente sepa a quién escribirle si falla algo.' 76)" "$E_RST"
    printf '  %s\n' "$(pad '' 76)"
  else
    printf '  %s%s%s\n' "$E_OK" "$(pad '✔ Texto plano: se ve igual en cualquier cliente.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" "$(pad "  Puesto desde: ${ORIGEN:-ninguno}" 76)" "$E_RST"
  fi
}

pintar_inicio() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BANNER SSH" "KIRA v$KIRA_VER"
  echo
  techo_ancho "ASÍ LO VE TU CLIENTE"
  vista_previa "${LINEAS[@]}"
  piso_ancho
  echo
  diagnostico
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion '01' '📝' 'ESCRIBIR UNO NUEVO')" "$(opcion '02' '✨' 'USAR UNA PLANTILLA')"
  if tiene_html || tiene_ansi; then
    printf '  %s  %s\n' "$(opcion '03' '🧽' 'LIMPIAR EL QUE TENGO')" "$(opcion '04' '🧹' 'QUITAR EL BANNER')"
  else
    printf '  %s  %s\n' "$(opcion_off '03' '🧽' 'LIMPIAR EL QUE TENGO')" "$(opcion '04' '🧹' 'QUITAR EL BANNER')"
  fi
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
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BANNER SSH" "KIRA v$KIRA_VER"
  echo
  techo_ancho "LO QUE LLEVÁS ESCRITO · ${#NUEVO[@]} DE $MAX_LINEAS LÍNEAS"
  vista_previa "${NUEVO[@]}"
  piso_ancho
  echo
  printf '  %s%s%s\n' "$E_TXT" \
    "$(pad "Escribí una línea y dale ENTER. Entran hasta $MAX_LINEAS de $ANCHO_LINEA caracteres." 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'ENTER en blanco termina y guarda. Nada de HTML ni de colores.' 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '99' '🔙' 'BORRAR LA ÚLTIMA LÍNEA')" "$(pad '' 37)"
  opcion_salir "CANCELAR SIN GUARDAR"
  echo
  linea_aviso
  prompt "Línea:"
}

pintar_plantillas() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BANNER SSH" "KIRA v$KIRA_VER"
  echo
  techo_ancho "VISTA PREVIA DE LA PLANTILLA $PLANT_SEL"
  local -a muestra=()
  mapfile -t muestra < <(plantilla "$PLANT_SEL")
  vista_previa "${muestra[@]}"
  piso_ancho
  echo
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'Elegí un número para verla, y volvé a elegirlo para dejarla puesta.' 76)" "$E_RST"
  echo
  seccion "PLANTILLAS" "$E_P1"
  echo
  printf '  %s  %s\n' "$(opcion '01' '📇' 'SOLO LOS DATOS')"   "$(opcion '02' '📣' 'CON LAS REGLAS')"
  printf '  %s  %s\n' "$(opcion '03' '⭐' 'CORTA Y DIRECTA')"   "$(opcion '09' '💾' 'DEJAR ESTA PUESTA')"
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
      t1="Se le sacan las etiquetas y los colores, y queda el texto de arriba."
      t2="Es exactamente lo que ya se ve en la vista previa."
      t3=""
      bot="SÍ, LIMPIARLO" ;;
    dropbear)
      t1="Dropbear necesita que el archivo se le pase al arrancar."
      t2="Para eso hay que reiniciarlo, y eso CORTA las conexiones que tenga."
      t3="Las de OpenSSH no se tocan. Después, cambiar el texto ya no corta nada."
      bot="SÍ, REINICIAR DROPBEAR" ;;
  esac
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BANNER SSH" "KIRA v$KIRA_VER"
  echo
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
PLANT_SEL=1
plantilla() { # $1=número
  local ip="${IP_PUB:-tu servidor}"
  case "$1" in
    2) printf '%s\n' \
         "==============================" \
         "        KIRA SSH VPN" \
         "==============================" \
         " Soporte: $KIRA_SOP" \
         " Prohibido compartir la cuenta" \
         " Una sola conexion por usuario" \
         "==============================" ;;
    3) printf '%s\n' \
         "KIRA SSH · soporte $KIRA_SOP" ;;
    *) printf '%s\n' \
         "==============================" \
         "   BIENVENIDO A KIRA SSH" \
         "==============================" \
         " Servidor: $ip" \
         " Soporte:  $KIRA_SOP" \
         "==============================" ;;
  esac
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

escribir_archivo() { # $@ = líneas
  local l
  : > "$ARCHIVO" 2>/dev/null || { AVISO="No pude escribir $ARCHIVO"; return 1; }
  for l in "$@"; do printf '%s\n' "$(limpiar_texto "$l")" >> "$ARCHIVO"; done
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
  # Se saca cualquier -b anterior para no acumular argumentos repetidos.
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
        1|01) NUEVO=(); PANTALLA=escribir ;;
        2|02) PLANT_SEL=1; PANTALLA=plantillas ;;
        3|03)
          if tiene_html || tiene_ansi; then ACCION=limpiar; PANTALLA=confirmar
          else AVISO="Tu banner ya está en texto plano, no hay nada que limpiar"; fi ;;
        4|04)
          if (( ${#LINEAS[@]} == 0 )); then AVISO="No hay ningún banner puesto"
          else ACCION=quitar; PANTALLA=confirmar; fi ;;
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
        elif guardar_banner "${NUEVO[@]}"; then
          MENSAJE="Banner guardado · ${#NUEVO[@]} líneas · ya lo ven los que entren"
          NUEVO=(); PANTALLA=inicio
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
        1|01) PLANT_SEL=1 ;;
        2|02) PLANT_SEL=2 ;;
        3|03) PLANT_SEL=3 ;;
        9|09)
          local -a m=()
          mapfile -t m < <(plantilla "$PLANT_SEL")
          if guardar_banner "${m[@]}"; then
            MENSAJE="Banner puesto con la plantilla $PLANT_SEL"
            PANTALLA=inicio
          fi ;;
        *) AVISO="Elegí 01, 02 o 03 para verla · 09 para dejarla puesta" ;;
      esac ;;

    confirmar)
      case "$entrada" in
        1|01)
          case "$ACCION" in
            quitar)   quitar_banner && MENSAJE="Banner quitado" ;;
            limpiar)
              local -a l=()
              local x
              for x in "${LINEAS[@]}"; do l+=("$(limpiar_texto "$x")"); done
              guardar_banner "${l[@]}" && MENSAJE="Banner limpio · ya sin HTML ni colores" ;;
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
      if [ "$PANTALLA" = escribir ]; then
        case "$1" in [[:print:]]) (( ${#BUF} < ANCHO_LINEA )) && BUF="$BUF$1" ;; esac
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