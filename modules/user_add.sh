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
ui_exige techo piso banda cabecera cachear_cabecera datos_sistema seccion encabezado pad \
         kira_purgar_demos

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
ES_DEMO=0; DEMO_HASTA=0
MAX_DIAS=3650               # 10 años: más que eso es un error de tipeo
MAX_CONEX=99
DEMO_MIN=60                 # cuánto dura la cuenta de prueba, en minutos

NOMBRE_PASO=("" "NOMBRE DE USUARIO" "CONTRASEÑA" "DURACIÓN" "LÍMITE DE CONEXIONES" \
             "CONFIRMAR" "CUENTA CREADA")

# Mismos colores que RED VPS y DISCO del monitor: el marco va en la versión
# apagada y la pastilla del título en la encendida, así el título salta y el
# marco acompaña sin competir.
M_DAT=$'\e[38;2;110;46;84m'      # marco rosa apagado
M_CLI=$'\e[38;2;96;76;28m'       # marco ámbar apagado
E_PINK=$'\e[38;2;255;111;181m'   # rosa encendido, para la pastilla

# ===================================================== PUERTOS Y SERVICIOS ==
# Lo que el cliente necesita para configurar HTTP Injector. Se lee de lo que
# está ESCUCHANDO de verdad, no de los archivos de configuración: si alguien
# cambió un puerto y no reinició el servicio, la configuración miente y el
# proceso no. Se miran TCP y UDP, porque OpenVPN y udpgw son UDP.
#
# La lista es FIJA: siempre se muestran los ocho servicios, con su puerto o
# con OFF. Así el cliente ve de una qué tiene y qué no, en vez de tener que
# deducir que lo que no aparece es porque no está.
CAT_NOM=("SSH" "SSH · DROPBEAR" "SSL / TLS" "WEBSOCKET" "V2RAY" "SHADOWSOCKS" "OPENVPN" "UDPGW")
CAT_CLA=(SSH   DROPBEAR         SSL         WS          V2RAY   SS            OVPN      UDPGW)
declare -A PUERTO_DE=()
PUERTOS="—"

# Arma la lista de puertos que entra en el ancho dado. Mete todos los que
# quepan hasta el tope y, si quedan afuera, avisa cuántos con "+N". Cortar con
# "…" deja al que mira sin saber si falta uno o faltan diez.
lista_corta() { # $1=ancho disponible  $2=tope de puertos  $3..=puertos
  local ancho="$1" tope="$2"; shift 2
  local n=$# primero="${1:-}"
  (( n == 0 )) && { printf ''; return; }
  (( tope > n )) && tope=$n
  local i k p s largo resto
  for (( i=tope; i>=1; i-- )); do
    s=""; k=0; largo=0
    for p in "$@"; do
      (( k >= i )) && break
      [ -n "$s" ] && { s="$s · "; largo=$(( largo + 3 )); }
      s="$s$p"; largo=$(( largo + ${#p} )); k=$(( k + 1 ))
    done
    resto=$(( n - i ))
    (( resto > 0 )) && { s="$s +$resto"; largo=$(( largo + 2 + ${#resto} )); }
    # El ancho se calcula sumando, no con ${#s}: el separador · ocupa DOS
    # bytes, y si la terminal no quedó en UTF-8 bash cuenta bytes en vez de
    # caracteres. Los puertos son dígitos, así que medirlos siempre da igual.
    (( largo <= ancho )) && { printf '%s' "$s"; return; }
  done
  printf '%s' "$primero"      # ni uno solo entra: al menos el primero
}

# Qué programa corresponde a qué servicio del catálogo.
clave_servicio() {
  case "${1,,}" in
    sshd|sshd-session)                          printf 'SSH' ;;
    dropbear|dropbearmulti)                     printf 'DROPBEAR' ;;
    stunnel|stunnel4|stunnel5)                  printf 'SSL' ;;
    python|python3|websocket|ws|wsproxy|nginx|apache2|httpd|caddy) printf 'WS' ;;
    v2ray|xray)                                 printf 'V2RAY' ;;
    ss-server|ssserver|ssr-server|shadowsocks*) printf 'SS' ;;
    openvpn)                                    printf 'OVPN' ;;
    badvpn-udpgw|udpgw)                         printf 'UDPGW' ;;
    *)                                          printf '' ;;
  esac
}

# Rango de puertos que el kernel reparte al azar para los flujos salientes.
# Todo lo que cae ahí NO es un servicio configurado.
EFIMERO_INI=32768
leer_rango_efimero() {
  local a b
  read -r a b < /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null || return
  [[ "$a" =~ ^[0-9]+$ ]] && EFIMERO_INI="$a"
}

MAX_PTOS=8          # tope por servicio, para que un caso raro no desborde

declare -A PTO_VISTO=()
declare -A CUANTOS=()
agrega_puerto() { # $1=clave del servicio $2=puerto
  local c="$1" p="$2"
  # Sin clave es un programa que no nos interesa (systemd-resolve, postgres…).
  # Hay que cortar ACÁ: con la clave vacía, PUERTO_DE[] tira "bad array
  # subscript" y además el puerto queda marcado como visto, así que si otro
  # servicio de verdad usara ese puerto, ya no se registraría.
  [ -z "$c" ] && return
  [[ "$p" =~ ^[0-9]+$ ]] || return
  (( p >= 1 && p <= 65535 )) || return
  [ -n "${PTO_VISTO[$p]:-}" ] && return      # un puerto, un solo servicio
  (( ${CUANTOS[$c]:-0} >= MAX_PTOS )) && return
  PTO_VISTO[$p]=1
  CUANTOS[$c]=$(( ${CUANTOS[$c]:-0} + 1 ))
  if [ -z "${PUERTO_DE[$c]:-}" ]; then PUERTO_DE[$c]="$p"
  else PUERTO_DE[$c]="${PUERTO_DE[$c]} $p"; fi
}

# --- fuente 1: los sockets que están escuchando --------------------------
# Es la fuente buena: dice lo que el sistema está haciendo AHORA, no lo que
# algún archivo dice que debería hacer.
puertos_de_sockets() {
  local proto pto prog
  while read -r proto pto prog; do
    [ -z "$prog" ] && continue
    # OJO con UDP: no existe el estado "escuchando". `ss -uln` lista TODOS
    # los sockets UDP, incluidos los que el kernel abre al vuelo para cada
    # flujo que udpgw reenvía. En un servidor con 900 clientes aparecen 900
    # "puertos" que no son el servicio, y el panel mostraba +909.
    # El puerto configurado siempre está por debajo del rango efímero.
    if [ "$proto" = u ] && (( pto >= EFIMERO_INI )); then continue; fi
    agrega_puerto "$(clave_servicio "$prog")" "$pto"
  done < <(
    # El campo de proceso viene como:  users:(("sshd",pid=811,fd=3))
    { ss -tlnpH 2>/dev/null | awk -v P=t '
        { n = split($4, a, ":"); p = a[n]; prog = ""
          if (match($0, /users:\(\("[^"]+"/)) prog = substr($0, RSTART+9, RLENGTH-10)
          if (p ~ /^[0-9]+$/ && prog != "") print P, p, prog }'
      ss -ulnpH 2>/dev/null | awk -v P=u '
        { n = split($4, a, ":"); p = a[n]; prog = ""
          if (match($0, /users:\(\("[^"]+"/)) prog = substr($0, RSTART+9, RLENGTH-10)
          if (p ~ /^[0-9]+$/ && prog != "") print P, p, prog }'
    })
}

# --- fuente 2: la línea de comandos de cada demonio ----------------------
# ss a veces no puede decir de quién es el socket y esa línea se pierde
# entera. Acá se recupera leyendo con qué argumentos arrancó cada programa:
# dropbear usa -p, badvpn-udpgw usa --listen-addr ip:puerto.
puertos_de_procesos() {
  local d c cla cmd tok espera
  for d in /proc/[0-9]*; do
    [ -r "$d/comm" ] || continue
    read -r c < "$d/comm" 2>/dev/null || continue
    cla="$(clave_servicio "$c")"
    [ -z "$cla" ] && continue
    cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)
    [ -z "$cmd" ] && continue
    espera=0
    for tok in $cmd; do
      if (( espera )); then
        espera=0
        agrega_puerto "$cla" "${tok##*:}"     # sirve para 109 y para ip:109
        continue
      fi
      case "$tok" in
        -p|--port|-L|--listen|--listen-addr|--local-addr) espera=1 ;;
        --port=*|--listen-addr=*) agrega_puerto "$cla" "${tok##*[=:]}" ;;
        -p[0-9]*)                 agrega_puerto "$cla" "${tok#-p}" ;;
      esac
    done
  done
}

# --- fuente 3: los archivos de configuración -----------------------------
# stunnel nunca lleva el puerto en la línea de comandos, siempre está en el
# archivo. Y el SSH es lo mínimo que el cliente necesita saber.
puertos_de_config() {
  local f pt
  for f in /etc/stunnel/*.conf; do
    [ -r "$f" ] || continue
    while read -r pt; do agrega_puerto SSL "$pt"; done < <(
      awk -F= 'tolower($1) ~ /^[ \t]*accept[ \t]*$/ {
                 gsub(/[ \t]/, "", $2); n = split($2, a, ":"); print a[n] }' "$f" 2>/dev/null)
  done
  if [ -r /etc/default/dropbear ]; then
    while read -r pt; do agrega_puerto DROPBEAR "$pt"; done < <(
      awk -F'[="]' '/^[ \t]*DROPBEAR_PORT/ { print $2 }' /etc/default/dropbear 2>/dev/null)
  fi
  if [ -z "${PUERTO_DE[SSH]:-}" ]; then
    pt=$(awk 'tolower($1)=="port" && $2 ~ /^[0-9]+$/ { print $2 }' /etc/ssh/sshd_config 2>/dev/null | head -4)
    [ -z "$pt" ] && pt=22
    for f in $pt; do agrega_puerto SSH "$f"; done
  fi
}

detectar_puertos() {
  PUERTO_DE=(); PTO_VISTO=(); CUANTOS=(); PUERTOS=""
  leer_rango_efimero
  puertos_de_sockets
  puertos_de_procesos
  puertos_de_config

  # Cada servicio con sus puertos de menor a mayor. Al venir de tres fuentes
  # distintas llegan desordenados, y una lista desordenada parece un error.
  local c
  for c in "${!PUERTO_DE[@]}"; do
    PUERTO_DE[$c]=$(printf '%s\n' ${PUERTO_DE[$c]} | sort -n | tr '\n' ' ')
  done

  # Resumen para la caja de la derecha mientras se carga el formulario. Van
  # sólo los tres primeros: un renglón lleno de números no se lee, se mancha.
  local -a todos=()
  local i p
  for i in "${!CAT_CLA[@]}"; do
    for p in ${PUERTO_DE[${CAT_CLA[i]}]:-}; do todos+=("$p"); done
  done
  PUERTOS="$(lista_corta 22 3 "${todos[@]}")"
  [ -z "$PUERTOS" ] && PUERTOS="—"
}

# Clave sugerida. Se sacan las letras y números que se confunden al dictarla
# por WhatsApp: 0/O, 1/l/i. Si el cliente la tipea mal, te escribe a vos.
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
dur_txt() {
  if (( ES_DEMO )); then printf '%s min · PRUEBA' "$DEMO_MIN"
  elif [ -n "$DIAS" ]; then printf '%s días' "$DIAS"; fi
}
lim_txt() {
  [ -n "$LIMITE" ] || return
  (( LIMITE == 1 )) && printf '1 simultánea' || printf '%s simultáneas' "$LIMITE"
}
# En una cuenta normal alcanza con la fecha. En una de prueba hace falta la
# hora, porque se vence el mismo día.
vence_txt() {
  if (( ES_DEMO )) && (( DEMO_HASTA > 0 )); then
    printf '%(%d/%m a las %H:%M)T' "$DEMO_HASTA"
  elif [ -n "$VENCE" ]; then printf '%s' "$VENCE"; fi
}

# Prefijos de la columna izquierda. Tienen que medir EXACTAMENTE 39 columnas,
# porque caja_der aporta las otras 39 (2 de separación + borde + 35 + borde).
# Sirven para que la caja de la izquierda cierre antes y la de la derecha siga
# sola hacia abajo.
izq_cierra() { printf '  %s╰%s╯%s' "$M_DAT" "$(rep '─' 35)" "$E_RST"; }
izq_nada()   { printf '%*s' 39 ''; }
izq_titulo() { # $1=título, a lo ancho de la columna izquierda
  printf '  %s▌%s %s%s%s %s%s%s' "$E_PINK" "$E_RST" "$E_BLD" "$E_TXT" "$1" \
         "$E_OFF" "$(rep '─' $(( 34 - ${#1} )))" "$E_RST"
}
izq_opcion() { # $1=número $2=texto
  # 2 de sangría + 2 del número + 1 de aire + 34 del texto = 39
  printf '  %s%s%s %s%s%s' "$E_BLD$E_P1" "$1" "$E_RST" "$E_BLD$E_TXT" "$(pad "$2" 34)" "$E_RST"
}

# Un servicio dentro de la caja derecha, sin icono:
#   1 de sangría + nombre 21 + puerto 13 = 35
# El puerto va en menta y el OFF en coral: el mismo par que el menú principal
# usa para ● ON y ○ OFF. Así se lee prendido o apagado por el color, sin
# tener que leer el número. En ámbar se confundía con el marco de la caja.
srv_der() { # $1=índice del catálogo
  local i="$1" v col
  v="${PUERTO_DE[${CAT_CLA[i]}]:-}"
  if [ -z "$v" ]; then
    v="OFF"; col="$E_BLD$E_ERR"
  else
    # Hasta 3 puertos se muestran todos. Pasando de 3 van sólo 2 y el resto
    # se resume en el +N: una fila con cuatro números es un manchón.
    local -a pts=($v) tope=3
    (( ${#pts[@]} > 3 )) && tope=2
    v="$(lista_corta 18 "$tope" "${pts[@]}")"; col="$E_BLD$E_OK"
  fi
  # 1 de sangría + nombre 16 + puerto 18 = 35
  # El nombre va en el mismo gris que IP, USUARIO y CLAVE: son todas
  # etiquetas, y el color fuerte queda para el dato, que es lo que se copia.
  caja_der " $E_MUT$(pad "${CAT_NOM[i]}" 16)$E_RST$col$(rpad "$v" 18)$E_RST" "$M_CLI"
}

paneles() {
  techo "DATOS DE LA CUENTA" "$E_PINK" "PARA EL CLIENTE" "$E_WARN" "$M_DAT" "$M_CLI"

  if (( PASO == 6 )); then
    # Con la cuenta creada, la caja del cliente sigue hacia abajo con los
    # servicios: todo lo que hay que mandarle queda en un solo bloque.
    # La izquierda cierra apenas termina el estado, y el hueco que deja lo
    # ocupan las opciones, para que no queden perdidas abajo de todo.
    fd "USUARIO"    "$USUARIO"       "$E_BLD$E_TXT" ; fc "IP"      "$IP_PUB"      "$E_BLD$E_TXT"
    fd "CONTRASEÑA" "$CLAVE"         "$E_BLD$E_TXT" ; fc "USUARIO" "$USUARIO"     "$E_BLD$E_OK"
    fd "DURACIÓN"   "$(dur_txt)"     "$E_TXT"       ; fc "CLAVE"   "$CLAVE"       "$E_BLD$E_OK"
    fd "LÍMITE"     "$(lim_txt)"     "$E_TXT"       ; fc "VENCE"   "$(vence_txt)" "$E_INFO"
    fil_dat "ESTADO" "$(estado_col)" "$(estado_txt)" ; srv_der 0
    izq_cierra                                       ; srv_der 1
    izq_nada                                         ; srv_der 2
    izq_titulo "¿QUÉ HACÉS AHORA?"                   ; srv_der 3
    izq_nada                                         ; srv_der 4
    izq_opcion "01" "CREAR OTRA CUENTA"              ; srv_der 5
    izq_opcion "00" "VOLVER AL PANEL"                ; srv_der 6
    izq_nada                                         ; srv_der 7
    # Sólo cierra la derecha: la izquierda ya cerró más arriba
    printf '%*s  %s╰%s╯%s\n' 39 '' "$M_CLI" "$(rep '─' 35)" "$E_RST"
  else
    fd "USUARIO"    "$USUARIO"      "$E_BLD$E_TXT" ; fc "IP"       "$IP_PUB"       "$E_BLD$E_TXT"
    fd "CONTRASEÑA" "$CLAVE"        "$E_BLD$E_TXT" ; fc "PUERTOS"  "$PUERTOS"      "$E_BLD$E_P1"
    fd "DURACIÓN"   "$(dur_txt)"    "$E_TXT"       ; fc "USUARIO"  "$USUARIO"      "$E_BLD$E_OK"
    fd "LÍMITE"     "$(lim_txt)"    "$E_TXT"       ; fc "CLAVE"    "$CLAVE"        "$E_BLD$E_OK"
    fil_dat "ESTADO" "$(estado_col)" "$(estado_txt)" ; fc "VENCE"  "$(vence_txt)"  "$E_INFO"
    piso "$M_DAT" "$M_CLI"
  fi
}

linea_aviso() {
  if [ -n "$AVISO" ]; then printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  else printf '  %s\n' "$(pad '' 76)"; fi
}

# La ayuda cambia según el paso: explica qué se espera ANTES de que escriba,
# no después de que se equivoque.
AYUDA=("" \
  "Minúsculas, números y guiones. Escribí  demo  para una cuenta de prueba." \
  "ENTER solo = genero una al azar, fácil de dictar." \
  "Cuántos días dura la cuenta. Lo normal: 30." \
  "Cuántos dispositivos puede usar a la vez. Lo normal: 1 o 2." \
  "Revisá que esté todo bien. S para crear, N para empezar de nuevo." \
  "Copiá los datos de la derecha y mandáselos al cliente.")

# La salida va como una opción más, con su número, igual que en el resto del
# panel. Antes era una nota al pie en gris apagado: sobre el fondo oscuro no
# se leía, así que el que entraba veía que le pedían un usuario y no sabía
# cómo salir. Escrito pero invisible es lo mismo que no estar.
opcion_volver() {
  local t
  if (( PASO == 1 )); then t="VOLVER AL PANEL"; else t="VOLVER AL PASO ANTERIOR"; fi
  printf '  %s00%s %s%s%s\n' "$E_BLD$E_P1" "$E_RST" "$E_BLD$E_TXT" "$(pad "$t" 73)" "$E_RST"
}

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
  if (( PASO == 6 )); then
    : # los datos y las opciones ya están dentro del panel de arriba
  else
    seccion "PASO $PASO · ${NOMBRE_PASO[$PASO]}" "$E_P2"
    echo
    printf '  %s%s%s\n' "$E_MUT" "$(pad "${AYUDA[$PASO]}" 76)" "$E_RST"
    echo
    opcion_volver
  fi
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
  ES_DEMO=0; DEMO_HASTA=0
}

# Volver un paso y borrar lo que se había cargado ahí, para que el campo
# quede vacío y se vea que hay que escribirlo de nuevo.
atras() {
  AVISO=""
  case $PASO in
    1) clear; exit 0 ;;
    2) USUARIO=""; PASO=1 ;;
    3) CLAVE="";   PASO=2 ;;
    4) DIAS="";    VENCE=""; PASO=3 ;;
    5) LIMITE="";  PASO=4 ;;
  esac
}

# ============================================================ CUENTA DEMO ===
# Para que el cliente pruebe antes de pagar. Se crea de una, sin preguntar
# nada: nombre libre, clave al azar, una sola conexión y una hora de vida.
crear_demo() {
  local i u=""
  for i in 1 2 3 4 5 6 7 8 9 10; do
    local cand="demo$(( RANDOM % 9000 + 1000 ))"
    id "$cand" >/dev/null 2>&1 || { u="$cand"; break; }
  done
  [ -z "$u" ] && { AVISO="No encontré un nombre libre para la prueba"; return 1; }

  USUARIO="$u"; CLAVE="$(clave_azar)"; LIMITE=1; DIAS=""
  ES_DEMO=1
  printf -v DEMO_HASTA '%(%s)T' -1
  DEMO_HASTA=$(( DEMO_HASTA + DEMO_MIN * 60 ))

  # Techo de seguridad: aunque nunca más abras el panel y nadie corra la
  # limpieza, el sistema la da de baja mañana por su cuenta.
  VENCE=$(date -d "+1 day" +%Y-%m-%d 2>/dev/null)
  [ -z "$VENCE" ] && { AVISO="No pude calcular el vencimiento"; return 1; }

  crear || return 1

  mkdir -p "$DIR/db"
  printf '%s %s\n' "$USUARIO" "$DEMO_HASTA" >> "$DIR/db/demos"
  return 0
}

# ================================================================= MAIN =====
exigir_ancho
datos_sistema
cachear_cabecera
detectar_puertos
kira_purgar_demos "$DIR"    # se lleva las pruebas que ya vencieron
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
      case "${RESP,,}" in
        0|00) clear; exit 0 ;;
        demo|prueba|test)
              if crear_demo; then PASO=6; fi ;;
        *)    if val_usuario "$RESP"; then USUARIO="$RESP"; PASO=2; fi ;;
      esac
      ;;
    2)
      preguntar "Contraseña:"
      AVISO=""
      case "$RESP" in 0|00) atras; continue ;; esac
      [ -z "$RESP" ] && RESP="$(clave_azar)"        # ENTER solo = al azar
      if val_clave "$RESP"; then CLAVE="$RESP"; PASO=3; fi
      ;;
    3)
      preguntar "Días:"
      AVISO=""
      case "$RESP" in 0|00) atras; continue ;; esac
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
      case "$RESP" in 0|00) atras; continue ;; esac
      [ -z "$RESP" ] && RESP=1                      # ENTER solo = 1 conexión
      if val_numero "$RESP" "$MAX_CONEX" "Límite"; then
        LIMITE=$(( 10#$RESP )); PASO=5
      fi
      ;;
    5)
      preguntar "¿Creo la cuenta? (s/n):"
      AVISO=""
      case "${RESP,,}" in
        0|00)       atras ;;
        s|si|sí|"") if crear; then PASO=6; fi ;;
        n|no)       limpiar_campos ;;
        *)          AVISO="Respondé s para crear, n para empezar de nuevo o 0 para volver" ;;
      esac
      ;;
    6)
      preguntar "Opción:"
      case "${RESP,,}" in
        1|01)  limpiar_campos ;;
        0|00|"") clear; exit 0 ;;
        *)     AVISO="Elegí 01 para crear otra o 00 para volver" ;;
      esac
      ;;
  esac
done