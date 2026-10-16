#!/bin/bash
# =============================================================================
#  KIRA · lib/ui.sh — paleta y utilería compartida por el menú y los módulos
#  Se incluye con:  source "$DIR/lib/ui.sh"
#  Rejilla fija de 78 columnas · color verdadero de 24 bits
# =============================================================================
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8

ANCHO=78

# ============================================================== PALETA ======
C_P1="45;212;232"    # cian    · primario
C_P2="155;140;255"   # violeta · marca
C_OK="63;224;168"    # menta   · ON / éxito
C_WARN="255;194;71"  # ámbar   · aviso
C_ERR="255;95;109"   # coral   · OFF / error
C_INFO="95;168;255"  # azul    · dato
C_MUT="111;125;156"  # gris    · secundario
C_TXT="220;228;245"  # texto
C_BORDE="40;64;106"
C_BAND="22;35;60"
C_SEL="19;34;65"
C_OFF="28;39;66"
C_CHIP="25;41;70"
G1=(45 212 232); G2=(199 125 238)   # degradado del logo y las reglas

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
# OJO 3: pad y rpad RECORTAN. Si sólo rellenaran, un valor largo empujaría la
# fila más allá de las 78 columnas y rompería el marco.
pad()  { local s="$1" w="$2"; (( ${#s} > w )) && s="${s:0:w}"
         local n=$(( w - ${#s} )); printf '%s%*s' "$s" "$n" ''; }
rpad() { local s="$1" w="$2"; (( ${#s} > w )) && s="${s:0:w}"
         local n=$(( w - ${#s} )); printf '%*s%s' "$n" '' "$s"; }
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

# Medidor segmentado: el RIEL lleva las zonas pintadas (verde hasta 60, ámbar
# hasta 85, rojo arriba), así la escala carga el significado y el relleno no
# tiene que cambiar de color. Se lee la zona sin mirar el número.
medidor() { # $1=pct $2=ancho
  local pct="$1" w="$2"
  [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
  (( pct > 100 )) && pct=100
  local lle=$(( pct * w / 100 ))
  (( lle==0 && pct>0 )) && lle=1
  local i p col
  for ((i=0; i<w; i++)); do
    p=$(( i * 100 / (w-1) ))
    if   (( p < 60 )); then col="$E_OK"
    elif (( p < 85 )); then col="$E_WARN"
    else                    col="$E_ERR"; fi
    if (( i < lle )); then printf '%s▰' "$col"
    else printf '\e[38;2;30;42;66m▱'; fi
  done
  printf '%s' "$E_RST"
}

# Barra de un solo color (para descargas, donde el color no significa carga)
barra_fija() { # $1=pct $2=ancho $3=color
  local pct="$1" w="$2"
  [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
  (( pct > 100 )) && pct=100
  local lle=$(( pct * w / 100 ))
  (( lle==0 && pct>0 )) && lle=1
  printf '%s%s%s%s%s' "$3" "$(rep '█' "$lle")" "$E_OFF" "$(rep '░' $(( w - lle )))" "$E_RST"
}

bytes_hum() { awk -v b="$1" 'BEGIN{
  s="BKMGT"; i=1; while (b>=1024 && i<5) { b/=1024; i++ }
  if (i==1) printf "%d%s", b, substr(s,i,1); else printf "%.1f%s", b, substr(s,i,1) }'; }

# ============================================================== MARCOS ======
# Cajas de 37 columnas: bordes en 2, 38, 41 y 77. El contenido entre bordes
# mide SIEMPRE 35. Se arma el cuerpo primero y se imprime con un solo %s: si
# la cantidad de marcadores no coincide con la de argumentos, printf repite
# el formato y mete líneas fantasma.
# El 2º argumento tiñe el marco. Sin él usa el azul de siempre, así que todo
# lo que ya estaba escrito sigue funcionando igual.
caja_izq() { local c="${2:-$E_BOR}"; printf '  %s│%s%s%s│%s'   "$c" "$E_RST" "$1" "$c" "$E_RST"; }
caja_der() { local c="${2:-$E_BOR}"; printf '  %s│%s%s%s│%s\n' "$c" "$E_RST" "$1" "$c" "$E_RST"; }

# Techo y piso de un par de cajas lado a lado
# Caja de 37 columnas: ╭ + ─ + espacio + título + espacio + rayas + ╮
# 5 fijos + título + rayas = 37  ->  rayas = 32 - largo del título
# El título va en una PASTILLA con fondo, no en texto suelto: destaca mucho
# más y el marco se tiñe del color de la sección. Mismo ancho de antes:
# 5 fijos + título + rayas = 37, así que rayas = 32 - largo del título.
# $5 y $6 tiñen los marcos; sin ellos, azul de siempre.
techo() { # $1=tit izq $2=color izq $3=tit der $4=color der [$5=marco izq $6=marco der]
  local bi="${5:-$E_BOR}" bd="${6:-$E_BOR}"
  printf '  %s╭─%s%s%s %s %s%s%s╮%s  ' "$bi" "$E_RST" "$B_CHIP$E_BLD" "$2" "$1" \
         "$E_RST$bi" "$(rep '─' $(( 32 - ${#1} )))" "$bi" "$E_RST"
  printf '%s╭─%s%s%s %s %s%s%s╮%s\n'   "$bd" "$E_RST" "$B_CHIP$E_BLD" "$4" "$3" \
         "$E_RST$bd" "$(rep '─' $(( 32 - ${#3} )))" "$bd" "$E_RST"
}
piso() { # [$1=marco izq $2=marco der]
  local bi="${1:-$E_BOR}" bd="${2:-$E_BOR}"
  printf '  %s╰%s╯%s  %s╰%s╯%s\n' "$bi" "$(rep '─' 35)" "$E_RST" \
                                   "$bd" "$(rep '─' 35)" "$E_RST"
}

# Banda ancha con fondo: para el estado general, que tiene que saltar a la
# vista antes que cualquier otra cosa de la pantalla.
banner() { # $1=texto $2=color de fondo "R;G;B" $3=color de texto
  printf '\e[48;2;%sm%s%s%s\n' "$2" "$3$E_BLD" "$(pad "  $1" ANCHO)" "$E_RST"
}

# Título de sección a todo lo ancho
seccion() { # $1=titulo $2=color
  printf '  %s▌%s %s%s%s %s%s%s\n' "$2" "$E_RST" "$E_BLD" "$E_TXT" "$1" \
         "$E_OFF" "$(rep '─' $(( 73 - ${#1} )))" "$E_RST"
}

# Encabezado compacto de módulo: ocupa 1 línea en vez de las 7 del logo
encabezado() { # $1=titulo $2=texto derecho
  local d=$(( 72 - ${#1} - ${#2} ))
  (( d < 1 )) && d=1
  printf '  %s▌%s %s%s%s %s%s%s %s%s%s\n' "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$1" \
         "$E_OFF" "$(rep '─' "$d")" "$E_RST" "$E_BLD$E_P2" "$2" "$E_RST"
}

# ============================================================= CABECERA =====
# El logo y la ficha de licencia. Vive acá para que el menú y TODOS los
# módulos muestren exactamente la misma, sin copiarla en cada archivo.
KIRA_LIC="ACTIVA"
KIRA_EXP="2026-12-31"
KIRA_SOP="@Loki_CC"
KIRA_VER=""
REGLA_FIJA=""; CABECERA_FIJA=""

# Los días que faltan se calculan: escritos a mano quedan mal al día siguiente.
dias_restantes() {
  local hoy exp
  hoy=$(date +%s)
  exp=$(date -d "$KIRA_EXP" +%s 2>/dev/null) || { printf '—'; return; }
  local d=$(( (exp - hoy) / 86400 ))
  (( d < 0 )) && { printf 'vencida'; return; }
  printf 'quedan %s días' "$d"
}

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
    "$E_BLD$E_P1$(pad "v$KIRA_VER PREMIUM" 14)$E_RST$E_MUT$(pad 'LICENCIA' 9)$E_RST$E_OK$(pad "● $KIRA_LIC" 20)$E_RST"
    "$E_MUT$(pad 'EXPIRA' 14)$E_RST$E_TXT$(pad "$KIRA_EXP" 14)$E_RST$E_MUT$(pad "$(dias_restantes)" 15)$E_RST"
    "$E_MUT$(pad 'SOPORTE' 14)$E_RST$E_INFO$(pad "$KIRA_SOP" 29)$E_RST"
    ""
  )
  local i
  for ((i=0;i<6;i++)); do
    printf '  %s   %s┃%s  ' "$(grad_txt "${L[i]}" "$i")" "$E_BOR" "$E_RST"
    if [ -z "${I[i]}" ]; then printf '%*s' 43 ''; else printf '%b' "${I[i]}"; fi
    printf '\n'
  done
}

# El logo y la regla cuestan caro: grad_txt y regla lanzan un subshell por
# carácter (≈240 por cuadro). Se arman una sola vez al arrancar.
cachear_cabecera() {
  # La versión se resuelve ACÁ, no dentro de cabecera(): esa corre en $( ),
  # que es un subshell, y cualquier variable que asigne se pierde al volver.
  [ -z "$KIRA_VER" ] && KIRA_VER="$(cat "${KIRA_DIR:-.}/VERSION" 2>/dev/null)"
  [ -z "$KIRA_VER" ] && KIRA_VER="1.0"
  REGLA_FIJA="$(regla '▀' 76)"
  CABECERA_FIJA="$(cabecera)"
}

# ======================================================= BANDA DEL SISTEMA ==
# La usan el menú y los módulos, para que todas las pantallas lleven la misma
# cabecera. La IP se guarda en caché: consultarla cuesta segundos y no cambia.
CACHE_IP="/tmp/kira-ip"
IP_PUB=""; SO=""; HORA=""

datos_sistema() {
  if [ -r "$CACHE_IP" ] && [ -n "$(find "$CACHE_IP" -mmin -60 2>/dev/null)" ]; then
    IP_PUB="$(cat "$CACHE_IP")"
  else
    IP_PUB=$(curl -s --max-time 4 ifconfig.me 2>/dev/null)
    [ -z "$IP_PUB" ] && IP_PUB=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$IP_PUB" ] && IP_PUB="sin red"
    printf '%s' "$IP_PUB" > "$CACHE_IP" 2>/dev/null
  fi
  SO=$(awk -F'"' '/^PRETTY_NAME/{print $2}' /etc/os-release 2>/dev/null)
  [ -z "$SO" ] && SO="Linux"
}

# Tres bloques: IP a la izquierda, SO centrado, HORA a la derecha. Los huecos
# se calculan para que el SO quede centrado y los extremos coincidan con la
# regla de colores (columnas 2 y 78).
banda() {
  HORA=$(date "+%H:%M:%S")
  local izq="  IP $IP_PUB"
  local cen="SO $SO"
  local der="HORA $HORA"
  local sitio=$(( ANCHO - ${#izq} - ${#der} - 4 ))
  (( ${#cen} > sitio )) && cen="${cen:0:sitio}"
  local g1=$(( (ANCHO - ${#cen}) / 2 - ${#izq} ))
  (( g1 < 2 )) && g1=2
  local g2=$(( ANCHO - ${#izq} - g1 - ${#cen} - ${#der} ))
  (( g2 < 2 )) && { g2=2; g1=$(( ANCHO - ${#izq} - ${#cen} - ${#der} - g2 )); }
  printf '%s%s%*s%s%*s%s%s\n' "$B_BAND" "$izq" "$g1" '' "$cen" "$g2" '' "$der" "$E_RST"
}

# ======================================================= CUENTAS DE PRUEBA ==
# Las cuentas de prueba duran MINUTOS, y /etc/shadow sólo sabe de días: su
# campo de vencimiento es un número de día, no tiene hora. Por eso la hora
# exacta se guarda aparte, en db/demos, y el borrado se hace acá.
# Se llama al abrir cualquier módulo de usuarios, así que no hace falta cron
# ni at: se limpian solas apenas entrás al panel. Igual, al crearlas se les
# pone vencimiento de sistema para mañana, como techo: aunque no abras el
# panel en una semana, la cuenta no sobrevive más de un día.
kira_purgar_demos() { # $1 = carpeta del panel
  local f="$1/db/demos" tmp="$1/db/.demos.tmp" lim="$1/db/limites"
  local u t ahora borrados=0
  [ -r "$f" ] || return 0
  printf -v ahora '%(%s)T' -1
  : > "$tmp" 2>/dev/null || return 0
  while read -r u t; do
    [ -z "$u" ] && continue
    [[ "$t" =~ ^[0-9]+$ ]] || continue
    if (( ahora >= t )); then
      userdel "$u" 2>/dev/null
      [ -w "$lim" ] && { grep -v "^$u " "$lim" > "$lim.tmp" 2>/dev/null; mv -f "$lim.tmp" "$lim"; }
      borrados=$(( borrados + 1 ))
    else
      printf '%s %s\n' "$u" "$t" >> "$tmp"
    fi
  done < "$f"
  mv -f "$tmp" "$f" 2>/dev/null
  return 0
}

# ============================================================= PANTALLA =====
# Un cuadro = UNA escritura. Si cada printf sale suelto, por la red la
# pantalla se ve temblar mientras se dibuja. \e[?2026h/l marca el cuadro como
# atómico en los clientes que lo soportan; el resto lo ignora sin romperse.
volcar() { # $1=cuadro ya armado
  printf '\e[?2026h\e[H%s\e[0J\e[?2026l' "$1"
}

cursor_off() { printf '\e[?25l'; }
cursor_on()  { printf '\e[?25h'; }

# Comprueba que la terminal tenga las 78 columnas que el marco necesita
exigir_ancho() {
  local c; c=$(tput cols 2>/dev/null || echo 80)
  if [ "$c" -lt "$ANCHO" ] 2>/dev/null; then
    printf '%s⚠ Tu terminal tiene %s columnas. KIRA necesita %s.%s\n' \
           "$E_WARN" "$c" "$ANCHO" "$E_RST"
    printf '  Agrandá la ventana o reducí la letra.\n'
    read -rsn1 -p "  Una tecla para continuar igual…"
  fi
}