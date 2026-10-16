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

# ============================================================== PALETA ======
# \e[38;2;R;G;Bm = texto · \e[48;2;R;G;Bm = fondo. Si el cliente no soporta
# color verdadero el degradado se ve plano, pero nada se rompe.
C_P1="45;212;232"    # cian    · primario
C_P2="155;140;255"   # violeta · marca
C_OK="63;224;168"    # menta   · ON
C_WARN="255;194;71"  # ámbar   · aviso
C_ERR="255;95;109"   # coral   · OFF
C_INFO="95;168;255"  # azul    · dato
C_MUT="111;125;156"  # gris    · secundario
C_TXT="220;228;245"  # texto
C_BORDE="40;64;106"
C_BAND="22;35;60"
C_SEL="19;34;65"
C_OFF="28;39;66"
C_CHIP="25;41;70"
G1=(45 212 232); G2=(199 125 238)   # degradado del logo

E_RST=$'\e[0m'; E_BLD=$'\e[1m'
E_P1=$'\e[38;2;'"$C_P1"'m';     E_P2=$'\e[38;2;'"$C_P2"'m'
E_OK=$'\e[38;2;'"$C_OK"'m';     E_WARN=$'\e[38;2;'"$C_WARN"'m'
E_ERR=$'\e[38;2;'"$C_ERR"'m';   E_INFO=$'\e[38;2;'"$C_INFO"'m'
E_MUT=$'\e[38;2;'"$C_MUT"'m';   E_TXT=$'\e[38;2;'"$C_TXT"'m'
E_BOR=$'\e[38;2;'"$C_BORDE"'m'; E_OFF=$'\e[38;2;'"$C_OFF"'m'
B_BAND=$'\e[48;2;'"$C_BAND"'m'; B_SEL=$'\e[48;2;'"$C_SEL"'m'
B_CHIP=$'\e[48;2;'"$C_CHIP"'m'

# ============================================================ UTILERÍA ======
# OJO: en `local a=$1 b=$((a+1))` bash expande TODAS las asignaciones antes de
# aplicarlas, así que b NO ve a `a`. Siempre en líneas separadas.
# OJO 2: printf "%-30s" cuenta BYTES. Con tildes (caché, tráfico, Menú) la
# columna se descuadra. pad() usa ${#s}, que cuenta caracteres.
pad()  { local s="$1" w="$2"; local n=$(( w - ${#s} )); ((n<0)) && n=0; printf '%s%*s' "$s" "$n" ''; }
rpad() { local s="$1" w="$2"; local n=$(( w - ${#s} )); ((n<0)) && n=0; printf '%*s%s' "$n" '' "$s"; }
rep()  { local i; for ((i=0;i<$2;i++)); do printf '%s' "$1"; done; }

mezcla() { # $1=i $2=n -> "R;G;B" interpolado entre G1 y G2
  local i=$1 n=$2
  (( n < 2 )) && n=2
  local r=$(( G1[0] + (G2[0]-G1[0])*i/(n-1) ))
  local g=$(( G1[1] + (G2[1]-G1[1])*i/(n-1) ))
  local b=$(( G1[2] + (G2[2]-G1[2])*i/(n-1) ))
  printf '%d;%d;%d' "$r" "$g" "$b"
}

regla() { # $1=caracter $2=ancho · regla con degradado
  local i; printf '  '
  for ((i=0;i<$2;i++)); do printf '\e[38;2;%sm%s' "$(mezcla "$i" "$2")" "$1"; done
  printf '%s\n' "$E_RST"
}

grad_txt() { # $1=texto $2=fila · degradado en diagonal
  local s="$1" fila="${2:-0}"
  local n=${#s}
  local i p
  for ((i=0;i<n;i++)); do
    p=$(( i + fila*3 )); (( p >= n )) && p=$(( n-1 ))
    printf '\e[38;2;%sm%s' "$(mezcla "$p" "$n")" "${s:i:1}"
  done
  printf '%s' "$E_RST"
}

barra() { # $1=pct $2=ancho · verde → ámbar → rojo según la carga
  local pct="$1" w="$2"
  [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
  (( pct > 100 )) && pct=100
  local lle=$(( pct * w / 100 ))
  (( lle==0 && pct>0 )) && lle=1
  local i p r g b
  for ((i=0;i<lle;i++)); do
    p=$(( i * 100 / (w-1) ))
    if (( p < 55 )); then
      r=$(( 63 + (255-63)*p/55 )); g=$(( 224 + (194-224)*p/55 )); b=$(( 168 + (71-168)*p/55 ))
    else
      r=255; g=$(( 194 + (95-194)*(p-55)/45 )); b=$(( 71 + (109-71)*(p-55)/45 ))
    fi
    printf '\e[38;2;%d;%d;%dm█' "$r" "$g" "$b"
  done
  printf '%s%s%s' "$E_OFF" "$(rep '░' $(( w - lle )))" "$E_RST"
}

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

# Tamaños legibles: 1536 -> "1.5K", 4294967296 -> "4.0G"
bytes_hum() { awk -v b="$1" 'BEGIN{
  s="BKMGT"; i=1; while (b>=1024 && i<5) { b/=1024; i++ }
  if (i==1) printf "%d%s", b, substr(s,i,1); else printf "%.1f%s", b, substr(s,i,1) }'; }

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
cpu_pct() {
  # top -bn1 tarda ~1s y la primera muestra es basura. /proc/stat con una
  # ventana de 0.2s es rápido y correcto.
  local i1 t1 i2 t2
  read -r i1 t1 < <(cpu_snap); sleep 0.2; read -r i2 t2 < <(cpu_snap)
  local dt=$(( t2 - t1 )) di=$(( i2 - i1 ))
  (( dt <= 0 )) && { echo 0; return; }
  echo $(( (100 * (dt - di)) / dt ))
}

IP_PUB="";  SSH_PORTS=""
cargar_fijos() {   # lo que no cambia: se consulta una sola vez
  IP_PUB=$(curl -s --max-time 4 ifconfig.me 2>/dev/null)
  [ -z "$IP_PUB" ] && IP_PUB=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$IP_PUB" ] && IP_PUB="sin red"
  # sshd_config puede no declarar Port: el valor por omisión es 22
  SSH_PORTS=$(awk '/^[[:space:]]*Port[[:space:]]+[0-9]+/{print $2}' \
              /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | sort -un | tr '\n' ' ')
  [ -z "${SSH_PORTS// }" ] && SSH_PORTS="22 "
  SO=$(awk -F'"' '/^PRETTY_NAME/{print $2}' /etc/os-release 2>/dev/null)
  [ -z "$SO" ] && SO="Linux"
}

cargar_vivos() {   # lo que cambia en cada refresco
  FECHA=$(date "+%d/%m/%Y %H:%M:%S")
  HORA=$(date "+%H:%M:%S")
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
}

# ============================================================= PANTALLA =====
cabecera() {
  local L=(
    "██╗  ██╗██╗██████╗  █████╗ "
    "██║ ██╔╝██║██╔══██╗██╔══██╗"
    "█████╔╝ ██║██████╔╝███████║"
    "██╔═██╗ ██║██╔══██╗██╔══██║"
    "██║  ██╗██║██║  ██║██║  ██║"
    "╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
  )
  local I=(
    ""
    "$E_BLD$E_TXT$(pad 'ADMINISTRADOR DE VPS · SSH' 43)$E_RST"
    "$E_BLD$E_P1$(pad 'v2.5 PREMIUM' 14)$E_RST$E_MUT$(pad 'LICENCIA' 9)$E_RST$E_OK$(pad '● ACTIVA' 20)$E_RST"
    "$E_MUT$(pad 'EXPIRA' 14)$E_RST$E_TXT$(pad '2026-12-31' 14)$E_RST$E_MUT$(pad 'quedan 77 días' 15)$E_RST"
    "$E_MUT$(pad 'SOPORTE' 14)$E_RST$E_INFO$(pad '@Loki_CC' 29)$E_RST"
    ""
  )
  local i
  for ((i=0;i<6;i++)); do
    printf '  %s   %s┃%s  ' "$(grad_txt "${L[i]}" "$i")" "$E_BOR" "$E_RST"
    if [ -z "${I[i]}" ]; then printf '%*s' 43 ''; else printf '%b' "${I[i]}"; fi
    printf '\n'
  done
}

banda() {
  local t=" IP $IP_PUB    SO $SO    UPTIME $UPTIME    HORA $HORA"
  printf '%s%s%s\n' "$B_BAND" "$(pad "$t" $ANCHO)" "$E_RST"
}

# Ambas cajas miden 37 columnas: bordes en 2, 38, 41 y 77. El contenido
# entre bordes mide SIEMPRE 35. Se arma el cuerpo primero y se imprime con
# un solo %s: si la cantidad de marcadores no coincide con la de argumentos,
# printf repite el formato y mete líneas fantasma.
caja_izq() { printf '  %s│%s%s%s│%s'   "$E_BOR" "$E_RST" "$1" "$E_BOR" "$E_RST"; }
caja_der() { printf '  %s│%s%s%s│%s\n' "$E_BOR" "$E_RST" "$1" "$E_BOR" "$E_RST"; }

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
  printf '  %s╭─%s %s%sSERVICIOS%s %s───────────────────────╮%s  ' \
         "$E_BOR" "$E_RST" "$E_BLD" "$E_P1" "$E_RST" "$E_BOR" "$E_RST"
  printf '%s╭─%s %s%sRECURSOS%s %s────────────────────────╮%s\n' \
         "$E_BOR" "$E_RST" "$E_BLD" "$E_P2" "$E_RST" "$E_BOR" "$E_RST"

  srv "SSH"       "$ST_SSH"  "${SSH_PORTS% }" ; rec "RAM"   "$RAM_PCT" "$(hum "$RAM_USA" "$RAM_TOT")"
  srv "DROPBEAR"  "$ST_DROP" "90 · 143"       ; rec "CPU"   "$CPU_PCT" "${NUCLEOS} vCPU"
  srv "SSL/TLS"   "$ST_SSL"  "443"            ; rec "DISCO" "$DSK_PCT" "${DSK_USA}/${DSK_TOT}"
  srv "SLOWDNS"   "$ST_DNS"  "53"             ; rec "SWAP"  "$SWP_PCT" "$(hum "$SWP_USA" "$SWP_TOT")"
  srv "BADVPN"    "$ST_BAD"  "7300"           ; rec_txt "RED ▼" "$NET_RX_VEL" "total $NET_RX_TOT"
  srv "V2RAY"     "$ST_V2"   "10086"          ; rec_txt "RED ▲" "$NET_TX_VEL" "total $NET_TX_TOT"
  srv "HTTP"      "$ST_HTTP" "80"             ; rec_txt "CONEX" "$CONEX establecidas" ""

  printf '  %s╰%s╯%s  %s╰%s╯%s\n' "$E_BOR" "$(rep '─' 35)" "$E_RST" "$E_BOR" "$(rep '─' 35)" "$E_RST"
}

seccion() { printf '  %s▌%s %s%s%s %s%s%s\n' "$2" "$E_RST" "$E_BLD" "$E_TXT" "$1" \
                   "$E_OFF" "$(rep '─' $(( 73 - ${#1} )))" "$E_RST"; }

# La fila se resalta sólo si coincide con lo que el usuario está tecleando.
# Antes la 01 estaba resaltada fija y parecía un error de pintado.
sel_de() { [ -n "$BUF" ] && { [ "$BUF" = "$1" ] || [ "$BUF" = "${1#0}" ]; } && echo 1 || echo 0; }

opcion() { # $1=nn $2=emoji $3=etiqueta $4=on|off|"" $5=sel
  # 2 + bar1 + sp1 + chip4 + sp1 + emoji2 + sp1 + sep1 + sp1 + etiq30
  #   + guía26 + sp1 + est7 = 78
  local f bar chip est pts
  if [ "$5" = "1" ]; then
    f="$B_SEL"; bar="$E_P1▌$E_RST$f"; chip="$B_CHIP$E_BLD$E_P1"; pts="$E_MUT"
  else
    f=""; bar="$E_OFF▏$E_RST"; chip="$B_CHIP$E_P1"; pts="$E_OFF"
  fi
  # El círculo va SIEMPRE en la misma columna: bullet a la izquierda y la
  # palabra rellenada a 3. Alineando "● ON" y "○ OFF" a la derecha, ON mide 2
  # y OFF mide 3, y los círculos quedan escalonados.
  case "$4" in
    on)  est="$E_BLD$E_OK  ● $(pad 'ON' 3)$E_RST" ;;
    off) est="$E_BLD$E_ERR  ○ $(pad 'OFF' 3)$E_RST" ;;
    *)   est="$(rpad '' 7)" ;;
  esac
  printf '%s  %s %s %s %s %s%s %s%s\n' \
    "$f" "$bar" "$chip $1 $E_RST$f" "$E_P2$2$E_RST$f" "$E_OFF│$E_RST$f" \
    "$E_BLD$E_TXT$(pad "$3" 30)$E_RST$f" "$pts$(rep '·' 26)$E_RST$f" "$est" "$E_RST"
}

menu() {
  seccion "MENÚ PRINCIPAL" "$E_P1"
  echo
  opcion 01 "👥" "CONTROL DE USUARIOS"      "$M_USER"   "$(sel_de 01)"
  opcion 02 "⚡" "OPTIMIZAR VPS"            "$M_OPT"    "$(sel_de 02)"
  opcion 03 "🌐" "USUARIOS ONLINE"          "$M_ONLINE" "$(sel_de 03)"
  opcion 04 "🚀" "AUTO INICIO"              "$M_AUTO"   "$(sel_de 04)"
  opcion 05 "📦" "INSTALADOR DE PROTOCOLOS" "$M_PROTO"  "$(sel_de 05)"
  opcion 06 "📊" "MONITOR EN TIEMPO REAL"   "$M_MON"    "$(sel_de 06)"
  opcion 07 "🔄" "ACTUALIZAR SCRIPT"        "$M_UPD"    "$(sel_de 07)"
  echo
  printf '  %s%s%s\n' "$E_OFF" "$(rep '─' 76)" "$E_RST"
  opcion 00 "🚪" "SALIR"                    ""          "$(sel_de 00)"
}

# Un solo prompt. El decorativo "KIRA@host:~#" sobraba: abajo ya aparecía
# el "Opción:" real del read y se leían dos prompts encima del otro.
prompt() {
  # "  ❯ Opción: " = 12 columnas + lo tecleado + cursor
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( 78 - vis )) ''
  printf '  %s%s%s\n' "$E_MUT" \
    "$(pad 'escribí el número y pulsá ENTER · 0 para salir' 76)" "$E_RST"
}

# El logo y la regla son fijos y cuestan caro: grad_txt y regla lanzan un
# subshell por carácter (≈240 por cuadro). Se arman una sola vez al arrancar.
REGLA_FIJA=""; CABECERA_FIJA=""
cachear_estatico() {
  REGLA_FIJA="$(regla '▀' 76)"
  CABECERA_FIJA="$(cabecera)"
}

pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  paneles
  echo
  menu
  echo
  prompt
}

# Un cuadro = UNA escritura. Antes cada printf llegaba suelto por la red y la
# pantalla se veía temblar mientras se dibujaba. Se arma todo en memoria y se
# vuelca de golpe, con el cursor oculto y marcando el cuadro como atómico
# (\e[?2026h/l) para los clientes que lo soportan.
render() {
  local f; f="$(pintar)"
  printf '\e[?2026h\e[H%s\e[0J\e[?2026l' "$f"
}

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
# El ancho de la terminal importa: a menos de 78 columnas el marco se parte.
cols=$(tput cols 2>/dev/null || echo 80)
if [ "$cols" -lt 78 ] 2>/dev/null; then
  printf '\e[38;2;255;194;71m⚠ Tu terminal tiene %s columnas. KIRA necesita 78.\e[0m\n' "$cols"
  printf '  Agrandá la ventana o reducí la letra, y volvé a entrar.\n'
  read -rsn1 -p "  ENTER para continuar igual…"
fi

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
  clear            # el módulo dejó su propia salida: pantalla limpia al volver
  printf '\e[?25l' # el módulo pudo mostrar el cursor: se vuelve a ocultar
}

cargar_fijos
cachear_estatico
# El cursor real parpadeando mientras se repinta suma al temblor: se oculta
# y se dibuja uno propio en el prompt. El trap lo devuelve pase lo que pase.
trap 'printf "\e[?25h\e[?2026l\e[0m\n"; clear' EXIT INT TERM
printf '\e[?25l'
clear
net_medir           # primera lectura: fija la base para calcular velocidad
BUF=""

# El bucle NO se queda bloqueado en `read`: espera una tecla hasta 0.8s y si
# no llega, repinta con datos frescos. Así la hora y los recursos avanzan
# solos. Se lee tecla por tecla (en vez de `read -t` sobre la línea entera)
# para no perder lo ya tecleado cuando vence el tiempo.
while true; do
  cargar_vivos
  render
  if read -rsn1 -t 0.8 tecla; then
    case "$tecla" in
      "")        ejecutar "$BUF"; BUF="" ;;   # ENTER
      $'\177'|$'\b') BUF="${BUF%?}" ;;        # borrar
      [0-9])     [ ${#BUF} -lt 2 ] && BUF="$BUF$tecla" ;;
      $'\e')     read -rsn2 -t 0.05 _ || true ;;  # descarta flechas
    esac
  fi
done