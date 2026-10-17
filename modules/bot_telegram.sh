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

PANTALLA=inicio           # inicio · token · admins · unir · unir_nombre
AVISO=""; MENSAJE=""
BUF=""; SEG_ANT=0; CARGA_ANT=0
EST="sin configurar"      # en línea · apagado · sin configurar · con error · sumado
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
print("CF_UNIDO=%s" % shlex.quote(str(c.get("unido_a", ""))))
sv = c.get("servidores", {})
print("CF_SRV=(%s)" % " ".join(shlex.quote(v.get("nombre", k)) for k, v in sorted(sv.items())))
PY
)"
  CF_TOKEN=""; CF_ADMINS=""; CF_NREV=0; CF_CRED=0; CF_BOTUSR=""; CF_LOCAL="Principal"; CF_SRV=()
  CF_UNIDO=""
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
elif accion == "unir":
    u = json.loads(valor)
    c["unido_a"] = u["ip"]
    c["nombre_local"] = u["nombre"]
    c["admins"] = [int(x) for x in u["admins"].split() if x.lstrip("-").isdigit()]
elif accion == "separar":
    c.pop("unido_a", None)
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
  if [ -n "$CF_UNIDO" ]; then EST="sumado"
  elif [ -z "$CF_TOKEN" ] || [ -z "$CF_ADMINS" ]; then EST="sin configurar"
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

# ============================================== SUMARSE A UN BOT QUE YA ANDA =
# Un mismo bot no puede correr en dos VPS: Telegram repartiría los mensajes
# entre los dos al azar. Así que cuando cargás un token que YA está andando
# en otro VPS, este no prende otro bot: se SUMA al que existe, y desde
# Telegram elegís cuál de los VPS querés mirar.
#
# El bot principal deja su llave pública y los IDs de los admins en la
# descripción del bot, en un idioma que no ve nadie (kl, groenlandés). Acá se
# lee eso, se autoriza la llave y se le avisa al admin para que confirme.
IDIOMA_OCULTO="kl"
PR_IP=""; PR_ADMINS=""; PR_PUB=""
UNIR_NOM=""

detectar_principal() { # $1=token -> 0 si el bot ya anda en OTRO VPS
  PR_IP=""; PR_ADMINS=""; PR_PUB=""
  local d mias
  d="$(curl -s --max-time 10 "https://api.telegram.org/bot$1/getMyDescription?language_code=$IDIOMA_OCULTO" 2>/dev/null |
       python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["description"])' 2>/dev/null)"
  case "$d" in KIRA-PRINCIPAL\ *) ;; *) return 1 ;; esac
  read -r _ PR_IP PR_ADMINS PR_PUB <<< "$d"
  PR_ADMINS="${PR_ADMINS//,/ }"
  [ -n "$PR_IP" ] && [ -n "$PR_PUB" ] || return 1
  # Si el principal es ESTE mismo VPS, no hay nada que sumar
  mias=" $IP_PUB $(hostname -I 2>/dev/null) "
  case "$mias" in *" $PR_IP "*) return 1 ;; esac
  return 0
}

# La llave del principal entra RESTRINGIDA: con ella sólo se puede correr el
# bot de KIRA en modo orden (--rpc). Ni consola, ni túneles, ni nada más.
# Aunque alguien robara esa llave, no podría usar este VPS para otra cosa.
autorizar_llave() { # $1=llave pública
  local ak=/root/.ssh/authorized_keys
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  touch "$ak" && chmod 600 "$ak"
  grep -v 'kira-bot.py --rpc' "$ak" > "$ak.kira.tmp" 2>/dev/null
  printf 'command="KIRA_DIR=%s python3 %s/kira-bot.py --rpc",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s\n' \
    "$DIR" "$DIR" "$1" >> "$ak.kira.tmp"
  mv -f "$ak.kira.tmp" "$ak"
}

quitar_llave() {
  local ak=/root/.ssh/authorized_keys
  [ -f "$ak" ] || return 0
  grep -v 'kira-bot.py --rpc' "$ak" > "$ak.kira.tmp" 2>/dev/null
  mv -f "$ak.kira.tmp" "$ak"
}

puerto_ssh() {
  local p
  p="$(sshd -T 2>/dev/null | awk '$1=="port"{print $2; exit}')"
  printf '%s' "${p:-22}"
}

# Le manda a los admins el mensaje con el botón ✅. Lo atiende el bot del
# principal: este VPS no lee mensajes, sólo los manda.
pedir_union() { # usa CF_TOKEN, PR_ADMINS, UNIR_NOM
  python3 - "$CF_TOKEN" "$UNIR_NOM" "$IP_PUB" "$(puerto_ssh)" "$DIR" $PR_ADMINS <<'PY'
import json, sys, urllib.parse, urllib.request
token, nombre, ip, puerto, carpeta, *admins = sys.argv[1:]
texto = ("🆕 Un VPS quiere sumarse a este bot\n\n"
         f"Nombre: {nombre}\nIP: {ip}\nPuerto SSH: {puerto}\nCarpeta: {carpeta}\n\n"
         "Tocá ✅ y desde 🌎 vas a poder manejarlo desde acá.")
teclado = {"inline_keyboard": [[{"text": f"✅ Sumar {nombre}", "callback_data": f"J:{ip}:{puerto}"}],
                               [{"text": "✖ Ignorar", "callback_data": "Jx"}]]}
ok = 0
for a in admins:
    datos = urllib.parse.urlencode({"chat_id": a, "text": texto,
                                    "reply_markup": json.dumps(teclado)}).encode()
    try:
        r = json.loads(urllib.request.urlopen(
            f"https://api.telegram.org/bot{token}/sendMessage", datos, timeout=10).read())
        ok += 1 if r.get("ok") else 0
    except Exception:
        pass
print(ok)
PY
}

unir_vps() {
  local n
  apagar                                   # acá no corre ningún bot
  autorizar_llave "$PR_PUB"
  conf_cambiar unir "$(python3 -c 'import json,sys; print(json.dumps({"ip":sys.argv[1],"nombre":sys.argv[2],"admins":sys.argv[3]}))' \
                       "$PR_IP" "$UNIR_NOM" "$PR_ADMINS")" >/dev/null
  cargar
  n="$(pedir_union)"
  if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
    MENSAJE="Listo · tocá ✅ Sumar en el mensaje que te llegó a Telegram"
  else
    AVISO="No pude mandar el aviso · abrí el bot y mandale /start, después opción 02"
  fi
}

separar_vps() {
  quitar_llave
  conf_cambiar separar "" >/dev/null
  cargar
  MENSAJE="Este VPS ya no está sumado · quitalo también de la lista en el bot"
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
    sumado)           c="$E_BLD$E_P1";   t="◆ SUMADO al bot que corre en $CF_UNIDO" ;;
    *)                c="$E_MUT";        t="○ SIN CONFIGURAR · seguí los pasos de abajo" ;;
  esac
  techo_ancho "ESTADO DEL BOT"
  fila_dato "ESTADO"        "$t" "$c"
  local usr="—"; [ -n "$CF_BOTUSR" ] && usr="@$CF_BOTUSR"
  fila_dato "BOT"           "$usr" "$E_BLD$E_P1"
  fila_dato "TOKEN"         "$(token_corto)" "$E_TXT"
  fila_dato "ADMINS"        "${CF_ADMINS:-ninguno todavía}" "$E_TXT"
  if [ "$EST" = sumado ]; then
    fila_dato "ESTE VPS"    "se ve en el bot como: $CF_LOCAL" "$E_TXT"
  elif (( ${#CF_SRV[@]} > 0 )); then
    local todos="$CF_LOCAL" s
    for s in "${CF_SRV[@]}"; do todos="$todos · $s"; done
    fila_dato "SERVIDORES"  "$(( ${#CF_SRV[@]} + 1 )) · $todos" "$E_TXT"
  else
    fila_dato "REVENDEDORES" "$CF_NREV · $CF_CRED créditos repartidos" "$E_TXT"
  fi
  piso_ancho
}

caja_movimientos() {
  local i l
  if [ "$EST" = sumado ]; then
    techo_ancho "CÓMO FUNCIONA"
    fila_texto "Este VPS no corre su propio bot: lo maneja el bot del VPS $CF_UNIDO." "$E_TXT"
    fila_texto "En Telegram tocá 'Cambiar de servidor' y elegí: $CF_LOCAL" "$E_TXT"
    fila_texto ""
    fila_texto "Si nunca tocaste ✅ en el aviso que te llegó, usá la opción 02" "$E_MUT"
    fila_texto "para que te lo mande de nuevo." "$E_MUT"
    fila_texto ""
    piso_ancho
    return
  fi
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
  if [ "$EST" = sumado ]; then
    printf '  %s  %s\n' "$(opcion '01' '🔑' 'CARGAR OTRO TOKEN')" "$(opcion '02' '📨' 'REPETIR EL AVISO')"
    printf '  %s  %s\n' "$(opcion '03' '🔌' 'SEPARAR ESTE VPS')" "$(pad '' 37)"
  elif [ "$EST" = "en línea" ]; then
    printf '  %s  %s\n' "$(opcion '01' '🔑' 'CARGAR EL TOKEN')" "$(opcion '02' '👑' 'ADMINISTRADORES')"
    printf '  %s  %s\n' "$(opcion '03' '🛑' 'APAGAR EL BOT')" "$(opcion '04' '🔄' 'REINICIAR')"
    printf '  %s  %s\n' "$(opcion '05' '📨' 'MANDARME UN MENSAJE')" "$(pad '' 37)"
  else
    printf '  %s  %s\n' "$(opcion '01' '🔑' 'CARGAR EL TOKEN')" "$(opcion '02' '👑' 'ADMINISTRADORES')"
    printf '  %s  %s\n' "$(opcion '03' '⚡' 'ENCENDER EL BOT')" "$(pad '' 37)"
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

pintar_unir() {
  marco_superior
  techo_ancho "ESTE BOT YA FUNCIONA EN OTRO VPS"
  local usr="—"; [ -n "$BOT_NUEVO" ] && usr="@$BOT_NUEVO"
  fila_dato "BOT"        "$usr" "$E_BLD$E_P1"
  fila_dato "CORRE EN"   "$PR_IP" "$E_BLD$E_TXT"
  fila_dato "ADMINS"     "$PR_ADMINS" "$E_TXT"
  fila_texto ""
  fila_texto "Un bot no puede correr en dos VPS a la vez. Lo que se hace es SUMAR" "$E_TXT"
  fila_texto "este VPS al bot que ya anda: desde Telegram elegís cuál querés mirar." "$E_TXT"
  piso_ancho
  echo
  if [ "$PANTALLA" = unir ]; then
    printf '  %s  %s\n' "$(opcion '01' '🔗' 'SUMAR ESTE VPS AL BOT')" "$(opcion '02' '💾' 'SÓLO GUARDAR EL TOKEN')"
    opcion_salir "CANCELAR"
    echo
    linea_aviso
    prompt "Opción:"
  else
    printf '  %s%s%s\n' "$E_TXT" "$(pad '¿Cómo querés ver este VPS en el bot? Por ejemplo: Perú 2, EE.UU.' 76)" "$E_RST"
    printf '  %s%s%s\n' "$E_MUT" "$(pad "ENTER solo = $(hostname -s 2>/dev/null)" 76)" "$E_RST"
    echo
    opcion_salir "CANCELAR"
    echo
    linea_aviso
    prompt "Nombre:"
  fi
}

pintar() {
  case "$PANTALLA" in
    token)       pintar_token ;;
    admins)      pintar_admins ;;
    unir|unir_*) pintar_unir ;;
    *)           pintar_inicio ;;
  esac
}
render() { local f; f="$(pintar)"; volcar "$f"; }

# ================================================================= LÓGICA ===
ejecutar() {
  local entrada="$1" r n
  AVISO=""; MENSAJE=""
  case "$PANTALLA" in
    inicio)
      if [ "$EST" = sumado ]; then
        case "$entrada" in
          ""|0|00) clear; exit 0 ;;
          1|01) PANTALLA=token ;;
          2|02)
            # Para repetir el aviso hacen falta los datos del principal: se
            # vuelven a leer de Telegram por si cambiaron los admins.
            if detectar_principal "$CF_TOKEN"; then
              UNIR_NOM="$CF_LOCAL"; autorizar_llave "$PR_PUB"
              n="$(pedir_union)"
              if [ "${n:-0}" -gt 0 ] 2>/dev/null; then MENSAJE="Aviso enviado · tocá ✅ Sumar en Telegram"
              else AVISO="No llegó · mandale /start al bot desde tu Telegram y probá de nuevo"; fi
            else
              AVISO="El bot principal no está publicando sus datos · ¿está encendido en $CF_UNIDO?"
            fi ;;
          3|03) separar_vps ;;
          *) AVISO="Elegí una opción de la lista" ;;
        esac
        return
      fi
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
        *) AVISO="Elegí una opción de la lista" ;;
      esac ;;

    unir)
      case "$entrada" in
        1|01) UNIR_NOM=""; PANTALLA=unir_nombre ;;
        2|02)
          PANTALLA=inicio
          MENSAJE="Token guardado · no lo prendas acá mientras ande en $PR_IP" ;;
        *) PANTALLA=inicio ;;
      esac ;;

    unir_nombre)
      case "$entrada" in 00) PANTALLA=inicio; return ;; "") entrada="$(hostname -s 2>/dev/null)" ;; esac
      UNIR_NOM="${entrada:0:20}"
      PANTALLA=inicio
      MENSAJE="Sumando…"; render; MENSAJE=""
      unir_vps ;;

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
      # ¿Ese bot ya está andando en otro VPS? Entonces este se suma a ese
      # en vez de prender un segundo bot que choque con el primero.
      if detectar_principal "$entrada"; then
        cargar
        PANTALLA=unir
        return
      fi
      # Era un VPS sumado y le cargaron un token nuevo: deja de estar sumado
      [ -n "$CF_UNIDO" ] && { quitar_llave; conf_cambiar separar "" >/dev/null; }
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
        unir_nombre)
                case "$1" in [[:print:]]) (( ${#BUF} < 20 )) && BUF="$BUF$1" ;; esac ;;
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
