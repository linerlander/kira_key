#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.01 · AGREGAR USUARIO
#  Crea una cuenta SSH para vender: usuario, clave, días y límite de conexiones.
#  Uso:  bash modules/user_add.sh
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
ui_exige techo piso banda cabecera cachear_cabecera datos_sistema seccion encabezado pad

# Crear cuentas toca /etc/passwd y /etc/shadow. Sin root no hay nada que hacer,
# y es mejor decirlo ahora que a mitad del formulario.
if [ "$(id -u)" -ne 0 ]; then
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para crear usuarios\e[0m\n'
  printf '  Entrá con:  \e[1msudo -i\e[0m   y volvé a abrir el panel.\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
PASO=1                      # 1 usuario · 2 clave · 3 días · 4 límite · 5 confirmar · 6 hecho
USUARIO=""; CLAVE=""; DIAS=""; LIMITE=""
VENCE=""; AVISO=""; CREADO=0
MAX_DIAS=3650               # 10 años: más que eso es un error de tipeo
MAX_CONEX=99

NOMBRE_PASO=("" "NOMBRE DE USUARIO" "CONTRASEÑA" "DURACIÓN" "LÍMITE DE CONEXIONES" \
             "CONFIRMAR" "CUENTA CREADA")

M_DAT=$'\e[38;2;22;92;110m'      # marco cian apagado
M_CLI=$'\e[38;2;74;64;130m'      # marco violeta apagado

# ============================================================== PUERTOS =====
# Los puertos que el cliente tiene que poner en HTTP Injector. Se leen de lo
# que está escuchando de verdad, no de la configuración: si alguien cambió el
# puerto y no reinició el servicio, la configuración miente y el proceso no.
PUERTOS="22"
detectar_puertos() {
  local p lista
  lista=$(ss -tlnpH 2>/dev/null | awk '
    /"sshd"|"dropbear"/ {
      n = split($4, a, ":")
      if (a[n] ~ /^[0-9]+$/ && !(a[n] in v)) { v[a[n]]=1; print a[n] }
    }' | sort -n | head -4)
  if [ -z "$lista" ] && [ -r /etc/ssh/sshd_config ]; then
    # Sin ss, se cae a la configuración. Default 22 si no dice nada.
    lista=$(awk 'tolower($1)=="port" && $2 ~ /^[0-9]+$/ {print $2}' /etc/ssh/sshd_config | head -4)
  fi
  [ -z "$lista" ] && lista="22"
  PUERTOS=""
  while read -r p; do
    [ -z "$p" ] && continue
    [ -n "$PUERTOS" ] && PUERTOS="$PUERTOS · "
    PUERTOS="$PUERTOS$p"
  done <<< "$lista"
}

# Clave sugerida. Se sacan las letras y números que se confunden al dictarla
# por WhatsApp: 0/O, 1/l/I. Si el cliente la tipea mal, te escribe a vos.
clave_azar() {
  local s
  s=$(LC_ALL=C tr -dc 'a-km-np-z2-9' < /dev/urandom 2>/dev/null | head -c 8)
  [ -z "$s" ] && s="kira$RANDOM"
  printf '%s' "$s"
}

# ============================================================== PANTALLA ====
# Contenido entre bordes = 35:  1 + etiqueta 12 + valor 22
fil_dat() { caja_izq " $E_MUT$(pad "$1" 12)$E_RST$2$(pad "$3" 22)$E_RST" "$M_DAT"; }
fil_cli() { caja_der " $E_MUT$(pad "$1" 12)$E_RST$2$(pad "$3" 22)$E_RST" "$M_CLI"; }

# Lo que todavía no se cargó se muestra con un guion gris, no en blanco: así
# se ve de un vistazo cuánto falta.
val() { # $1=valor $2=color si está cargado
  if [ -z "$1" ]; then printf '%s\x01%s' "$E_OFF" "—"
  else printf '%s\x01%s' "$2" "$1"; fi
}
fd() { local v; v="$(val "$2" "$3")"; fil_dat "$1" "${v%%$'\x01'*}" "${v#*$'\x01'}"; }
fc() { local v; v="$(val "$2" "$3")"; fil_cli "$1" "${v%%$'\x01'*}" "${v#*$'\x01'}"; }

estado_txt() {
  if   (( CREADO ));   then printf '✔ creada'
  elif (( PASO >= 5 )); then printf 'lista para crear'
  else printf 'cargando datos…'; fi
}
estado_col() {
  if   (( CREADO ));    then printf '%s' "$E_BLD$E_OK"
  elif (( PASO >= 5 )); then printf '%s' "$E_BLD$E_WARN"
  else printf '%s' "$E_MUT"; fi
}
dur_txt()  { [ -n "$DIAS" ] && printf '%s días' "$DIAS"; }
lim_txt()  { [ -n "$LIMITE" ] && printf '%s simultáneas' "$LIMITE"; }
vence_txt(){ [ -n "$VENCE" ] && printf '%s' "$VENCE"; }

paneles() {
  techo "DATOS DE LA CUENTA" "$E_P1" "PARA EL CLIENTE" "$E_P2" "$M_DAT" "$M_CLI"
  fd "USUARIO"    "$USUARIO"      "$E_BLD$E_TXT" ; fc "IP"       "$IP_PUB"       "$E_BLD$E_TXT"
  fd "CONTRASEÑA" "$CLAVE"        "$E_BLD$E_TXT" ; fc "PUERTOS"  "$PUERTOS"      "$E_BLD$E_P1"
  fd "DURACIÓN"   "$(dur_txt)"    "$E_TXT"       ; fc "USUARIO"  "$USUARIO"      "$E_BLD$E_OK"
  fd "LÍMITE"     "$(lim_txt)"    "$E_TXT"       ; fc "CLAVE"    "$CLAVE"        "$E_BLD$E_OK"
  fil_dat "ESTADO" "$(estado_col)" "$(estado_txt)" ; fc "VENCE"  "$(vence_txt)"  "$E_INFO"
  piso "$M_DAT" "$M_CLI"
}

linea_aviso() {
  if [ -n "$AVISO" ]; then printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  else printf '  %s\n' "$(pad '' 76)"; fi
}

# La ayuda cambia según el paso: explica qué se espera ANTES de que escriba,
# no después de que se equivoque.
AYUDA=("" \
  "Letras minúsculas, números y guiones. Sin espacios ni mayúsculas." \
  "ENTER solo = genero una al azar, fácil de dictar." \
  "Cuántos días dura la cuenta. Lo normal: 30." \
  "Cuántos dispositivos puede usar a la vez. Lo normal: 1 o 2." \
  "Revisá que esté todo bien. S para crear, N para cancelar." \
  "Copiá los datos de la derecha y mandáselos al cliente.")

pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "AGREGAR USUARIO" "KIRA v$KIRA_VER"
  echo
  paneles
  echo
  seccion "PASO $PASO · ${NOMBRE_PASO[$PASO]}" "$E_P2"
  echo
  printf '  %s%s%s\n' "$E_MUT" "$(pad "${AYUDA[$PASO]}" 76)" "$E_RST"
  echo
  linea_aviso
}

# El cuadro se vuelca entero y RECIÉN AHÍ se escribe la línea del prompt, sin
# salto de línea al final, para que el cursor quede justo donde se tipea.
# OJO: el \n del principio es obligatorio. `f="$(pintar)"` se come el salto
# de línea final, así que sin él el prompt se escribe PEGADO a la línea de
# aviso y los dos juntos se pasan de las 78 columnas.
preguntar() { # $1=etiqueta  -> respuesta en RESP
  local f; f="$(pintar)"
  volcar "$f"
  printf '\n  %s%s❯%s %s%s%s%s %s' "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$1" "$E_RST" "$E_BLD$E_P1"
  cursor_on
  IFS= read -r RESP
  cursor_off
  printf '%s' "$E_RST"
}

# ============================================================ VALIDACIÓN ====
# Las reglas de los nombres de usuario de Linux. Si se cuela algo raro,
# useradd falla y el error que tira no se entiende; mejor atajarlo acá.
val_usuario() {
  local u="$1"
  [ -z "$u" ] && { AVISO="Escribí un nombre de usuario"; return 1; }
  if ! [[ "$u" =~ ^[a-z_][a-z0-9_-]{0,19}$ ]]; then
    AVISO="Solo minúsculas, números, guion y guion bajo (máx. 20, sin empezar con número)"
    return 1
  fi
  if id "$u" >/dev/null 2>&1; then
    AVISO="El usuario '$u' ya existe · usá la opción 03 para renovarlo"
    return 1
  fi
  return 0
}

val_clave() {
  local c="$1"
  [ -z "$c" ] && { AVISO="La contraseña no puede quedar vacía"; return 1; }
  # Los dos puntos separan los campos de /etc/shadow: una clave con ':'
  # parte el archivo y deja la cuenta rota sin ningún mensaje de error.
  case "$c" in
    *:*) AVISO="La contraseña no puede llevar dos puntos ( : )"; return 1 ;;
    *\ *) AVISO="La contraseña no puede llevar espacios"; return 1 ;;
  esac
  (( ${#c} < 4 )) && { AVISO="Muy corta: mínimo 4 caracteres"; return 1; }
  return 0
}

val_numero() { # $1=valor $2=máximo $3=qué es
  local n="$1"
  [[ "$n" =~ ^[0-9]+$ ]] || { AVISO="$3: escribí solo números"; return 1; }
  # 0$n evita que un "007" se lea como octal y reviente la comparación
  (( 10#$n >= 1 && 10#$n <= $2 )) || { AVISO="$3: tiene que estar entre 1 y $2"; return 1; }
  return 0
}

# =============================================================== CREACIÓN ===
crear() {
  local err="/tmp/kira-add.err"
  : > "$err"

  # -M sin carpeta personal y -s /bin/false sin consola: estas cuentas son
  # para túnel, no para que entren a la máquina. El reenvío de puertos de
  # HTTP Injector funciona igual, porque no ejecuta la consola.
  if ! useradd -M -s /bin/false -e "$VENCE" "$USUARIO" 2>"$err"; then
    AVISO="No se pudo crear: $(head -1 "$err")"
    return 1
  fi

  # printf es un builtin de bash, así que la clave NO aparece en la lista de
  # procesos. Con `echo` externo o pasándola como argumento, cualquiera que
  # corra `ps` en ese instante la vería.
  if ! printf '%s:%s\n' "$USUARIO" "$CLAVE" | chpasswd 2>"$err"; then
    AVISO="Usuario creado pero falló la contraseña: $(head -1 "$err")"
    userdel "$USUARIO" 2>/dev/null     # se deshace, no se deja a medias
    return 1
  fi

  # Límite de conexiones para el módulo 14. Se reescribe la línea del usuario
  # en vez de agregar otra, para que no queden dos límites para el mismo.
  mkdir -p "$DIR/db"
  touch "$DIR/db/limites"
  local tmp="$DIR/db/.limites.tmp"
  grep -v "^$USUARIO " "$DIR/db/limites" > "$tmp" 2>/dev/null
  printf '%s %s\n' "$USUARIO" "$LIMITE" >> "$tmp"
  mv -f "$tmp" "$DIR/db/limites"

  rm -f "$err"
  CREADO=1
  return 0
}

limpiar_campos() {
  PASO=1; USUARIO=""; CLAVE=""; DIAS=""; LIMITE=""; VENCE=""; AVISO=""; CREADO=0
}

# ================================================================= MAIN =====
exigir_ancho
datos_sistema
cachear_cabecera
detectar_puertos
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear' EXIT
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear; exit 130' INT TERM
cursor_off
clear

while true; do
  case $PASO in
    1)
      preguntar "Usuario:"
      AVISO=""
      [ -z "$RESP" ] && { clear; exit 0; }          # ENTER vacío = salir
      if val_usuario "$RESP"; then USUARIO="$RESP"; PASO=2; fi
      ;;
    2)
      preguntar "Contraseña:"
      AVISO=""
      [ -z "$RESP" ] && RESP="$(clave_azar)"        # ENTER solo = al azar
      if val_clave "$RESP"; then CLAVE="$RESP"; PASO=3; fi
      ;;
    3)
      preguntar "Días:"
      AVISO=""
      [ -z "$RESP" ] && RESP=30                     # ENTER solo = 30 días
      if val_numero "$RESP" "$MAX_DIAS" "Días"; then
        DIAS=$(( 10#$RESP ))
        VENCE=$(date -d "+$DIAS days" +%Y-%m-%d 2>/dev/null)
        if [ -z "$VENCE" ]; then AVISO="No pude calcular la fecha de vencimiento"
        else PASO=4; fi
      fi
      ;;
    4)
      preguntar "Límite:"
      AVISO=""
      [ -z "$RESP" ] && RESP=1                      # ENTER solo = 1 conexión
      if val_numero "$RESP" "$MAX_CONEX" "Límite"; then
        LIMITE=$(( 10#$RESP )); PASO=5
      fi
      ;;
    5)
      preguntar "¿Creo la cuenta? (s/n):"
      AVISO=""
      case "${RESP,,}" in
        s|si|sí|"") if crear; then PASO=6; fi ;;
        n|no)       limpiar_campos ;;
        *)          AVISO="Respondé s para crear o n para cancelar" ;;
      esac
      ;;
    6)
      preguntar "ENTER vuelve · N crea otro:"
      case "${RESP,,}" in
        n|o|otro) limpiar_campos ;;
        *)        clear; exit 0 ;;
      esac
      ;;
  esac
done