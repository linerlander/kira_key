#!/bin/bash
# =============================================================================
#  KIRA · módulo 06 · MONITOR EN TIEMPO REAL
#  Uso:  bash monitor.sh
#        DEMO=1 bash monitor.sh    (datos inventados, para ver el diseño)
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
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
ui_exige medidor techo piso banda cabecera cachear_cabecera datos_sistema pad rpad


BUF=""; PAUSA=0
# Marcos teñidos: cada sección lleva su color, apagado para que no compita
# con el contenido. Es lo que hace que la pantalla se lea por bloques.
M_CPU=$'\e[38;2;22;92;110m'; M_MEM=$'\e[38;2;74;64;130m'
M_RED=$'\e[38;2;110;46;84m'; M_DSK=$'\e[38;2;96;76;28m'
E_PINK=$'\e[38;2;255;111;181m'

# Se detecta la interfaz aunque no se muestre: la usa el cálculo de tráfico.
IFACE=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
[ -z "$IFACE" ] && IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -v '^lo$' | head -n1)
[ -z "$IFACE" ] && IFACE="red" 

# ================================================================= PICOS ====
# Ventana deslizante de 60 lecturas (≈1 minuto). Antes se reiniciaba a cero
# cada minuto, así que justo después del corte el pico valía lo mismo que el
# valor actual y parecía que no se movía.
VENT_CPU=""; VENT_RAM=""; PICO_CPU=0; PICO_RAM=0
ventana() { # $1=lista $2=valor nuevo -> lista recortada a 60
  local -a v=($1 $2)
  local n=${#v[@]}
  (( n > 60 )) && printf '%s' "${v[*]:n-60:60}" || printf '%s' "${v[*]}"
}
maximo() { awk '{ m=0; for(i=1;i<=NF;i++) if($i>m) m=$i; print m+0 }' <<< "$1"; }

anotar_pico() {
  VENT_CPU="$(ventana "$VENT_CPU" "$CPU_PCT")"
  VENT_RAM="$(ventana "$VENT_RAM" "$RAM_PCT")"
  PICO_CPU="$(maximo "$VENT_CPU")"
  PICO_RAM="$(maximo "$VENT_RAM")"
}

# ================================================================ DATOS =====
# CPU por diferencia entre dos lecturas de /proc/stat, guardando la anterior
# entre vueltas. top -bn1 tarda ~1s y su primera muestra es basura.
declare -A CPU_I CPU_T
# OJO: deja el resultado en CPU_RES en vez de imprimirlo. Si se llamara con
# $( ), correría en un SUBSHELL y las muestras guardadas en CPU_I/CPU_T se
# perderían al volver: cada lectura se compararía contra el arranque del
# sistema y el porcentaje saldría casi fijo (el promedio desde el booteo).
CPU_RES=0
cpu_de() { # $1=cpu|cpu0|cpu1...  -> resultado en CPU_RES
  local k="$1" i2 t2
  read -r i2 t2 < <(awk -v k="$k" '$1==k{idle=$5; tot=0; for(i=2;i<=NF;i++) tot+=$i; print idle, tot; exit}' /proc/stat)
  [ -z "$t2" ] && { CPU_RES=0; return; }
  local dt=$(( t2 - ${CPU_T[$k]:-0} )) di=$(( i2 - ${CPU_I[$k]:-0} ))
  CPU_I[$k]=$i2; CPU_T[$k]=$t2
  if (( dt <= 0 )); then CPU_RES=0; else CPU_RES=$(( (100 * (dt - di)) / dt )); fi
}

NET_RX_ANT=0; NET_TX_ANT=0; NET_T_ANT=0
NET_RX_VEL=0; NET_TX_VEL=0; NET_RX_TOT=0; NET_TX_TOT=0
net_medir() {
  local rx tx up
  read -r rx tx < <(awk '/:/{split($0,a,":"); f=a[1]; gsub(/ /,"",f);
      if (f=="lo") next; n=split(a[2],b," "); rx+=b[1]; tx+=b[9] }
      END{print rx+0, tx+0}' /proc/net/dev 2>/dev/null)
  read -r up _ < /proc/uptime
  NET_RX_TOT="$rx"; NET_TX_TOT="$tx"
  local dt; dt=$(awk -v a="$up" -v b="$NET_T_ANT" 'BEGIN{printf "%.2f", a-b}')
  if [ "$NET_T_ANT" != "0" ] && awk -v d="$dt" 'BEGIN{exit !(d>0.1)}'; then
    NET_RX_VEL=$(awk -v a="$rx" -v b="$NET_RX_ANT" -v d="$dt" 'BEGIN{printf "%d", (a-b)/d}')
    NET_TX_VEL=$(awk -v a="$tx" -v b="$NET_TX_ANT" -v d="$dt" 'BEGIN{printf "%d", (a-b)/d}')
  fi
  NET_RX_ANT="$rx"; NET_TX_ANT="$tx"; NET_T_ANT="$up"
}

procnet() { local f o=(); for f in "$@"; do [ -r "$f" ] && o+=("$f"); done; printf '%s\n' "${o[@]}"; }
conexiones() {
  if command -v ss >/dev/null 2>&1; then
    ss -tn state established 2>/dev/null | tail -n +2 | wc -l
  else
    local f; mapfile -t f < <(procnet /proc/net/tcp /proc/net/tcp6)
    [ ${#f[@]} -eq 0 ] && { echo 0; return; }
    awk 'FNR>1 && $4=="01"{n++} END{print n+0}' "${f[@]}" 2>/dev/null
  fi
}

NUCLEOS=1; CORES=()
PROCS=()
medir() {
  if [ -n "${DEMO:-}" ]; then
    CPU_PCT=$(( RANDOM % 70 + 10 )); RAM_PCT=$(( RANDOM % 30 + 20 ))
    CORES=($(( RANDOM % 80 )) $(( RANDOM % 80 )))
    NUCLEOS=2; RAM_USA=1843; RAM_TOT=8029; SWP_USA=0; SWP_TOT=1024; SWP_PCT=0
    DSK_PCT=31; DSK_USA="14G"; DSK_TOT="40G"; DSK_DEC="31.4"; DSK_LIBRE="26G"
    RAM_DEC=$(awk -v r="$RAM_PCT" 'BEGIN{printf "%.1f", r+0.3}')
    NET_RX_VEL=$(( RANDOM % 2000000 )); NET_TX_VEL=$(( RANDOM % 400000 ))
    NET_RX_TOT=4500000000; NET_TX_TOT=880000000
    CARGA="0.42 0.38 0.30"; NPROC=132; SESIONES=3; CONEX=17; ACTIVO="14d 06h"
    PROCS=("1234|root|sshd|12.3|1.2" "2201|nobody|v2ray|8.1|3.4" "994|root|dropbear|4.2|0.8"
           "5120|kira|python3|2.0|2.1" "77|root|systemd|0.7|0.4")
  else
    cpu_de cpu; CPU_PCT=$CPU_RES
    NUCLEOS=$(nproc 2>/dev/null || echo 1)
    CORES=()
    local c; for ((c=0; c<NUCLEOS && c<8; c++)); do cpu_de "cpu$c"; CORES+=("$CPU_RES"); done
    read -r RAM_USA RAM_TOT < <(free -m 2>/dev/null | awk '/^Mem:/{print $3, $2}')
    : "${RAM_USA:=0}"; : "${RAM_TOT:=1}"
    RAM_PCT=$(( RAM_USA * 100 / (RAM_TOT>0?RAM_TOT:1) ))
    # Con un entero la RAM se ve congelada: pasa de 506MB a 491MB y el
    # porcentaje sigue marcando 6%. Un decimal ya muestra el movimiento.
    RAM_DEC=$(awk -v u="$RAM_USA" -v t="$RAM_TOT" 'BEGIN{printf "%.1f", (t>0? u*100/t : 0)}')
    read -r SWP_USA SWP_TOT < <(free -m 2>/dev/null | awk '/^Swap:/{print $3, $2}')
    : "${SWP_USA:=0}"; : "${SWP_TOT:=0}"
    SWP_PCT=$(( SWP_TOT>0 ? SWP_USA*100/SWP_TOT : 0 ))
    read -r DSK_USA DSK_TOT DSK_PCT < <(df -h --output=used,size,pcent / 2>/dev/null | awk 'NR==2{gsub("%","",$3); print $1, $2, $3}')
    : "${DSK_USA:=0}"; : "${DSK_TOT:=0}"; : "${DSK_PCT:=0}"
    # df redondea a entero: con un decimal se nota cuando se escriben archivos
    read -r DSK_UK DSK_TK < <(df -k --output=used,size / 2>/dev/null | awk 'NR==2{print $1, $2}')
    DSK_DEC=$(awk -v u="${DSK_UK:-0}" -v t="${DSK_TK:-1}" 'BEGIN{printf "%.1f", (t>0? u*100/t : 0)}')
    DSK_LIBRE=$(df -h --output=avail / 2>/dev/null | awk 'NR==2{print $1}')
    net_medir
    CARGA=$(awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg 2>/dev/null)
    NPROC=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
    SESIONES=$(who 2>/dev/null | wc -l)
    CONEX=$(conexiones)
    ACTIVO=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); printf "%dd %02dh", d, h}' /proc/uptime 2>/dev/null)
    mapfile -t PROCS < <(ps -eo pid=,user=,comm=,pcpu=,pmem= --sort=-pcpu 2>/dev/null |
                         head -5 | awk '{printf "%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5}')
  fi
  anotar_pico
}

# ============================================================== PANTALLA ====
MARCO_I="$E_BOR"; MARCO_D="$E_BOR"
f_izq() { caja_izq " $E_MUT$(pad "$1" 9)$E_RST$2" "$MARCO_I"; }
f_der() { caja_der " $E_MUT$(pad "$1" 9)$E_RST$2" "$MARCO_D"; }

# Contenido de 35 columnas: 1 + etiqueta 9 + cuerpo 25
cuerpo_barra() { # $1=pct(entero, para el medidor) $2=texto a mostrar
  local t="${2:-$1%}"
  printf '%s %s%s%s' "$(medidor "$1" 12)" "$E_BLD$E_TXT" "$(rpad "$t" 7)" "$E_RST$E_MUT$(pad '' 5)$E_RST"
}
cuerpo_txt() { printf '%s%s%s' "$E_TXT" "$(pad "$1" 25)" "$E_RST"; }

paneles_arriba() {
  MARCO_I="$M_CPU"; MARCO_D="$M_MEM"
  techo "PROCESADOR" "$E_P1" "MEMORIA" "$E_P2" "$M_CPU" "$M_MEM"
  f_izq "USO"     "$(cuerpo_barra "$CPU_PCT" "")"            ; f_der "RAM"   "$(cuerpo_barra "$RAM_PCT" "$RAM_DEC%")"
  f_izq "PICO 1m" "$(cuerpo_barra "$PICO_CPU" "")"            ; f_der "PICO 1m" "$(cuerpo_barra "$PICO_RAM" "")"
  f_izq "NÚCLEOS" "$(cuerpo_txt "$(nucleos_txt)")"            ; f_der "USADA" "$(cuerpo_txt "${RAM_USA}M de $(hum_mb "$RAM_TOT")")"
  f_izq "CARGA"   "$(cuerpo_txt "$CARGA")"                    ; f_der "SWAP"  "$(cuerpo_barra "$SWP_PCT" "")"
  f_izq "TAREAS"  "$(cuerpo_txt "$NPROC procesos")"           ; f_der "LIBRE" "$(cuerpo_txt "$(hum_mb $(( RAM_TOT - RAM_USA )))")"
  piso "$M_CPU" "$M_MEM"
}

nucleos_txt() {
  local s="" i
  for i in "${!CORES[@]}"; do s="$s$((i+1)):${CORES[i]}% "; done
  [ -z "$s" ] && s="$NUCLEOS núcleo(s)"
  printf '%s' "$s"
}
hum_mb() { awk -v m="$1" 'BEGIN{ if (m>=1024) printf "%.1fG", m/1024; else printf "%dM", m }'; }

paneles_abajo() {
  MARCO_I="$M_RED"; MARCO_D="$M_DSK"
  techo "RED VPS" "$E_PINK" "DISCO Y SISTEMA" "$E_WARN" "$M_RED" "$M_DSK"
  f_izq "BAJADA"  "$(cuerpo_txt "$(bytes_hum "$NET_RX_VEL")/s")" ; f_der "USO"     "$(cuerpo_barra "$DSK_PCT" "$DSK_DEC%")"
  f_izq "SUBIDA"  "$(cuerpo_txt "$(bytes_hum "$NET_TX_VEL")/s")" ; f_der "ESPACIO" "$(cuerpo_txt "$DSK_USA de $DSK_TOT · libre ${DSK_LIBRE:-?}")"
  f_izq "TOTAL ▼" "$(cuerpo_txt "$(bytes_hum "$NET_RX_TOT")")" ; f_der "SESIONES" "$(cuerpo_txt "$SESIONES abiertas")"
  f_izq "TOTAL ▲" "$(cuerpo_txt "$(bytes_hum "$NET_TX_TOT")")" ; f_der "ACTIVO"   "$(cuerpo_txt "$ACTIVO")"
  f_izq "CONEX"  "$(cuerpo_txt "$CONEX establecidas")"         ; f_der "ESTADO"   "$(cuerpo_txt "$(estado_txt)")"
  piso "$M_RED" "$M_DSK"
}

estado_txt() {
  if   (( CPU_PCT >= 90 || RAM_PCT >= 90 )); then printf 'crítico'
  elif (( CPU_PCT >= 70 || RAM_PCT >= 70 )); then printf 'exigido'
  else printf 'normal'; fi
}

# Tabla: 2 + pid 7 + 1 + usuario 12 + 1 + proceso 41 + 1 + cpu 6 + 1 + ram 6 = 78
tabla_procesos() {
  printf '  %s%s%s%s%s%s%s\n' "$E_BLD$E_MUT" "$(pad 'PID' 8)" "$(pad 'USUARIO' 13)" \
         "$(pad 'PROCESO' 42)" "$(rpad 'CPU' 6)" " $(rpad 'RAM' 6)" "$E_RST"
  local l i=0
  for l in "${PROCS[@]}"; do
    IFS='|' read -r pid usr com cpu mem <<< "$l"
    printf '  %s%s%s%s%s%s%s%s%s%s%s\n' \
      "$E_MUT" "$(pad "$pid" 8)" "$E_RST" \
      "$E_INFO" "$(pad "$usr" 13)" "$E_RST" \
      "$E_TXT$E_BLD" "$(pad "$com" 42)" "$E_RST" \
      "$E_BLD$E_OK$(rpad "$cpu%" 6)$E_RST" "$E_BLD$E_P2 $(rpad "$mem%" 6)$E_RST"
    i=$((i+1))
  done
  for ((; i<5; i++)); do printf '  %s\n' "$(pad '' 76)"; done
}

# El pie arranca en la columna 2, igual que la tabla de procesos de arriba.
# Con la barra ▏ y la pastilla quedaba metido hacia adentro y se veía corrido.
# 2 + nn2 + 2 + emoji2 + 2 + texto 56 + estado 12 = 78
pie() {
  local etxt col
  if [ "$PAUSA" = 1 ]; then etxt="⏸ PAUSADO"; col="$E_WARN"; else etxt="▶ EN VIVO"; col="$E_OK"; fi
  printf '  %s%s%s  %s%s%s  %s%s%s%s%s%s\n' \
    "$E_BLD$E_P1" "00" "$E_RST" \
    "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad 'VOLVER AL MENÚ' 56)" "$E_RST" \
    "$E_BLD$col" "$(rpad "$etxt" 12)" "$E_RST"
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "MONITOR EN TIEMPO REAL" "KIRA v$KIRA_VER"
  echo
  paneles_arriba
  echo
  paneles_abajo
  echo
  seccion "PROCESOS QUE MÁS CONSUMEN" "$E_P2"
  echo
  tabla_procesos
  echo
  pie
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# ================================================================= MAIN =====
exigir_ancho
datos_sistema
cachear_cabecera
# El manejador de INT/TERM DEBE salir. Si sólo limpia, Ctrl+C ejecuta el trap
# y el bucle sigue corriendo: no hay forma de cortar el script.
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear' EXIT
trap 'cursor_on; printf "\e[?2026l\e[0m\n"; clear; exit 130' INT TERM
cursor_off
clear

medir            # primera lectura: fija la base de CPU y red
sleep 0.3
SEG_ANT=-1

while true; do
  printf -v ahora '%(%s)T' -1
  if [ "$PAUSA" = 0 ] && [ "$ahora" != "$SEG_ANT" ]; then medir; SEG_ANT="$ahora"; fi
  render
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    case "$tecla" in
      "")            case "$BUF" in 0|00) clear; exit 0 ;; esac; BUF="" ;;
      $'\177'|$'\b') BUF="${BUF%?}" ;;
      [0-9])         [ ${#BUF} -lt 2 ] && BUF="$BUF$tecla" ;;
      p|P)           PAUSA=$(( 1 - PAUSA )) ;;
      $'\e')         read -rsn2 -t 0.05 _ || true ;;
    esac
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done