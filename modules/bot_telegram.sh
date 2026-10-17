#!/bin/bash
# =============================================================================
#  KIRA · módulo 01.11 · BOT DE TELEGRAM
#  Acá sólo se configura y se prende o apaga. El bot en sí es kira-bot.py, en
#  la raíz del panel, y lo corre systemd como servicio kira-bot: sigue andando
#  aunque cierres la terminal o reinicie el VPS.
#  Uso:  bash modules/bot_telegram.sh
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
  printf '\e[1;38;2;255;95;109m✖ Hay que ser root para manejar el bot\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '\e[1;38;2;255;95;109m✖ El bot necesita python3\e[0m\n'
  printf '  Instalalo con:  \e[1mapt-get install -y python3\e[0m\n'
  read -rsn1 -p "  Pulsá una tecla para volver…"
  exit 1
fi

# ================================================================ ESTADO ====
CONF="$DIR/db/bot.json"
LOGBOT="$DIR/db/bot.log"
BOT_PY="$DIR/kira-bot.py"
UNIDAD="/etc/systemd/system/kira-bot.service"

PANTALLA=inicio           # inicio · token · admins
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0; CARGA_ANT=0
EST="sin configurar"      # en línea · apagado · sin configurar · con error
CF_TOKEN=""; CF_ADMINS=""; CF_NREV=0; CF_BOTUSR=""; CF_CRED=0
declare -a ULTIMOS=()

M_TABLA=$'\e[38;2;110;46;84m'
E_PINK=$'\e[38;2;255;111;181m'

# ================================================================ DATOS =====
# La configuración es JSON porque la comparte con el bot. Bash no lee JSON,
# así que se le pide a python3, que igual tiene que estar para el bot.
conf_leer() {
  local salida
  salida="$(python3 - "$CONF" <<'PY' 2>/dev/null
import json, shlex, sys
try:
    c = json.load(open(sys.argv[1]))
except Exception:
    c = {}
rv = c.get("revendedores", {})
print("CF_TOKEN=%s" % shlex.quote(str(c.get("token", ""))))
print("CF_ADMINS=%s" % shlex.quote(" ".join(str(x) for x in c.get("admins", []))))
print("CF_NREV=%d" % len(rv))
print("CF_CRED=%d" % sum(int(r.get("creditos", 0)) for r in rv.values()))
print("CF_BOTUSR=%s" % shlex.quote(str(c.get("bot_usuario", ""))))
print("CF_LOCAL=%s" % shlex.quote(str(c.get("nombre_local") or "Principal")))
sv = c.get("servidores", {})
filas = ["%s|%s|%s|%s|%s" % (k, v.get("nombre", k), v.get("host", ""), v.get("puerto", 22),
                             v.get("dir", "/root/kira_key")) for k, v in sorted(sv.items())]
print("CF_SRV=(%s)" % " ".join(shlex.quote(f) for f in filas))
PY
)"
  CF_TOKEN=""; CF_ADMINS=""; CF_NREV=0; CF_CRED=0; CF_BOTUSR=""; CF_LOCAL="Principal"; CF_SRV=()
  eval "$salida"
}

# $1=acción (token · admin)  $2=valor
conf_cambiar() {
  mkdir -p "$DIR/db"
  python3 - "$CONF" "$1" "$2" <<'PY'
import json, os, sys
ruta, accion, valor = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    c = json.load(open(ruta))
except Exception:
    c = {}
c.setdefault("admins", [])
c.setdefault("revendedores", {})
if accion == "token":
    c["token"] = valor
    c.pop("bot_usuario", None)
elif accion == "nombre_local":
    c["nombre_local"] = valor
elif accion == "srv_agregar":
    s = json.loads(valor)
    c.setdefault("servidores", {})
    # Si ya estaba ese mismo VPS, se actualiza en vez de duplicarlo
    sid = next((k for k, v in c["servidores"].items() if v.get("host") == s["host"]), None)
    if sid is None:
        n = 1
        while f"s{n}" in c["servidores"]:
            n += 1
        sid = f"s{n}"
    c["servidores"][sid] = s
    print(sid)
elif accion == "srv_quitar":
    c.setdefault("servidores", {}).pop(valor, None)
elif accion == "admin":
    n = int(valor)
    if n in c["admins"]:
        c["admins"].remove(n)
        print("quitado")
    else:
        c["admins"].append(n)
        c["revendedores"].pop(str(n), None)   # un admin no paga créditos
        print("agregado")
tmp = ruta + ".tmp"
with open(tmp, "w") as f:
    json.dump(c, f, indent=2, ensure_ascii=False)
os.chmod(tmp, 0o600)
os.replace(tmp, ruta)
PY
}

estado_bot() {
  if [ -z "$CF_TOKEN" ] || [ -z "$CF_ADMINS" ]; then EST="sin configurar"
  elif systemctl is-active --quiet kira-bot 2>/dev/null; then EST="en línea"
  elif systemctl is-failed --quiet kira-bot 2>/dev/null; then EST="con error"
  else EST="apagado"; fi
}

cargar() {
  conf_leer
  estado_bot
  ULTIMOS=()
  [ -r "$LOGBOT" ] && mapfile -t ULTIMOS < <(tail -n 6 "$LOGBOT" 2>/dev/null)
}

token_corto() {
  [ -z "$CF_TOKEN" ] && { printf 'sin cargar'; return; }
  printf '%s…%s' "${CF_TOKEN:0:6}" "${CF_TOKEN: -4}"
}

# ============================================================== ACCIONES ====
instalar_servicio() {
  cat > "$UNIDAD" <<EOF
[Unit]
Description=KIRA - bot de Telegram
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=KIRA_DIR=$DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/env python3 $BOT_PY
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}

# El bot viejo de bash corría suelto con nohup. Si queda vivo con el mismo
# token, Telegram reparte los mensajes entre los dos al azar.
matar_bot_viejo() {
  local pid
  if [ -r /etc/kira/bot/bot.pid ]; then
    read -r pid < /etc/kira/bot/bot.pid
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    rm -f /etc/kira/bot/bot.pid
  fi
  pkill -f /etc/kira/bot/telegram_bot.sh 2>/dev/null
}

encender() {
  [ -f "$BOT_PY" ] || { AVISO="Falta kira-bot.py en la carpeta del panel · actualizá con la opción 07"; return 1; }
  [ -n "$CF_TOKEN" ]  || { AVISO="Primero cargá el token con la opción 01"; return 1; }
  [ -n "$CF_ADMINS" ] || { AVISO="Primero agregá tu ID de Telegram con la opción 02"; return 1; }
  matar_bot_viejo
  instalar_servicio
  systemctl enable kira-bot >/dev/null 2>&1
  systemctl restart kira-bot >/dev/null 2>&1
  sleep 3
  if systemctl is-active --quiet kira-bot; then return 0; fi
  AVISO="No arrancó: $(journalctl -u kira-bot -n 1 -o cat --no-pager 2>/dev/null | tail -1)"
  return 1
}

apagar() {
  systemctl disable --now kira-bot >/dev/null 2>&1
  return 0
}

reiniciar_si_anda() {
  systemctl is-active --quiet kira-bot 2>/dev/null && systemctl restart kira-bot >/dev/null 2>&1
}

# Se le pregunta a Telegram si el token sirve ANTES de guardarlo: un token mal
# copiado deja al bot reiniciándose en silencio cada diez segundos.
probar_token() { # $1=token -> deja el @usuario en BOT_NUEVO
  BOT_NUEVO=""
  local r
  r="$(curl -s --max-time 10 "https://api.telegram.org/bot$1/getMe" 2>/dev/null)"
  case "$r" in
    *'"ok":true'*)
      BOT_NUEVO="$(printf '%s' "$r" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"].get("username",""))' 2>/dev/null)"
      return 0 ;;
  esac
  return 1
}

mensaje_prueba() {
  local a ok=0 txt
  txt="✅ <b>KIRA</b> te escucha.%0AMandá /start para abrir el panel."
  for a in $CF_ADMINS; do
    curl -s --max-time 10 "https://api.telegram.org/bot$CF_TOKEN/sendMessage" \
      -d "chat_id=$a" -d "parse_mode=HTML" -d "text=$txt" 2>/dev/null | grep -q '"ok":true' && ok=$(( ok + 1 ))
  done
  if (( ok > 0 )); then MENSAJE="Mensaje enviado a $ok administrador(es) · mirá tu Telegram"
  else AVISO="No llegó · ¿le mandaste /start al bot al menos una vez desde ese Telegram?"; fi
}

# ============================================================ SERVIDORES ====
# El bot de ESTE VPS maneja los demás por SSH, con una llave propia. Para
# sumar uno hay que dejar esa llave autorizada allá: se hace una sola vez,
# escribiendo la clave root del otro VPS acá mismo, en la terminal.
LLAVE="/root/.ssh/kira_ed25519"
declare -A SRV_EST=()      # id -> ok · sin kira · sin respuesta
ALTA_IP=""; ALTA_PTO=""; ALTA_NOM=""
SRV_QUITAR=""

asegurar_llave() {
  [ -f "$LLAVE" ] && return 0
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  ssh-keygen -q -t ed25519 -N "" -C "kira-bot@$(hostname)" -f "$LLAVE" >/dev/null 2>&1
}

ssh_kira() { # $1=host $2=puerto $3..=orden
  local h="$1" p="$2"; shift 2
  ssh -i "$LLAVE" -p "$p" -o BatchMode=yes -o ConnectTimeout=6 \
      -o StrictHostKeyChecking=accept-new "root@$h" "$@" 2>/dev/null
}

# Dónde está KIRA en el otro VPS. Devuelve la carpeta, o nada.
buscar_kira_remoto() { # $1=host $2=puerto
  ssh_kira "$1" "$2" 'for d in /root/kira_key /home/*/kira_key; do [ -f "$d/kira-bot.py" ] && { echo "$d"; break; }; done'
}

probar_servidores() {
  local f id nom host pto dir r
  SRV_EST=()
  for f in "${CF_SRV[@]}"; do
    IFS='|' read -r id nom host pto dir <<< "$f"
    if ! ssh_kira "$host" "$pto" true; then SRV_EST[$id]="sin respuesta"; continue; fi
    r="$(ssh_kira "$host" "$pto" "[ -f '$dir/kira-bot.py' ] && echo si")"
    if [ "$r" = si ]; then SRV_EST[$id]="ok"; else SRV_EST[$id]="sin kira"; fi
  done
}

# Sale del dibujo y deja la terminal normal: ssh-copy-id pide la clave del
# otro VPS y hay que verla escribir.
alta_servidor() {
  local dir sid
  asegurar_llave || { AVISO="No pude crear la llave SSH en $LLAVE"; return 1; }
  cursor_on; printf '\e[0m'; clear
  printf '\n  \e[1m🔑 Autorizar a este bot en %s\e[0m\n\n' "$ALTA_IP"
  printf '  Te va a pedir la \e[1mclave de root del otro VPS\e[0m. Es una sola vez:\n'
  printf '  después el bot entra con su llave y no necesita ninguna clave.\n\n'
  if command -v ssh-copy-id >/dev/null 2>&1; then
    ssh-copy-id -i "$LLAVE.pub" -p "$ALTA_PTO" -o StrictHostKeyChecking=accept-new "root@$ALTA_IP"
  else
    ssh -p "$ALTA_PTO" -o StrictHostKeyChecking=accept-new "root@$ALTA_IP" \
      'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' \
      < "$LLAVE.pub"
  fi
  if ! ssh_kira "$ALTA_IP" "$ALTA_PTO" true; then
    printf '\n  \e[1;38;2;255;95;109m✖ No pude entrar con la llave.\e[0m\n\n'
    printf '  Si ese VPS no deja entrar a root con clave, pegá esta línea en el\n'
    printf '  archivo \e[1m/root/.ssh/authorized_keys\e[0m del otro VPS y volvé a intentar:\n\n'
    printf '  \e[38;2;45;212;232m%s\e[0m\n\n' "$(cat "$LLAVE.pub")"
    read -rsn1 -p "  Pulsá una tecla para volver…"
    cursor_off; clear
    AVISO="No se pudo autorizar la llave en $ALTA_IP"
    return 1
  fi
  dir="$(buscar_kira_remoto "$ALTA_IP" "$ALTA_PTO")"
  cursor_off; clear
  sid="$(conf_cambiar srv_agregar "$(python3 -c 'import json,sys; print(json.dumps({"nombre":sys.argv[1],"host":sys.argv[2],"puerto":int(sys.argv[3]),"dir":sys.argv[4]}))' \
          "$ALTA_NOM" "$ALTA_IP" "$ALTA_PTO" "${dir:-/root/kira_key}")")"
  cargar
  reiniciar_si_anda
  if [ -z "$dir" ]; then
    SRV_EST[$sid]="sin kira"
    AVISO="Agregado, pero $ALTA_IP no tiene KIRA: instalalo allá y tocá B para probar"
  else
    SRV_EST[$sid]="ok"
    MENSAJE="$ALTA_NOM agregado · ya lo podés elegir desde el bot"
  fi
  return 0
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
# Fila de "etiqueta  valor" adentro del marco: 2 + 14 + 57 + 1 = 74
fila_dato() { # $1=etiqueta $2=valor [$3=color]
  fila_ancha "$(printf '  %s%s%s%s%s ' "$E_MUT" "$(pad "$1" 14)" \
    "${3:-$E_BLD$E_TXT}" "$(pad "$2" 57)" "$E_RST")"
}
fila_texto() { # $1=texto [$2=color] · renglón suelto de 72
  fila_ancha "$(printf '  %s%s%s ' "${2:-$E_TXT}" "$(pad "$1" 71)" "$E_RST")"
}

opcion() { # $1=número $2=emoji $3=texto
  printf '%s%s%s %s%s%s %s%s%s' "$E_BLD$E_P1" "$(pad "$1" 2)" "$E_RST" \
         "$E_P2" "$2" "$E_RST" "$E_BLD$E_TXT" "$(pad "$3" 31)" "$E_RST"
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
  local et="${1:-Opción:}" vis mostrar="$BUF"
  # El token no se muestra entero mientras se pega: queda en la pantalla y
  # en el scroll de la terminal.
  if [ "$PANTALLA" = token ] && (( ${#BUF} > 10 )); then
    mostrar="${BUF:0:6}$(rep '•' $(( ${#BUF} - 10 )))${BUF: -4}"
  fi
  (( ${#mostrar} > 60 )) && mostrar="…${mostrar: -59}"
  vis=$(( 4 + ${#et} + 1 + ${#mostrar} + 1 ))
  printf '  %s%s❯%s %s%s%s%s %s%s%s\e[48;2;%sm \e[0m%*s\n' \
    "$E_BLD" "$E_P1" "$E_RST" "$E_BLD" "$E_TXT" "$et" "$E_RST" \
    "$E_BLD" "$E_P1" "$mostrar" "$C_P1" $(( ANCHO - vis > 0 ? ANCHO - vis : 0 )) ''
}

# =============================================================== PANTALLA ===
marco_superior() {
  echo
  printf '%s\n' "$REGLA_FIJA"
  printf '%s\n' "$CABECERA_FIJA"
  echo
  banda
  echo
  encabezado "BOT DE TELEGRAM" "KIRA v$KIRA_VER"
  echo
}

caja_estado() {
  local c t
  case "$EST" in
    "en línea")       c="$E_BLD$E_OK";   t="● EN LÍNEA · respondiendo en Telegram" ;;
    apagado)          c="$E_BLD$E_WARN"; t="○ APAGADO · opción 03 para encenderlo" ;;
    "con error")      c="$E_BLD$E_ERR";  t="✖ SE CAYÓ · mirá abajo qué pasó" ;;
    *)                c="$E_MUT";        t="○ SIN CONFIGURAR · seguí los pasos de abajo" ;;
  esac
  techo_ancho "ESTADO DEL BOT"
  fila_dato "ESTADO"        "$t" "$c"
  local usr="—"; [ -n "$CF_BOTUSR" ] && usr="@$CF_BOTUSR"
  fila_dato "BOT"           "$usr" "$E_BLD$E_P1"
  fila_dato "TOKEN"         "$(token_corto)" "$E_TXT"
  fila_dato "ADMINS"        "${CF_ADMINS:-ninguno todavía}" "$E_TXT"
  fila_dato "REVENDEDORES"  "$CF_NREV · $CF_CRED créditos repartidos" "$E_TXT"
  piso_ancho
}

caja_movimientos() {
  local i l
  if [ "$EST" = "sin configurar" ]; then
    techo_ancho "PRIMEROS PASOS"
    fila_texto "1. En Telegram abrí @BotFather, mandale /newbot y seguí los pasos." "$E_TXT"
    fila_texto "   Al final te da un TOKEN: copialo y cargalo con la opción 01." "$E_MUT"
    fila_texto "2. Abrí @userinfobot y te dice tu ID: cargalo con la opción 02." "$E_TXT"
    fila_texto "3. Encendé el bot con la opción 03 y mandale /start a tu bot." "$E_TXT"
    fila_texto "" ; fila_texto ""
    piso_ancho
    return
  fi
  if [ "$EST" = "con error" ]; then
    techo_ancho "LO ÚLTIMO QUE DIJO ANTES DE CAERSE"
    mapfile -t ULTIMOS < <(journalctl -u kira-bot -n 6 -o cat --no-pager 2>/dev/null)
  else
    techo_ancho "ÚLTIMOS MOVIMIENTOS"
  fi
  for ((i=0; i<6; i++)); do
    l="${ULTIMOS[i]:-}"
    if [ -z "$l" ] && (( i == 0 )); then
      fila_texto "Todavía no pasó nada. Mandale /start a tu bot." "$E_MUT"
    else
      fila_texto "$l" "$E_TXT"
    fi
  done
  piso_ancho
}

pintar_inicio() {
  marco_superior
  caja_estado
  echo
  caja_movimientos
  echo
  seccion "QUÉ HACER" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion '01' '🔑' 'CARGAR EL TOKEN')" "$(opcion '02' '👑' 'ADMINISTRADORES')"
  if [ "$EST" = "en línea" ]; then
    printf '  %s  %s\n' "$(opcion '03' '🛑' 'APAGAR EL BOT')" "$(opcion '04' '🔄' 'REINICIAR')"
    printf '  %s  %s\n' "$(opcion '05' '📨' 'MANDARME UN MENSAJE')" "$(opcion '06' '🌎' "SERVIDORES · $(( ${#CF_SRV[@]} + 1 ))")"
  else
    printf '  %s  %s\n' "$(opcion '03' '⚡' 'ENCENDER EL BOT')" "$(opcion '06' '🌎' "SERVIDORES · $(( ${#CF_SRV[@]} + 1 ))")"
  fi
  opcion_salir
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_token() {
  marco_superior
  techo_ancho "TOKEN DEL BOT"
  fila_dato "ACTUAL" "$(token_corto)" "$E_TXT"
  fila_texto ""
  fila_texto "El token te lo da @BotFather en Telegram cuando creás el bot." "$E_TXT"
  fila_texto "Tiene esta forma:  123456789:AAH-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" "$E_MUT"
  fila_texto "Pegalo abajo y dale ENTER: antes de guardarlo se prueba con Telegram." "$E_MUT"
  piso_ancho
  echo
  opcion_salir "CANCELAR"
  echo
  linea_aviso
  prompt "Token:"
}

pintar_admins() {
  local a n=0
  marco_superior
  techo_ancho "ADMINISTRADORES"
  fila_texto "Pueden todo: crear, borrar, ver el servidor y manejar revendedores." "$E_MUT"
  fila_texto ""
  for a in $CF_ADMINS; do
    n=$(( n + 1 )); (( n > 5 )) && break
    fila_dato "ADMIN $n" "$a" "$E_BLD$E_OK"
  done
  (( n == 0 )) && fila_dato "" "ninguno todavía" "$E_MUT"
  for ((; n<5; n++)); do fila_texto ""; done
  piso_ancho
  echo
  printf '  %s%s%s\n' "$E_TXT" "$(pad 'Escribí un ID de Telegram: si no está se agrega, y si ya está se quita.' 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" "$(pad 'Tu ID te lo dice @userinfobot, o tu bot cuando le mandás /id.' 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" "$(pad 'Los revendedores se agregan desde el mismo bot, botón Revendedores.' 76)" "$E_RST"
  echo
  opcion_salir "VOLVER"
  echo
  linea_aviso
  prompt "ID:"
}

pintar_servidores() {
  local f id nom host pto dir est c i=0
  marco_superior
  techo_ancho "SERVIDORES QUE MANEJA EL BOT"
  fila_ancha "$(printf '  %s%s%s%s%s%s%s ' "$E_BLD$E_P1" "$(pad '·' 3)" "$E_RST" \
    "$E_BLD$E_TXT" "$(pad "$CF_LOCAL" 24)" "$E_RST$E_MUT" "$(pad 'este VPS · el bot corre acá' 44)")$E_RST"
  for f in "${CF_SRV[@]}"; do
    i=$(( i + 1 )); (( i > 7 )) && break
    IFS='|' read -r id nom host pto dir <<< "$f"
    est="${SRV_EST[$id]:-sin probar}"
    case "$est" in
      ok)              c="$E_BLD$E_OK";  est="● conectado" ;;
      "sin kira")      c="$E_BLD$E_WARN"; est="▲ falta instalar KIRA" ;;
      "sin respuesta") c="$E_BLD$E_ERR"; est="✖ no responde" ;;
      *)               c="$E_MUT" ;;
    esac
    fila_ancha "$(printf '  %s%s%s%s%s%s%s%s%s%s ' "$E_BLD$E_P1" "$(pad "$i" 3)" "$E_RST" \
      "$E_BLD$E_TXT" "$(pad "$nom" 24)" "$E_RST$E_MUT" "$(pad "$host:$pto" 22)" "$E_RST$c" \
      "$(pad "$est" 22)" "$E_RST")"
  done
  (( i == 0 )) && fila_texto "Todavía no sumaste ningún otro VPS." "$E_MUT"
  for ((; i<7; i++)); do fila_texto ""; done
  piso_ancho
  echo
  printf '  %s%s%s\n' "$E_MUT" "$(pad 'En cada VPS que sumes tiene que estar KIRA instalado: el bot lo usa allá.' 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" "$(pad 'Escribí el número de un servidor para quitarlo de la lista.' 76)" "$E_RST"
  echo
  seccion "OPCIONES · SE ELIGEN CON LETRA" "$E_WARN"
  echo
  printf '  %s  %s\n' "$(opcion 'A' '➕' 'SUMAR UN VPS')" "$(opcion 'B' '🔁' 'PROBAR LA CONEXIÓN')"
  printf '  %s  %s\n' "$(opcion 'C' '📝' 'NOMBRE DE ESTE VPS')" "$(pad '' 37)"
  opcion_salir "VOLVER"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar_alta() {
  local et
  marco_superior
  techo_ancho "SUMAR UN VPS"
  fila_dato "IP"     "${ALTA_IP:-—}"
  fila_dato "PUERTO" "${ALTA_PTO:-—}"
  fila_dato "NOMBRE" "${ALTA_NOM:-—}"
  fila_texto ""
  case "$PANTALLA" in
    alta_ip)  et="IP:";     fila_texto "La IP pública del otro VPS, por ejemplo 161.132.47.70" "$E_TXT" ;;
    alta_pto) et="Puerto:"; fila_texto "El puerto SSH del otro VPS. ENTER solo = 22" "$E_TXT" ;;
    alta_nom) et="Nombre:"; fila_texto "Cómo lo vas a ver en el bot, por ejemplo: Perú 2, EE.UU." "$E_TXT" ;;
    *)        et="Nombre:"; fila_texto "Cómo se llama ESTE VPS en el bot, por ejemplo: Perú 1" "$E_TXT" ;;
  esac
  piso_ancho
  echo
  opcion_salir "CANCELAR"
  echo
  linea_aviso
  prompt "$et"
}

pintar_quitar() {
  local f id nom host pto dir
  for f in "${CF_SRV[@]}"; do
    IFS='|' read -r id nom host pto dir <<< "$f"
    [ "$id" = "$SRV_QUITAR" ] && break
  done
  marco_superior
  seccion "QUITAR $nom" "$E_ERR"
  echo
  printf '  %s%s%s\n' "$E_BLD$E_TXT" "$(pad "El bot deja de manejar $host. Las cuentas de allá siguen andando igual." 76)" "$E_RST"
  printf '  %s%s%s\n' "$E_MUT" "$(pad 'Lo podés volver a sumar cuando quieras con la opción A.' 76)" "$E_RST"
  echo
  printf '  %s  %s\n' "$(opcion '01' '✅' 'SÍ, QUITARLO')" "$(pad '' 37)"
  opcion_salir "NO, VOLVER"
  echo
  linea_aviso
  prompt "Opción:"
}

pintar() {
  case "$PANTALLA" in
    token)      pintar_token ;;
    admins)     pintar_admins ;;
    servidores) pintar_servidores ;;
    alta_*)     pintar_alta ;;
    renombrar)  pintar_alta ;;
    quitar)     pintar_quitar ;;
    *)          pintar_inicio ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# ================================================================= LÓGICA ===
ejecutar() {
  local entrada="$1" r
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    inicio)
      case "$entrada" in
        ""|0|00) clear; exit 0 ;;
        1|01) PANTALLA=token ;;
        2|02) PANTALLA=admins ;;
        3|03)
          if [ "$EST" = "en línea" ]; then
            apagar && MENSAJE="Bot apagado · ya no responde en Telegram"
          else
            render
            encender && MENSAJE="Bot encendido · mandale /start desde Telegram"
          fi
          cargar ;;
        4|04)
          if [ "$EST" = "en línea" ]; then
            systemctl restart kira-bot >/dev/null 2>&1; sleep 2
            MENSAJE="Bot reiniciado"
          else AVISO="El bot está apagado · usá la opción 03"; fi
          cargar ;;
        5|05)
          if [ "$EST" = "en línea" ]; then mensaje_prueba
          else AVISO="Encendé el bot primero"; fi ;;
        6|06)
          PANTALLA=servidores
          if (( ${#CF_SRV[@]} > 0 )); then
            MENSAJE="Probando la conexión con los servidores…"; render; MENSAJE=""
            probar_servidores
          fi ;;
        *) AVISO="Elegí una opción de la lista" ;;
      esac ;;

    servidores)
      case "$entrada" in
        ""|0|00) PANTALLA=inicio ;;
        a|A) ALTA_IP=""; ALTA_PTO=""; ALTA_NOM=""; PANTALLA=alta_ip ;;
        b|B)
          MENSAJE="Probando…"; render; MENSAJE=""
          probar_servidores
          MENSAJE="Listo · conexión probada con ${#CF_SRV[@]} servidor(es)" ;;
        c|C) ALTA_NOM=""; PANTALLA=renombrar ;;
        *)
          if [[ "$entrada" =~ ^[0-9]+$ ]] && (( 10#$entrada >= 1 && 10#$entrada <= ${#CF_SRV[@]} )); then
            SRV_QUITAR="${CF_SRV[$(( 10#$entrada - 1 ))]%%|*}"; PANTALLA=quitar
          else AVISO="Los números son servidores y las letras son opciones"; fi ;;
      esac ;;

    alta_ip)
      case "$entrada" in ""|00) PANTALLA=servidores; return ;; esac
      if ! [[ "$entrada" =~ ^[A-Za-z0-9.:-]{3,60}$ ]]; then AVISO="Escribí la IP o el dominio del otro VPS"; return; fi
      ALTA_IP="$entrada"; PANTALLA=alta_pto ;;
    alta_pto)
      case "$entrada" in 00) PANTALLA=servidores; return ;; "") entrada=22 ;; esac
      if ! [[ "$entrada" =~ ^[0-9]+$ ]] || (( 10#$entrada < 1 || 10#$entrada > 65535 )); then
        AVISO="Un puerto es un número de 1 a 65535"; return
      fi
      ALTA_PTO=$(( 10#$entrada )); PANTALLA=alta_nom ;;
    alta_nom)
      case "$entrada" in ""|00) PANTALLA=servidores; return ;; esac
      ALTA_NOM="${entrada:0:20}"
      PANTALLA=servidores
      alta_servidor ;;

    renombrar)
      case "$entrada" in ""|00) PANTALLA=servidores; return ;; esac
      conf_cambiar nombre_local "${entrada:0:20}" >/dev/null
      cargar; reiniciar_si_anda
      PANTALLA=servidores
      MENSAJE="Este VPS ahora se llama ${entrada:0:20} en el bot" ;;

    quitar)
      case "$entrada" in
        1|01)
          conf_cambiar srv_quitar "$SRV_QUITAR" >/dev/null
          unset "SRV_EST[$SRV_QUITAR]"
          cargar; reiniciar_si_anda
          MENSAJE="Servidor quitado de la lista"; PANTALLA=servidores ;;
        *) PANTALLA=servidores ;;
      esac ;;

    token)
      case "$entrada" in
        ""|0|00) PANTALLA=inicio; return ;;
      esac
      entrada="${entrada// /}"
      if ! [[ "$entrada" =~ ^[0-9]{6,12}:[A-Za-z0-9_-]{30,}$ ]]; then
        AVISO="Eso no parece un token · copialo entero desde @BotFather"; return
      fi
      MENSAJE="Probando con Telegram…"; render; MENSAJE=""
      if ! probar_token "$entrada"; then
        AVISO="Telegram rechazó ese token · revisá que esté completo"; return
      fi
      conf_cambiar token "$entrada" >/dev/null
      cargar
      CF_BOTUSR="$BOT_NUEVO"
      PANTALLA=inicio
      reiniciar_si_anda
      MENSAJE="Token guardado · tu bot es @$BOT_NUEVO" ;;

    admins)
      case "$entrada" in
        ""|00) PANTALLA=inicio; return ;;
      esac
      if ! [[ "$entrada" =~ ^-?[0-9]{4,15}$ ]]; then
        AVISO="Un ID de Telegram son sólo números"; return
      fi
      r="$(conf_cambiar admin "$entrada")"
      cargar
      reiniciar_si_anda
      if [ "$r" = quitado ]; then MENSAJE="$entrada ya no es administrador"
      else MENSAJE="$entrada ahora es administrador"; fi ;;
  esac
}

procesar() {
  case "$1" in
    "")            ejecutar "$BUF"; BUF="" ;;
    $'\177'|$'\b') BUF="${BUF%?}" ;;
    $'\e')         read -rsn2 -t 0.05 _ || true ;;
    *)
      case "$PANTALLA" in
        token)  case "$1" in [[:print:]]) (( ${#BUF} < 80 )) && BUF="$BUF$1" ;; esac ;;
        admins) case "$1" in [0-9-]) (( ${#BUF} < 15 )) && BUF="$BUF$1" ;; esac ;;
        alta_*|renombrar)
                case "$1" in [[:print:]]) (( ${#BUF} < 60 )) && BUF="$BUF$1" ;; esac ;;
        servidores)
                case "$1" in
                  [0-9])     (( ${#BUF} < 2 )) && BUF="$BUF$1" ;;
                  [a-cA-C])  BUF="$1" ;;
                esac ;;
        *)      case "$1" in [0-9]) (( ${#BUF} < 2 )) && BUF="$BUF$1" ;; esac ;;
      esac ;;
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
  redibujar=0
  if (( ahora != SEG_ANT )); then SEG_ANT=$ahora; redibujar=1; fi
  # Los movimientos se releen cada 3 segundos: así ves en vivo lo que se hace
  # desde el celular.
  if [ "$PANTALLA" = inicio ] && (( ahora - CARGA_ANT >= 3 )); then
    cargar; CARGA_ANT=$ahora; redibujar=1
  fi
  (( redibujar )) && render
  read -rsn1 -t 0.25 tecla; rc=$?
  if (( rc == 0 )); then
    procesar "$tecla"
    # Al pegar el token llegan 46 caracteres de golpe: se vacía todo el búfer
    # antes de repintar.
    while read -rsn1 -t 0.01 extra; do procesar "$extra"; done
    render
  elif (( rc <= 128 )); then
    exit 0
  fi
done
