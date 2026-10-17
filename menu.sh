#!/bin/bash
# =============================================================================
#  KIRA · ADMINISTRADOR DE VPS · menú principal
#  Rejilla fija de 78 columnas · color verdadero de 24 bits
#  Requiere: bash 4+, locale UTF-8. Todo lo demás tiene respaldo.
# =============================================================================
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8

ANCHO=78
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD="$DIR/modules"

# Paleta, utilería, marcos y volcado de pantalla viven en lib/ui.sh: una
# sola copia para el menú y para todos los módulos. Si estuvieran
# duplicados, cambiar un color acá dejaría los módulos con el viejo.
# Si falta, `source` sigue de largo y después salen cientos de "command not
# found" que no dicen nada. Mejor una línea clara y salir.
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
  printf '  Creá la carpeta con:  \e[1mmkdir -p %s/lib\e[0m\n' "$DIR"
  printf '  y pegá ahí el archivo ui.sh.\n'
  exit 1
fi
KIRA_DIR="$DIR"
source "$DIR/lib/ui.sh"

# lib/ui.sh crece con el tiempo. Si el módulo es nuevo y la librería vieja,
# bash tira "command not found" por cada llamada y la pantalla se inunda:
# cientos de errores que no dicen cuál es el problema real. Mejor comprobar
# una vez qué funciones faltan y decirlo en una línea.
ui_exige() {
  local f faltan=""
  for f in "$@"; do declare -F "$f" >/dev/null 2>&1 || faltan="$faltan $f"; done
  [ -z "$faltan" ] && return 0
  printf '\e[1;38;2;255;95;109m✖ Tu lib/ui.sh está desactualizado\e[0m\n'
  printf '  Le faltan estas funciones:\e[1m%s\e[0m\n' "$faltan"
  printf '  Actualizalo con:  \e[1mcd %s && git pull\e[0m\n' "$KIRA_DIR"
  exit 1
}
ui_exige techo piso banda cabecera cachear_cabecera datos_sistema barra pad rpad


# ================================================================ DATOS =====
# Puertos en escucha. ss → netstat → /proc/net. El último siempre existe en
# Linux, así que funciona hasta en imágenes mínimas sin iproute2.
LISTEN=""
cargar_puertos() {
  if command -v ss >/dev/null 2>&1; then
    LISTEN=$(ss -tuln 2>/dev/null | awk 'NR>1{n=split($5,a,":"); print a[n]}')
  elif command -v netstat >/dev/null 2>&1; then
    LISTEN=$(netstat -tuln 2>/dev/null | awk '/^(tcp|udp)/{n=split($4,a,":"); print a[n]}')
  else
    local f; mapfile -t f < <(procnet /proc/net/tcp /proc/net/tcp6 /proc/net/udp /proc/net/udp6)
    [ ${#f[@]} -eq 0 ] && { LISTEN=""; return; }
    LISTEN=$(awk 'FNR>1 && ($4=="0A" || $4=="07"){split($2,a,":"); print strtonum("0x" a[2])}' \
             "${f[@]}" 2>/dev/null)
  fi
}
puerto_activo() { grep -qx "$1" <<< "$LISTEN"; }

servicio_activo() { # $1=unidad systemd  $2=patrón de proceso (opcional)
  systemctl is-active --quiet "$1" 2>/dev/null && return 0
  [ -n "${2:-}" ] && pgrep -f "$2" >/dev/null 2>&1 && return 0
  return 1
}

# Con IPv6 apagado /proc/net/tcp6 no existe y awk aborta SIN imprimir nada:
# hay que pasarle sólo los archivos presentes.
procnet() { local f o=(); for f in "$@"; do [ -r "$f" ] && o+=("$f"); done; printf '%s\n' "${o[@]}"; }

# Conexiones TCP establecidas. ss → /proc/net/tcp (estado 01 = ESTABLISHED).
conexiones() {
  if command -v ss >/dev/null 2>&1; then
    ss -tn state established 2>/dev/null | tail -n +2 | wc -l
  else
    local f; mapfile -t f < <(procnet /proc/net/tcp /proc/net/tcp6)
    [ ${#f[@]} -eq 0 ] && { echo 0; return; }
    awk 'FNR>1 && $4=="01"{n++} END{print n+0}' "${f[@]}" 2>/dev/null
  fi
}

# Velocidad de red por diferencia entre dos lecturas de /proc/net/dev.
# Se descarta lo (loopback): si no, el tráfico local infla la cifra.
NET_RX_ANT=0; NET_TX_ANT=0; NET_T_ANT=0
net_medir() {
  local rx tx up
  read -r rx tx < <(awk '/:/{split($0,a,":"); f=a[1]; gsub(/ /,"",f);
      if (f=="lo") next; n=split(a[2],b," "); rx+=b[1]; tx+=b[9] }
      END{print rx+0, tx+0}' /proc/net/dev 2>/dev/null)
  read -r up _ < /proc/uptime
  NET_RX_TOT=$(bytes_hum "${rx:-0}")
  NET_TX_TOT=$(bytes_hum "${tx:-0}")
  local dt; dt=$(awk -v a="$up" -v b="$NET_T_ANT" 'BEGIN{printf "%.2f", a-b}')
  if awk -v d="$dt" 'BEGIN{exit !(d>0.1)}' && [ "$NET_T_ANT" != "0" ]; then
    NET_RX_VEL="$(bytes_hum "$(awk -v a="$rx" -v b="$NET_RX_ANT" -v d="$dt" 'BEGIN{printf "%d", (a-b)/d}')")/s"
    NET_TX_VEL="$(bytes_hum "$(awk -v a="$tx" -v b="$NET_TX_ANT" -v d="$dt" 'BEGIN{printf "%d", (a-b)/d}')")/s"
  else
    NET_RX_VEL="—"; NET_TX_VEL="—"
  fi
  NET_RX_ANT="$rx"; NET_TX_ANT="$tx"; NET_T_ANT="$up"
}

cpu_snap() { awk '/^cpu /{idle=$5; tot=0; for(i=2;i<=NF;i++) tot+=$i; print idle, tot}' /proc/stat; }

# SIN sleep. Antes dormía 0.2s para tomar dos muestras, y ese bloqueo era la
# mayor parte del retardo al teclear. Ahora guarda la muestra anterior entre
# vueltas del bucle: la ventana pasa a ser ~1s, que además mide mejor.
CPU_I_ANT=0; CPU_T_ANT=0
cpu_pct() {
  local i2 t2
  read -r i2 t2 < <(cpu_snap)
  local dt=$(( t2 - CPU_T_ANT )) di=$(( i2 - CPU_I_ANT ))
  CPU_I_ANT=$i2; CPU_T_ANT=$t2
  (( dt <= 0 )) && { echo 0; return; }
  echo $(( (100 * (dt - di)) / dt ))
}

IP_PUB="";  SSH_PORTS=""
cargar_fijos() {   # lo que no cambia: se consulta una sola vez
  datos_sistema    # IP y SO, desde lib/ui.sh (con caché de la IP)
  # sshd_config puede no declarar Port: el valor por omisión es 22
  SSH_PORTS=$(awk '/^[[:space:]]*Port[[:space:]]+[0-9]+/{print $2}' \
              /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | sort -un | tr '\n' ' ')
  [ -z "${SSH_PORTS// }" ] && SSH_PORTS="22 "
}

cargar_vivos() {   # lo que cambia en cada refresco
  FECHA=$(date "+%d/%m/%Y %H:%M:%S")
  read -r RAM_USA RAM_TOT < <(free -m 2>/dev/null | awk '/^Mem:/{print $3, $2}')
  : "${RAM_USA:=0}"; : "${RAM_TOT:=1}"
  RAM_PCT=$(( RAM_USA * 100 / (RAM_TOT>0?RAM_TOT:1) ))
  read -r SWP_USA SWP_TOT < <(free -m 2>/dev/null | awk '/^Swap:/{print $3, $2}')
  : "${SWP_USA:=0}"; : "${SWP_TOT:=0}"
  SWP_PCT=$(( SWP_TOT>0 ? SWP_USA*100/SWP_TOT : 0 ))
  read -r DSK_USA DSK_TOT DSK_PCT < <(df -h --output=used,size,pcent / 2>/dev/null | awk 'NR==2{gsub("%","",$3); print $1, $2, $3}')
  : "${DSK_USA:=0}"; : "${DSK_TOT:=0}"; : "${DSK_PCT:=0}"
  CPU_PCT=$(cpu_pct)
  NUCLEOS=$(nproc 2>/dev/null || echo 1)
  UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //; s/ days\?/d/; s/ hours\?/h/; s/ minutes\?/m/; s/,//g')
  [ -z "$UPTIME" ] && UPTIME="?"
  net_medir
  CONEX=$(conexiones)
  USUARIOS=$(awk -F: '$3>=1000 && $1!="nobody"{n++} END{print n+0}' /etc/passwd 2>/dev/null)

  cargar_puertos
  servicio_activo ssh sshd          && ST_SSH=on   || ST_SSH=off
  servicio_activo dropbear          && ST_DROP=on  || ST_DROP=off
  puerto_activo 443                 && ST_SSL=on   || ST_SSL=off
  puerto_activo 53                  && ST_DNS=on   || ST_DNS=off
  pgrep -f badvpn >/dev/null 2>&1   && ST_BAD=on   || ST_BAD=off
  servicio_activo v2ray v2ray       && ST_V2=on    || ST_V2=off
  puerto_activo 80                  && ST_HTTP=on  || ST_HTTP=off

  # Estado de cada módulo: existe el script / está habilitado el servicio
  [ -f "$MOD/user.sh" ]      && M_USER=on  || M_USER=off
  [ -f "$MOD/optimize.sh" ]  && M_OPT=on   || M_OPT=off
  [ -f "$MOD/online.sh" ]    && M_ONLINE=on || M_ONLINE=off
  systemctl is-enabled --quiet kira 2>/dev/null && M_AUTO=on || M_AUTO=off
  [ -f "$MOD/protocols.sh" ] && M_PROTO=on || M_PROTO=off
  [ -f "$DIR/monitor.sh" ]   && M_MON=on   || M_MON=off
  [ -f "$MOD/update.sh" ]    && M_UPD=on   || M_UPD=off
  OPC_EST=("$M_USER" "$M_OPT" "$M_ONLINE" "$M_AUTO" "$M_PROTO" "$M_MON" "$M_UPD" "")

  # Al final de todo: si se arma antes, la caché guarda los estados de la
  # vuelta ANTERIOR y los servicios se ven con un segundo de atraso.
  PANELES_CACHE="$(banda; echo; paneles)"
}

# ============================================================= PANTALLA =====
# cabecera(), banda() y datos_sistema() viven en lib/ui.sh: una sola copia
# para el menú y para todos los módulos.

# Ambas cajas miden 37 columnas: bordes en 2, 38, 41 y 77. El contenido
# entre bordes mide SIEMPRE 35. Se arma el cuerpo primero y se imprime con
# un solo %s: si la cantidad de marcadores no coincide con la de argumentos,
# printf repite el formato y mete líneas fantasma.

srv() { # $1=nombre $2=on/off $3=detalle · 1+11+5+18 = 35
  local e c
  if [ "$2" = "on" ]; then e="● ON "; c="$E_OK"; else e="○ OFF"; c="$E_ERR"; fi
  caja_izq " $E_TXT$(pad "$1" 11)$E_RST$c$e$E_RST$E_MUT$(pad " $3" 18)$E_RST"
}
rec() { # $1=etiqueta $2=pct $3=valor · 1+6+12+1+4+1+10 = 35
  caja_der " $E_MUT$(pad "$1" 6)$E_RST$(barra "$2" 12) $E_TXT$(rpad "$2" 4)%$E_RST$E_MUT$(pad " $3" 10)$E_RST"
}
rec_txt() { # fila sin barra · 1+6+16+12 = 35
  caja_der " $E_MUT$(pad "$1" 6)$E_RST$E_TXT$(pad "$2" 16)$E_RST$E_MUT$(pad "$3" 12)$E_RST"
}

# Convierte megabytes a una forma corta que entre en la columna:
# 522 8029 -> "0.5/7.8G"   (en bytes crudos la línea desborda)
hum() { awk -v u="$1" -v t="$2" 'BEGIN{
  if (t >= 1024) printf "%.1f/%.1fG", u/1024, t/1024; else printf "%d/%dM", u, t }'; }

paneles() {
  techo "SERVICIOS" "$E_P1" "RECURSOS" "$E_P2"

  srv "SSH"       "$ST_SSH"  "${SSH_PORTS% }" ; rec "RAM"   "$RAM_PCT" "$(hum "$RAM_USA" "$RAM_TOT")"
  srv "DROPBEAR"  "$ST_DROP" "90 · 143"       ; rec "CPU"   "$CPU_PCT" "${NUCLEOS} vCPU"
  srv "SSL/TLS"   "$ST_SSL"  "443"            ; rec "DISCO" "$DSK_PCT" "${DSK_USA}/${DSK_TOT}"
  srv "SLOWDNS"   "$ST_DNS"  "53"             ; rec "SWAP"  "$SWP_PCT" "$(hum "$SWP_USA" "$SWP_TOT")"
  srv "BADVPN"    "$ST_BAD"  "7300"           ; rec_txt "RED ▼" "$NET_RX_VEL" "total $NET_RX_TOT"
  srv "V2RAY"     "$ST_V2"   "10086"          ; rec_txt "RED ▲" "$NET_TX_VEL" "total $NET_TX_TOT"
  srv "HTTP"      "$ST_HTTP" "80"             ; rec_txt "CONEX" "$CONEX establecidas" ""

  piso
}


# TODOS los emoji van del bloque U+1F300 en adelante: ésos miden 2 columnas
# en cualquier terminal. Los heredados U+26xx/U+27xx (⚡ ⚙ ✦ 🌐 de trazo fino)
# cambian de ancho o de tamaño según el cliente y desalinean la columna.
OPC_NUM=(01 02 03 04 05 06 07 00)
OPC_EMO=("👥" "🔧" "📡" "🚀" "📦" "📊" "🔄" "🚪")
OPC_TXT=("CONTROL DE USUARIOS" "OPTIMIZAR VPS" "USUARIOS ONLINE" "AUTO INICIO"
         "INSTALADOR DE PROTOCOLOS" "MONITOR EN TIEMPO REAL" "ACTUALIZAR SCRIPT" "SALIR")
OPC_PAD=(); OPC_EST=()
PUNTOS=""; RAYA=""; EST_ON=""; EST_OFF=""; EST_NADA=""; SECCION_FIJA=""

# Las etiquetas rellenadas, los puntos, la raya y los tres estados posibles
# son CONSTANTES: se arman una sola vez. Antes cada repintado lanzaba ~40
# subshells (uno por cada pad/rep/sel_de) y eso era todo el costo del cuadro.
cachear_menu() {
  local i
  for i in "${!OPC_TXT[@]}"; do OPC_PAD[i]="$(pad "${OPC_TXT[i]}" 30)"; done
  PUNTOS="$(rep '·' 26)"
  RAYA="$(rep '─' 76)"
  # El círculo va SIEMPRE en la misma columna: bullet a la izquierda y la
  # palabra rellenada a 3. Alineando "● ON" y "○ OFF" a la derecha, ON mide 2
  # y OFF mide 3, y los círculos quedan escalonados.
  EST_ON="$E_BLD$E_OK  ● $(pad 'ON' 3)$E_RST"
  EST_OFF="$E_BLD$E_ERR  ○ $(pad 'OFF' 3)$E_RST"
  EST_NADA="$(rpad '' 7)"
  SECCION_FIJA="$(seccion 'MENÚ PRINCIPAL' "$E_P1")"
}

# Sin una sola sustitución de comando: todo sale de las tablas de arriba.
# 2 + bar1 + sp1 + chip4 + sp1 + emoji2 + sp1 + sep1 + sp1 + etiq30
#   + guía26 + sp1 + est7 = 78
menu() {
  printf '%s\n\n' "$SECCION_FIJA"
  local i est f bar chip pts n
  for i in 0 1 2 3 4 5 6 7; do
    (( i == 7 )) && printf '\n  %s%s%s\n' "$E_OFF" "$RAYA" "$E_RST"
    case "${OPC_EST[i]}" in
      on)  est="$EST_ON" ;;
      off) est="$EST_OFF" ;;
      *)   est="$EST_NADA" ;;
    esac
    n="${OPC_NUM[i]}"
    # La fila se resalta sólo si coincide con lo que se está tecleando.
    if [ -n "$BUF" ] && { [ "$BUF" = "$n" ] || [ "$BUF" = "${n#0}" ]; }; then
      f="$B_SEL"; bar="$E_P1▌$E_RST$f"; chip="$B_CHIP$E_BLD$E_P1"; pts="$E_MUT"
    else
      f=""; bar="$E_OFF▏$E_RST"; chip="$B_CHIP$E_P1"; pts="$E_OFF"
    fi
    printf '%s  %s %s %s %s %s%s %s%s\n' \
      "$f" "$bar" "$chip $n $E_RST$f" "$E_P2${OPC_EMO[i]}$E_RST$f" "$E_OFF│$E_RST$f" \
      "$E_BLD$E_TXT${OPC_PAD[i]}$E_RST$f" "$pts$PUNTOS$E_RST$f" "$est" "$E_RST"
  done
}

# Un solo prompt. El decorativo "KIRA@host:~#" sobraba: abajo ya aparecía
# el "Opción:" real del read y se leían dos prompts encima del otro.
prompt() {
  # "  ❯ Opción: " = 12 columnas + lo tecleado + cursor
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( 78 - vis )) ''
}

# Al teclear sólo cambian el menú y el prompt. Los paneles se reusan desde
# la caché: rearmarlos en cada tecla costaba ~40ms de más.
pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  printf '%s\n' "$PANELES_CACHE"
  echo
  menu
  echo
  prompt
}

# Un cuadro = UNA escritura. Antes cada printf llegaba suelto por la red y la
# pantalla se veía temblar mientras se dibujaba. Se arma todo en memoria y se
# vuelca de golpe, con el cursor oculto y marcando el cuadro como atómico
# (\e[?2026h/l) para los clientes que lo soportan.
render() { local f; f="$(pintar)"; volcar "$f"; }

# ============================================================== MÓDULOS =====
abrir() { # $1=ruta $2=nombre
  if [ -f "$1" ]; then
    bash "$1"
  else
    printf '\n  %s%s✖ %s no está instalado%s\n' "$E_BLD" "$E_ERR" "$2" "$E_RST"
    printf '  %sfalta el archivo: %s%s\n\n' "$E_MUT" "$1" "$E_RST"
    read -rsn1 -p "  Pulsa una tecla para volver…"
  fi
}

# ================================================================= MAIN =====
exigir_ancho

ejecutar() {
  case "$1" in
    1|01) abrir "$MOD/user.sh"      "Control de usuarios" ;;
    2|02) abrir "$MOD/optimize.sh"  "Optimizar VPS" ;;
    3|03) abrir "$MOD/online.sh"    "Usuarios online" ;;
    4|04) abrir "$MOD/autostart.sh" "Auto inicio" ;;
    5|05) abrir "$MOD/protocols.sh" "Instalador de protocolos" ;;
    6|06) abrir "$DIR/monitor.sh"   "Monitor en tiempo real" ;;
    7|07) abrir "$MOD/update.sh"    "Actualizar script" ;;
    0|00) clear; exit 0 ;;
    "")   return ;;
    *)    printf '\n  %s%s✖ Opción inválida%s\n\n' "$E_BLD" "$E_ERR" "$E_RST"; sleep 1 ;;
  esac
  clear        # el módulo dejó su propia salida: pantalla limpia al volver
  cursor_off   # el módulo pudo mostrar el cursor: se vuelve a ocultar
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;   # ENTER
    $'\177'|$'\b') BUF="${BUF%?}" ;;            # borrar
    [0-9])         [ ${#BUF} -lt 2 ] && BUF="$BUF$1" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;  # descarta flechas
  esac
}

# El vigilante de conexiones tiene que quedar andando sin que el que compró
# el panel toque nada. Se revisa cada vez que se abre el menú y, si no está
# corriendo, se instala solo y en silencio. Va al fondo para no demorar el
# arranque, y sólo como root: sin permisos no hay nada que instalar.
asegurar_vigilante() {
  [ "$(id -u)" -eq 0 ] || return 0
  [ -f "$DIR/kira-vigilante" ] || return 0
  local puesto="/usr/local/sbin/kira-vigilante"
  # El servicio corre desde una COPIA en /usr/local/sbin. Actualizar el repo
  # no la toca, así que además de ver si está andando hay que comparar: si la
  # del repo es distinta, se reinstala y el servicio arranca con lo nuevo.
  # Sin esto, el cliente actualiza y sigue corriendo la versión vieja sin que
  # nada se lo avise.
  if [ -f "$puesto" ] && cmp -s "$DIR/kira-vigilante" "$puesto"; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl is-active --quiet kira-vigilante 2>/dev/null && return 0
    else
      return 0
    fi
  fi
  KIRA_DIR="$DIR" bash "$DIR/kira-vigilante" --instalar >/dev/null 2>&1 &
}

# kira-limite corre desde una copia en /usr/local/sbin que PAM llama en cada
# login. Igual que con el vigilante, actualizar el repo no la toca: si ya
# estaba instalado y la copia quedó vieja, se la reemplaza. Si nunca se
# instaló, no se instala solo: tocar PAM es decisión del dueño.
asegurar_limite() {
  [ "$(id -u)" -eq 0 ] || return 0
  local puesto="/usr/local/sbin/kira-limite"
  [ -f "$puesto" ] && [ -f "$DIR/kira-limite" ] || return 0
  cmp -s "$DIR/kira-limite" "$puesto" && return 0
  KIRA_DIR="$DIR" bash "$DIR/kira-limite" --instalar >/dev/null 2>&1
}
asegurar_vigilante
asegurar_limite

cargar_fijos
cachear_cabecera
cachear_menu
# El cursor real parpadeando mientras se repinta suma al temblor: se oculta
# y se dibuja uno propio en el prompt. El trap lo devuelve pase lo que pase.
# El manejador de INT/TERM DEBE salir. Si sólo limpia, Ctrl+C ejecuta el
# trap y el bucle sigue corriendo: no hay forma de cortar el script.
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear' EXIT
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear; exit 130' INT TERM
cursor_off
clear
net_medir           # primera lectura: fija la base de red
cpu_pct >/dev/null  # primera muestra de CPU: la siguiente ya mide un intervalo
BUF=""
SEG_ANT=-1

# El bucle NO se queda bloqueado en `read`: espera una tecla hasta 0.8s y si
# no llega, repinta con datos frescos. Así la hora y los recursos avanzan
# solos. Se lee tecla por tecla (en vez de `read -t` sobre la línea entera)
# para no perder lo ya tecleado cuando vence el tiempo.
while true; do
  # Los datos se recogen UNA vez por segundo; el repintado va aparte. Antes se
  # recolectaba en cada vuelta (320ms) y la tecla tardaba en aparecer.
  printf -v ahora '%(%s)T' -1
  if [ "$ahora" != "$SEG_ANT" ]; then cargar_vivos; SEG_ANT="$ahora"; fi
  render
  read -rsn1 -t 0.25 tecla; rc=$?
  # read devuelve >128 si venció el tiempo y 1 si stdin se cerró. Sin separar
  # los dos casos, al cerrarse la sesión el bucle gira a máxima velocidad y
  # clava la CPU en 100%.
  if (( rc == 0 )); then
    procesar "$tecla"
    # Vacía lo que quedó en el búfer del teclado ANTES de repintar. Al borrar
    # se pulsa la tecla dos o tres veces seguidas; sin esto cada pulsación
    # pagaba un repintado entero y la segunda se sentía trabada.
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0          # stdin cerrado: salir en vez de girar en vacío
  fi
done