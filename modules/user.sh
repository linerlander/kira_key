#!/bin/bash
# =============================================================================
#  KIRA · módulo 01 · CONTROL DE USUARIOS
#  Uso:  bash modules/user.sh
#        DEMO=1 bash modules/user.sh    (datos inventados, para ver el diseño)
# =============================================================================
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -r "$DIR/lib/ui.sh" ]; then
  printf '\e[1;38;2;255;95;109m✖ Falta el archivo lib/ui.sh\e[0m\n'
  printf '  Tiene que estar en: \e[1m%s/lib/ui.sh\e[0m\n' "$DIR"
  exit 1
fi
KIRA_DIR="$DIR"
source "$DIR/lib/ui.sh"

# lib/ui.sh crece con el tiempo. Si el módulo es nuevo y la librería vieja,
# bash tira "command not found" por cada llamada y la pantalla se inunda.
ui_exige() {
  local f faltan=""
  for f in "$@"; do declare -F "$f" >/dev/null 2>&1 || faltan="$faltan $f"; done
  [ -z "$faltan" ] && return 0
  printf '\e[1;38;2;255;95;109m✖ Tu lib/ui.sh está desactualizado\e[0m\n'
  printf '  Le faltan estas funciones:\e[1m%s\e[0m\n' "$faltan"
  printf '  Actualizalo con:  \e[1mcd %s && git pull\e[0m\n' "$KIRA_DIR"
  exit 1
}
ui_exige techo piso banda cabecera cachear_cabecera datos_sistema pad rpad

MOD="$DIR/modules"
BUF=""; MENSAJE=""; AVISO=""
UMBRAL_VENCE=7      # días para considerar que una cuenta "está por vencer"

# ================================================================ DATOS =====
# Se lee de /etc/shadow, que es la fuente real: campo 2 = contraseña (si
# empieza con ! la cuenta está bloqueada) y campo 8 = día de expiración,
# contado en días desde 1970.
TOTAL=0; ACTIVOS=0; POR_VENCER=0; VENCIDOS=0; BLOQUEADOS=0
EN_LINEA=0; CONEXIONES=0; EXCEDIDOS=0; HAY_LIMITES=0
ULTIMO="—"; TRAFICO="—"; SIN_ROOT=0
declare -A CON_USR      # usuario -> cuántas conexiones tiene abiertas
declare -A ES_CLIENTE   # usuarios vendibles (UID >= 1000)

# Dónde registra el sistema los logins. Cambia según la distro.
LOG_AUTH=""
for _f in /var/log/auth.log /var/log/secure; do
  [ -r "$_f" ] && { LOG_AUTH="$_f"; break; }
done

cargar_cuentas() {
  if [ -n "${DEMO:-}" ]; then
    TOTAL=42; ACTIVOS=38; POR_VENCER=3; VENCIDOS=1; BLOQUEADOS=1
    EN_LINEA=8; CONEXIONES=23; EXCEDIDOS=2; HAY_LIMITES=1
    ULTIMO="juanperez · hace 2m"; TRAFICO="47.9G desde arranque"
    return
  fi

  TOTAL=0; ACTIVOS=0; POR_VENCER=0; VENCIDOS=0; BLOQUEADOS=0
  if [ ! -r /etc/shadow ]; then
    SIN_ROOT=1
  else
    SIN_ROOT=0
    local hoy; hoy=$(( $(date +%s) / 86400 ))
    # Un solo recorrido de passwd + shadow. Antes era un grep y dos cut POR
    # usuario: con 40 cuentas eran ~120 subshells cada vez que refresca.
    # `read < <(...)` corre el read en ESTA shell, así que los valores quedan;
    # con `VAR=$(...)` se perderían al cerrar el subshell.
    #   campo 2 de shadow = clave   · empieza con ! -> bloqueada
    #                               · empieza con * o vacía -> sin clave, no se vende
    #   campo 8 de shadow = día de vencimiento, contado desde 1970
    read -r TOTAL ACTIVOS POR_VENCER VENCIDOS BLOQUEADOS < <(
      awk -F: -v hoy="$hoy" -v lim="$UMBRAL_VENCE" '
        NR==FNR { if ($3>=1000 && $1!="nobody" && $1!="nogroup") usr[$1]=1; next }
        # OJO: la fecha NO puede llamarse exp. exp() es una función de awk y
        # usarla como variable es error de sintaxis, que con 2>/dev/null se
        # traga en silencio y deja todos los contadores en cero.
        ($1 in usr) {
          clave=$2; vto=$8
          if (clave == "" || clave ~ /^\*/) next
          tot++
          if (clave ~ /^!/) { bloq++; next }
          if (vto ~ /^[0-9]+$/) {
            if (vto < hoy)        { venc++; next }
            if (vto - hoy <= lim) { pov++ }
          }
          act++
        }
        END { printf "%d %d %d %d %d", tot+0, act+0, pov+0, venc+0, bloq+0 }
      ' /etc/passwd /etc/shadow 2>/dev/null
    )
    : "${TOTAL:=0}" "${ACTIVOS:=0}" "${POR_VENCER:=0}" "${VENCIDOS:=0}" "${BLOQUEADOS:=0}"
  fi

  # Quiénes son clientes: los de UID >= 1000. Sirve para descartar root y las
  # cuentas de sistema de todo lo que viene después.
  ES_CLIENTE=()
  local u
  while read -r u; do ES_CLIENTE[$u]=1; done < <(
    awk -F: '$3>=1000 && $1!="nobody" && $1!="nogroup" {print $1}' /etc/passwd 2>/dev/null)

  cargar_conexiones
  cargar_ultimo
  TRAFICO="$(trafico_total)"
}

# ========================================================== CONEXIONES ======
# OJO: `who` y `last` NO sirven acá. Los dos leen utmp/wtmp, donde sólo se
# anota la sesión que pide una TERMINAL. El cliente de HTTP Injector (y
# cualquier túnel) se conecta con `ssh -N`: no pide terminal, así que para
# `who` no existe. Hay que contar las conexiones de verdad, una por una.
cargar_conexiones() {
  CON_USR=(); CONEXIONES=0; EN_LINEA=0; EXCEDIDOS=0; HAY_LIMITES=0
  local u pid

  # --- OpenSSH -------------------------------------------------------------
  # sshd forja un proceso hijo por cada conexión y lo renombra
  # "sshd: usuario@pts/0" (con terminal) o "sshd: usuario@notty" (túnel).
  # Se cuentan SÓLO las que llevan @: por cada conexión sshd deja además un
  # "sshd: usuario [priv]" que corre como root, y contarlo sería contar doble.
  # Desde OpenSSH 9.8 el binario de sesión se llama sshd-session, de ahí el
  # (-session)? del patrón.
  while read -r u; do
    [ -n "${ES_CLIENTE[$u]:-}" ] && (( CON_USR[$u]++ ))
  done < <(ps -eo args= 2>/dev/null | awk '
      $1 ~ /^sshd(-session)?:$/ && $2 ~ /@/ { s=$2; sub(/@.*/,"",s); print s }')

  # --- Dropbear ------------------------------------------------------------
  # Dropbear no pone el usuario en la línea del proceso, así que no se puede
  # leer de `ps`. Hay que cruzarlo con el log: cada PID que autenticó bien y
  # todavía está vivo es una conexión abierta. El PID se puede reciclar, por
  # eso se comprueba que el proceso vivo sea realmente dropbear.
  if [ -n "$LOG_AUTH" ] && pgrep -x dropbear >/dev/null 2>&1; then
    local comm
    while read -r pid u; do
      [ -r "/proc/$pid/comm" ] || continue
      read -r comm < "/proc/$pid/comm" 2>/dev/null || continue
      [ "$comm" = "dropbear" ] || continue
      [ -n "${ES_CLIENTE[$u]:-}" ] && (( CON_USR[$u]++ ))
    done < <(tail -n 3000 "$LOG_AUTH" 2>/dev/null | awk '
        /dropbear\[[0-9]+\]: Password auth succeeded for/ {
          p=$5; gsub(/[^0-9]/,"",p)
          u=""; for(i=1;i<=NF;i++) if($i=="for"){u=$(i+1);break}
          gsub(/[^A-Za-z0-9._-]/,"",u)
          if (p!="" && u!="") m[p]=u          # último usuario visto por PID
        }
        END { for (p in m) print p, m[p] }')
  fi

  # --- OpenVPN -------------------------------------------------------------
  # OpenVPN publica sus clientes conectados en el archivo de estado.
  local ovpn
  for ovpn in /etc/openvpn/openvpn-status.log /etc/openvpn/server/openvpn-status.log \
              /var/log/openvpn/status.log /var/log/openvpn-status.log; do
    [ -r "$ovpn" ] || continue
    while read -r u; do
      [ -n "${ES_CLIENTE[$u]:-}" ] && (( CON_USR[$u]++ ))
    done < <(awk -F, '/^CLIENT_LIST/ {print $2}' "$ovpn" 2>/dev/null)
    break
  done

  for u in "${!CON_USR[@]}"; do
    (( CONEXIONES += CON_USR[$u] ))
    (( EN_LINEA++ ))
  done

  # Quién pasa su límite de conexiones simultáneas. El límite por usuario lo
  # guarda el módulo 14; sin ese archivo no hay con qué comparar.
  if [ -r "$DIR/db/limites" ]; then
    HAY_LIMITES=1
    local lu ll
    while read -r lu ll; do
      [ -z "$lu" ] && continue
      [[ "$ll" =~ ^[0-9]+$ ]] || continue
      (( ${CON_USR[$lu]:-0} > ll )) && (( EXCEDIDOS++ ))
    done < "$DIR/db/limites"
  fi
}

# Último cliente que entró. Por lo mismo de arriba `last` no sirve: un túnel
# sin terminal no deja rastro en wtmp. Se lee del log de autenticación, que sí
# anota todos los logins, con o sin terminal.
cargar_ultimo() {
  ULTIMO="—"
  [ -n "$LOG_AUTH" ] || return
  local t u ult_t="" ult_u=""
  while IFS='|' read -r t u; do
    [ -n "${ES_CLIENTE[$u]:-}" ] || continue
    ult_t="$t"; ult_u="$u"          # se recorre hacia adelante: queda el último
  done < <(tail -n 3000 "$LOG_AUTH" 2>/dev/null | awk '
      /sshd(-session)?\[[0-9]+\]: Accepted / ||
      /dropbear\[[0-9]+\]: Password auth succeeded for/ {
        u=""; for (i=1; i<=NF; i++) if ($i == "for") { u=$(i+1); break }
        gsub(/[^A-Za-z0-9._-]/, "", u)
        if (u != "") print $1" "$2" "$3 "|" u
      }')
  [ -z "$ult_u" ] && return
  local e ahora d
  e=$(date -d "$ult_t" +%s 2>/dev/null) || { ULTIMO="$ult_u"; return; }
  ahora=$(date +%s); d=$(( ahora - e ))
  (( d < 0 )) && d=0
  if   (( d < 60 ));    then ULTIMO="$ult_u · recién"
  elif (( d < 3600 ));  then ULTIMO="$ult_u · hace $(( d/60 ))m"
  elif (( d < 86400 )); then ULTIMO="$ult_u · hace $(( d/3600 ))h"
  else                       ULTIMO="$ult_u · hace $(( d/86400 ))d"
  fi
}

# Tráfico que movió la VPS. Los contadores del kernel se ponen en cero cuando
# la máquina reinicia, por eso dice "desde arranque" y no "este mes": decir
# mes sería mentir. El consumo por usuario necesita contabilidad con iptables,
# que es lo que va a armar el módulo 07.
trafico_total() {
  local t=0 n rx tx
  for n in /sys/class/net/*; do
    [ "${n##*/}" = "lo" ] && continue
    [ -r "$n/statistics/rx_bytes" ] || continue
    read -r rx < "$n/statistics/rx_bytes" 2>/dev/null || continue
    read -r tx < "$n/statistics/tx_bytes" 2>/dev/null || continue
    t=$(( t + rx + tx ))
  done
  (( t == 0 )) && { printf '—'; return; }
  printf '%s desde arranque' "$(bytes_hum "$t")"
}

# ============================================================== PANTALLA ====
# El contenido entre bordes mide SIEMPRE 35:
#   izquierda  1 + etiqueta 12 + valor 7 + nota 15 = 35
#   derecha    1 + etiqueta 12 + valor 22          = 35
fila_izq() { caja_izq " $E_MUT$(pad "$1" 12)$E_RST$2$(pad "$3" 7)$E_RST$E_MUT$(pad "${4:-}" 15)$E_RST" "$M_CTA"; }
fila_der() { caja_der " $E_MUT$(pad "$1" 12)$E_RST$2$(pad "$3" 22)$E_RST" "$M_ACT"; }

M_CTA=$'\e[38;2;22;92;110m'      # marco cian apagado
M_ACT=$'\e[38;2;74;64;130m'      # marco violeta apagado

paneles() {
  local c_vence="$E_TXT" c_venc="$E_TXT" c_bloq="$E_TXT"
  (( POR_VENCER > 0 )) && c_vence="$E_BLD$E_WARN"
  (( VENCIDOS   > 0 )) && c_venc="$E_BLD$E_ERR"
  (( BLOQUEADOS > 0 )) && c_bloq="$E_BLD$E_ERR"
  local c_exc="$E_TXT"; (( EXCEDIDOS > 0 )) && c_exc="$E_BLD$E_WARN"

  local c_lin="$E_MUT"; (( EN_LINEA > 0 )) && c_lin="$E_BLD$E_OK"
  local c_con="$E_MUT"; (( CONEXIONES > 0 )) && c_con="$E_BLD$E_TXT"

  techo "CUENTAS" "$E_P1" "ACTIVIDAD" "$E_P2" "$M_CTA" "$M_ACT"
  fila_izq "TOTAL"      "$E_BLD$E_TXT" "$TOTAL"      ""                        ; fila_der "EN LÍNEA"   "$c_lin"  "$EN_LINEA"
  fila_izq "ACTIVOS"    "$E_BLD$E_OK"  "$ACTIVOS"    ""                        ; fila_der "CONEXIONES" "$c_con"  "$CONEXIONES"
  fila_izq "POR VENCER" "$c_vence"     "$POR_VENCER" "en $UMBRAL_VENCE días"   ; fila_der "MULTILOGIN" "$c_exc"  "$(excedidos_txt)"
  fila_izq "VENCIDOS"   "$c_venc"      "$VENCIDOS"   ""                        ; fila_der "ÚLTIMO"     "$E_INFO" "$ULTIMO"
  fila_izq "BLOQUEADOS" "$c_bloq"      "$BLOQUEADOS" ""                        ; fila_der "TRÁFICO"    "$E_TXT"  "$TRAFICO"
  piso "$M_CTA" "$M_ACT"
}
plural() { (( $1 == 1 )) && printf '%s' "$2" || printf '%s' "$3"; }
excedidos_txt() {
  if (( ! HAY_LIMITES )); then printf 'sin límites fijados'
  elif (( EXCEDIDOS > 0 )); then printf '%s %s' "$EXCEDIDOS" "$(plural "$EXCEDIDOS" excedido excedidos)"
  else printf 'sin excesos'; fi
}

# Dos columnas. Cada celda = nn 2 + sp + emoji 2 + sp + texto 31 = 37
# Fila = 2 de margen + 37 + 2 de separación + 37 = 78
OPC=(
  "01|👥|AGREGAR USUARIO"        "08|🔒|BLOQUEAR USUARIO"
  "02|🧹|BORRAR USUARIO(S)"      "09|💾|BACKUP DE USUARIOS"
  "03|🔄|EDITAR / RENOVAR"       "10|🔗|MENÚ SSR / SS"
  "04|📋|USUARIOS REGISTRADOS"   "11|🤖|BOT DE TELEGRAM"
  "05|📡|USUARIOS CONECTADOS"    "12|🔍|VERIFICADOR"
  "06|📢|BANNER SSH"             "13|📄|CHECKUSER"
  "07|📊|LOG DE CONSUMO"         "14|🚦|CONTROL MULTILOGIN"
)
celda() { # $1="nn|emoji|texto"
  local n e t sel
  IFS='|' read -r n e t <<< "$1"
  if [ -n "$BUF" ] && { [ "$BUF" = "$n" ] || [ "$BUF" = "${n#0}" ]; }; then
    printf '%s%s%s %s%s%s %s%s%s' "$B_SEL$E_BLD$E_P1" "$n" "$E_RST$B_SEL" \
           "$E_P2" "$e" "$E_RST$B_SEL" "$E_BLD$E_TXT" "$(pad "$t" 31)" "$E_RST"
  else
    printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$n" "$E_RST" \
           "$E_P2" "$e" "$E_RST" "$E_TXT" "$(pad "$t" 31)" "$E_RST"
  fi
}
opciones() {
  local i
  for ((i=0; i<${#OPC[@]}; i+=2)); do
    printf '  %s  %s\n' "$(celda "${OPC[i]}")" "$(celda "${OPC[i+1]}")"
  done
}

pie() {
  printf '  %s%s%s  %s%s%s  %s%s%s\n' \
    "$E_BLD$E_ERR" "00" "$E_RST" "$E_P2" "🚪" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad 'VOLVER AL MENÚ PRINCIPAL' 68)" "$E_RST"
  local vis=$(( 12 + ${#BUF} + 1 ))
  printf '  %s%s❯%s %s%sOpción:%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$E_RST" \
    "$E_BLD" "$E_P1" "$BUF" "$C_P1" $(( ANCHO - vis )) ''
}

# Renglón reservado para avisos. Queda en blanco cuando no hay nada que decir
# — no se borra la línea, porque si apareciera y desapareciera el bloque de
# abajo saltaría una fila y la pantalla se vería brincar.
linea_aviso() {
  if [ -n "$AVISO" ]; then
    printf '  %s%s%s\n' "$E_BLD$E_ERR" "$(pad "✖ $AVISO" 76)" "$E_RST"
  elif (( SIN_ROOT )); then
    printf '  %s%s%s\n' "$E_BLD$E_WARN" "$(pad "▸ Entrá como root para ver el estado real de las cuentas" 76)" "$E_RST"
  else
    printf '  %s\n' "$(pad '' 76)"
  fi
}

pintar() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "CONTROL DE USUARIOS" "KIRA v$KIRA_VER"
  echo
  paneles
  echo
  seccion "OPERACIONES" "$E_P2"
  echo
  opciones
  echo
  linea_aviso
  echo
  pie
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# =============================================================== ACCIONES ===
abrir() { # $1=archivo $2=nombre
  if [ -f "$MOD/$1" ]; then
    cursor_on; clear
    bash "$MOD/$1"
    clear; cursor_off
    cargar_cuentas
    AVISO=""
  else
    AVISO="$2 no está instalado · falta modules/$1"
  fi
}

ejecutar() {
  AVISO=""          # cada elección arranca limpia: el aviso anterior ya no aplica
  case "$1" in
    1|01)  abrir user_add.sh     "Agregar usuario" ;;
    2|02)  abrir user_clear.sh   "Borrar usuarios" ;;
    3|03)  abrir user_edit.sh    "Editar / renovar" ;;
    4|04)  abrir user_list.sh    "Usuarios registrados" ;;
    5|05)  abrir user_online.sh  "Usuarios conectados" ;;
    6|06)  abrir ssh_banner.sh   "Banner SSH" ;;
    7|07)  abrir user_log.sh     "Log de consumo" ;;
    8|08)  abrir user_lock.sh    "Bloquear usuario" ;;
    9|09)  abrir user_backup.sh  "Backup de usuarios" ;;
    10)    abrir ssr.sh          "Menú SSR / SS" ;;
    11)    abrir bot_telegram.sh "Bot de Telegram" ;;
    12)    abrir user_check.sh   "Verificador" ;;
    13)    abrir checkuser.sh    "Checkuser" ;;
    14)    abrir user_libre.sh   "Control multilogin" ;;
    0|00)  clear; exit 0 ;;
    "")    return ;;
    *)     AVISO="Opción $1 inválida" ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    [0-9])         [ ${#BUF} -lt 2 ] && BUF="$BUF$1" ;;
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

cargar_cuentas
SEG_ANT=-1

while true; do
  # Las cuentas se releen cada 5s: cambian poco y leer /etc/shadow entero
  # en cada vuelta es gasto al pedo.
  printf -v ahora '%(%s)T' -1
  if (( ahora - SEG_ANT >= 5 )); then cargar_cuentas; SEG_ANT=$ahora; fi
  render
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done