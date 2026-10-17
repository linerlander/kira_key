#!/usr/bin/env python3
# =============================================================================
#  KIRA · BOT DE TELEGRAM
#  El panel entero en el celular, con botones: crear cuentas, demos, renovar,
#  cortar, bloquear, borrar, revendedores con créditos y avisos automáticos.
#
#  Usa los MISMOS datos que el panel (db/claves, db/limites, db/demos,
#  /etc/shadow), así que lo que se hace acá aparece allá y al revés, y el
#  vigilante y kira-limite controlan estas cuentas igual que las otras.
#
#  Sólo librería estándar de Python 3: no hay nada que instalar con pip.
#  Lo arranca systemd (kira-bot.service); se configura desde el módulo 11.
# =============================================================================
import datetime
import html
import json
import os
import pwd
import re
import secrets
import subprocess
import sys
import threading
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

KIRA_DIR = os.environ.get("KIRA_DIR") or os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(KIRA_DIR, "db")
CONF = os.path.join(DB, "bot.json")
ESTADO = os.path.join(DB, "bot_estado.json")
LOG = os.path.join(DB, "bot.log")

SSHD = {"sshd", "sshd-session", "sshd-auth", "dropbear", "dropbearmulti"}
UMBRAL_VENCE = 7          # días para considerar que una cuenta "está por vencer"
DEMO_MIN = 60             # cuánto dura una demo
DEMOS_POR_REV = 3         # demos vivas a la vez que puede tener un revendedor
POR_PAGINA = 8
MAX_DIAS = 3650
MAX_LIMITE = 99
MULTI_CORTES = 6          # cortes por hora que ya huelen a cuenta compartida
RE_USUARIO = re.compile(r"^[a-z_][a-z0-9_-]{0,19}$")
LINEA = "━━━━━━━━━━━━━━━━━━━━"
esc = html.escape

ICONO = {"activa": "🟢", "pronto": "🟡", "vencida": "🔴", "bloqueada": "🔒",
         "prueba": "🎁", "sin tope": "♾️", "sin clave": "⚪"}

cerrojo = threading.RLock()
TOKEN = ""


class Aviso(Exception):
    """Algo que hay que decirle al que tocó el botón, en el cartelito de arriba."""


# =============================================================== REGISTRO ====
# Lo lee el módulo 11 para mostrar "últimos movimientos". Sin emojis a
# propósito: en la terminal un emoji ocupa dos columnas y corre el marco.
def registro(txt):
    try:
        os.makedirs(DB, exist_ok=True)
        with open(LOG, "a") as f:
            f.write(time.strftime("%d/%m %H:%M") + "  " + txt + "\n")
        if os.path.getsize(LOG) > 200_000:
            with open(LOG) as f:
                ultimas = f.readlines()[-500:]
            with open(LOG, "w") as f:
                f.writelines(ultimas)
    except Exception:
        pass


# ========================================================= CONFIGURACIÓN ====
DEF_AVISOS = {"vence": True, "multi": True, "vps": True}


def guardar_json(ruta, datos, modo=0o600):
    os.makedirs(DB, exist_ok=True)
    tmp = ruta + ".tmp"
    with open(tmp, "w") as f:
        json.dump(datos, f, indent=2, ensure_ascii=False)
    os.chmod(tmp, modo)
    os.replace(tmp, ruta)


def _cargar(ruta):
    try:
        with open(ruta) as f:
            return json.load(f)
    except Exception:
        return {}


def _completar(c):
    c.setdefault("token", "")
    c.setdefault("admins", [])
    c.setdefault("revendedores", {})
    c.setdefault("avisos", {})
    for k, v in DEF_AVISOS.items():
        c["avisos"].setdefault(k, v)
    c["admins"] = [int(x) for x in c["admins"] if str(x).lstrip("-").isdigit()]
    return c


def leer_conf():
    with cerrojo:
        return _completar(_cargar(CONF))


def cambiar_conf(fn):
    """Lee, aplica fn y guarda, todo bajo el mismo candado: el hilo de avisos
    y el de los mensajes no se pisan los cambios."""
    with cerrojo:
        c = _completar(_cargar(CONF))
        r = fn(c)
        guardar_json(CONF, c)
        return r


def rol(tg, c=None):
    c = c or leer_conf()
    if tg in c["admins"]:
        return "admin"
    if str(tg) in c["revendedores"]:
        return "rev"
    return None


def creditos(tg, c=None):
    c = c or leer_conf()
    return int(c["revendedores"].get(str(tg), {}).get("creditos", 0))


def cobrar(tg, n):
    """Descuenta n créditos. Los admins no pagan. False si no le alcanza."""
    def f(c):
        if tg in c["admins"]:
            return True
        r = c["revendedores"].get(str(tg))
        if r is None or int(r.get("creditos", 0)) < n:
            return False
        r["creditos"] = int(r.get("creditos", 0)) - n
        return True
    return cambiar_conf(f)


def devolver(tg, n):
    def f(c):
        r = c["revendedores"].get(str(tg))
        if r is not None and tg not in c["admins"]:
            r["creditos"] = int(r.get("creditos", 0)) + n
    cambiar_conf(f)


# ============================================================== TELEGRAM ====
def api(metodo, **p):
    # Listas, diccionarios y booleanos van como JSON: urlencode mandaría
    # "True" con mayúscula y Telegram no lo entiende.
    datos = {k: (json.dumps(v, ensure_ascii=False) if isinstance(v, (dict, list, bool)) else v)
             for k, v in p.items() if v is not None}
    espera = int(p.get("timeout") or 0) + 20
    req = urllib.request.Request(f"https://api.telegram.org/bot{TOKEN}/{metodo}",
                                 data=urllib.parse.urlencode(datos).encode())
    try:
        with urllib.request.urlopen(req, timeout=espera) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read().decode())
        except Exception:
            return {"ok": False, "description": str(e)}
    except Exception as e:
        return {"ok": False, "description": str(e)}


def b(texto, dato):
    return {"text": texto, "callback_data": dato[:64]}


def _teclado(filas):
    return {"inline_keyboard": [f for f in filas if f]} if filas else None


def enviar(chat, texto, filas=None):
    return api("sendMessage", chat_id=chat, text=texto, parse_mode="HTML",
               disable_web_page_preview=True, reply_markup=_teclado(filas))


def editar(chat, msg, texto, filas=None):
    """Navegar = editar el mismo mensaje. Así el chat no se llena de menús
    viejos y se siente una app, no una conversación."""
    if msg is None:
        return enviar(chat, texto, filas)
    r = api("editMessageText", chat_id=chat, message_id=msg, text=texto, parse_mode="HTML",
            disable_web_page_preview=True, reply_markup=_teclado(filas))
    if not r.get("ok") and "not modified" not in r.get("description", ""):
        r = enviar(chat, texto, filas)
    return r


def nombre_de(u):
    n = u.get("first_name") or ""
    if u.get("username"):
        n = f"{n} @{u['username']}".strip()
    return n or str(u.get("id"))


# ============================================================ ARCHIVOS DB ===
def ruta(n):
    return os.path.join(DB, n)


def leer_lineas(n):
    try:
        with open(ruta(n)) as f:
            return [l.rstrip("\n") for l in f if l.strip()]
    except Exception:
        return []


def leer_pares(n):
    d = {}
    for l in leer_lineas(n):
        p = l.split(None, 1)
        d[p[0]] = p[1].strip() if len(p) > 1 else ""
    return d


def poner_par(n, usuario, valor, modo=0o644, crear=True):
    """Reescribe la línea del usuario en db/<n>. valor None la saca.
    Mismo formato que usa el panel: "usuario valor" (bloqueos va con |)."""
    if not crear and not os.path.exists(ruta(n)):
        return
    os.makedirs(DB, exist_ok=True)
    sep = "|" if n == "bloqueos" else " "
    lineas = [l for l in leer_lineas(n) if l.split(sep, 1)[0].split()[0] != usuario]
    if valor is not None:
        lineas.append(f"{usuario}{sep}{valor}")
    tmp = ruta("." + n + ".tmp")
    with open(tmp, "w") as f:
        f.write("".join(x + "\n" for x in lineas))
    os.chmod(tmp, modo)
    os.replace(tmp, ruta(n))


# ============================================================== SISTEMA =====
def clientes():
    """Las cuentas vendibles: UID >= 1000, como en todo el panel."""
    return {p.pw_name: p.pw_uid for p in pwd.getpwall()
            if p.pw_uid >= 1000 and p.pw_uid != 65534 and p.pw_name not in ("nobody", "nogroup")}


def leer_shadow():
    s = {}
    try:
        with open("/etc/shadow") as f:
            for l in f:
                p = l.rstrip("\n").split(":")
                if len(p) >= 8:
                    s[p[0]] = (p[1], int(p[7]) if p[7].isdigit() else None)
    except Exception:
        pass
    return s


def procesos(solo_ssh=True):
    """uid -> [pid]. Por DUEÑO del proceso, igual que el vigilante: un túnel
    de HTTP Injector no deja rastro en utmp. Los zombis no cuentan."""
    por = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            if solo_ssh:
                with open(f"/proc/{d}/comm") as f:
                    if f.read().strip() not in SSHD:
                        continue
            est = uid = None
            with open(f"/proc/{d}/status") as f:
                for l in f:
                    if l.startswith("State:"):
                        est = l.split()[1]
                    elif l.startswith("Uid:"):
                        uid = int(l.split()[1])
                        break
            if est != "Z" and uid is not None and uid >= 1000:
                por.setdefault(uid, []).append(int(d))
        except Exception:
            continue
    return por


def correr(cmd, entrada=None):
    try:
        p = subprocess.run(cmd, input=entrada, capture_output=True, text=True, timeout=30)
        msg = (p.stderr or p.stdout or "").strip()
        return p.returncode == 0, (msg.splitlines()[0] if msg else "")
    except Exception as e:
        return False, str(e)


def cuentas():
    """Todas las cuentas con todo lo que se sabe de cada una, en una pasada."""
    cli = clientes()
    sh = leer_shadow()
    con = procesos()
    lim = leer_pares("limites")
    clv = leer_pares("claves")
    due = leer_pares("duenos")
    dem = leer_pares("demos")
    bloq = {}
    for l in leer_lineas("bloqueos"):
        p = l.split("|")
        bloq[p[0]] = p
    mes = time.strftime("%Y%m")
    cons = {}
    for l in leer_lineas("consumo"):
        p = l.split()
        if len(p) >= 4 and p[3] == mes and p[2].isdigit():
            cons[p[0]] = int(p[2])

    ahora = time.time()
    res = {}
    for n, uid in cli.items():
        if n not in sh:
            continue
        clave, vto = sh[n]
        d = (dem.get(n) or "").split()
        es_demo = bool(d) and d[0].isdigit()
        if es_demo:
            fin = int(d[0])
        elif vto is not None:
            fin = vto * 86400
        else:
            fin = 0
        if clave in ("!", "!!", "*", ""):
            est = "sin clave"
        elif clave.startswith("!"):
            est = "bloqueada"
        elif es_demo:
            est = "prueba" if fin > ahora else "vencida"
        elif not fin:
            est = "sin tope"
        elif fin <= ahora:
            est = "vencida"
        elif fin - ahora <= UMBRAL_VENCE * 86400:
            est = "pronto"
        else:
            est = "activa"
        l = lim.get(n, "")
        res[n] = {"nombre": n, "uid": uid, "estado": est, "fin": fin, "demo": es_demo, "vto": vto,
                  "limite": int(l) if l.isdigit() else 0, "conex": len(con.get(uid, [])),
                  "clave": clv.get(n, ""), "dueno": due.get(n, ""), "consumo": cons.get(n, 0),
                  "motivo": bloq[n][2] if n in bloq and len(bloq[n]) > 2 else ""}
    return res


def mias(tg, todas, c=None):
    """El admin ve todo. El revendedor, sólo las cuentas que creó él."""
    if rol(tg, c) == "admin":
        return todas
    return {n: x for n, x in todas.items() if x["dueno"] == str(tg)}


def obtener(tg, nombre):
    x = cuentas().get(nombre)
    if x is None:
        raise Aviso(f"La cuenta {nombre} ya no existe")
    if rol(tg) != "admin" and x["dueno"] != str(tg):
        raise Aviso("Esa cuenta no es tuya")
    return x


# =========================================================== FORMATEO =======
def restante(seg):
    if seg <= 0:
        return "vencida"
    d = int(seg // 86400)
    if d >= 2:
        return f"{d} días"
    return f"{int(seg // 3600)}h {int(seg % 3600 // 60):02d}m"


def restante_corto(x):
    if not x["fin"]:
        return "∞"
    s = x["fin"] - time.time()
    if s <= 0:
        return "vencida"
    if s >= 172800:
        return f"{int(s // 86400)}d"
    return f"{int(s // 3600)}h{int(s % 3600 // 60):02d}"


def fecha_txt(x):
    if not x["fin"]:
        return "sin fecha"
    f = datetime.datetime.fromtimestamp(x["fin"])
    return f.strftime("%d/%m a las %H:%M") if x["demo"] else f.strftime("%d/%m/%Y")


def bytes_hum(n):
    for u in ("B", "K", "M", "G", "T"):
        if n < 1024 or u == "T":
            return f"{n:.0f}{u}" if u == "B" else f"{n:.1f}{u}"
        n /= 1024


def barra(pct, w=10):
    pct = max(0, min(100, int(pct)))
    k = round(pct * w / 100)
    punto = "🟢" if pct < 70 else ("🟡" if pct < 90 else "🔴")
    return f"{punto} {'▰' * k}{'▱' * (w - k)} <b>{pct}%</b>"


def tira(pct, w=12):
    """La barra sola, sin número ni color: para meterla en una tabla."""
    pct = max(0, min(100, int(pct)))
    k = round(pct * w / 100)
    if pct > 0 and k == 0:
        k = 1
    return "▰" * k + "▱" * (w - k)


# =============================================================== ESTILO =====
# Telegram no deja elegir tipografía, pero Unicode trae letras "dibujadas" en
# negrita sin serifa y en versalitas. Con eso los títulos se ven como un logo
# en vez de texto común. Sólo para títulos: el dato que se copia va siempre
# en letras normales, si no el cliente copiaría caracteres raros.

_NEGRITA = {}
for _i, _c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
    _NEGRITA[_c] = chr(0x1D5D4 + _i)
for _i, _c in enumerate("abcdefghijklmnopqrstuvwxyz"):
    _NEGRITA[_c] = chr(0x1D5EE + _i)
for _i, _c in enumerate("0123456789"):
    _NEGRITA[_c] = chr(0x1D7EC + _i)
_VERSAL = dict(zip("abcdefghijklmnopqrstuvwxyz",
                   "ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀꜱᴛᴜᴠᴡxʏᴢ"))


def _sin_tildes(t):
    return "".join(c for c in unicodedata.normalize("NFD", t) if unicodedata.category(c) != "Mn")


def negrita(t):
    return "".join(_NEGRITA.get(c, c) for c in _sin_tildes(t))


def versal(t):
    return "".join(_VERSAL.get(c, c) for c in _sin_tildes(t).lower())


def titulo(emoji, txt, sub=""):
    s = f"{emoji} {negrita(txt)}"
    return s + (f"  ·  <i>{versal(sub)}</i>" if sub else "")


def cita(*lineas):
    """Recuadro de Telegram: la barrita de color al costado agrupa el bloque."""
    return "<blockquote>" + "\n".join(l for l in lineas if l is not None) + "</blockquote>"


def tabla(pares, ancho=24):
    """Etiqueta ....... valor, en letra de ancho fijo: las columnas quedan
    derechas en cualquier celular."""
    filas = []
    for k, v in pares:
        k, v = str(k), str(v)
        puntos = max(2, ancho - len(k) - len(v) - 2)
        filas.append(f"{esc(k)} {'·' * puntos} {esc(v)}")
    return "<pre>" + "\n".join(filas) + "</pre>"


def clave_azar():
    # Sin 0/O ni 1/l/i: se confunden al dictarla por WhatsApp
    return "".join(secrets.choice("abcdefghijkmnpqrstuvwxyz23456789") for _ in range(8))


def error_clave(c):
    if len(c) < 4:
        return "Muy corta: mínimo 4 caracteres"
    if len(c) > 40:
        return "Muy larga: máximo 40 caracteres"
    if ":" in c or " " in c:
        return "No puede llevar espacios ni dos puntos"
    if not all(33 <= ord(ch) < 127 for ch in c):
        return "Sólo letras, números y símbolos comunes (sin tildes ni emojis)"
    return ""


# ========================================================= DATOS DEL VPS ====
def ip_publica():
    cache = "/tmp/kira-ip"
    try:
        if time.time() - os.path.getmtime(cache) < 3600:
            ip = open(cache).read().strip()
            if ip:
                return ip
    except Exception:
        pass
    ip = ""
    for url in ("https://api.ipify.org", "https://ifconfig.me/ip"):
        try:
            ip = urllib.request.urlopen(url, timeout=5).read().decode().strip()
            if re.match(r"^[0-9a-fA-F.:]+$", ip):
                break
        except Exception:
            ip = ""
    if not ip:
        ok, out = correr(["hostname", "-I"])
        ip = out.split()[0] if ok and out else "tu-servidor"
    try:
        with open(cache, "w") as f:
            f.write(ip)
    except Exception:
        pass
    return ip


def soporte():
    try:
        m = re.search(r'^KIRA_SOP="([^"]*)"', open(os.path.join(KIRA_DIR, "lib/ui.sh")).read(), re.M)
        if m:
            return m.group(1)
    except Exception:
        pass
    return ""


ORDEN_SRV = ["SSH", "Dropbear", "SSL / TLS", "WebSocket", "V2Ray", "Shadowsocks", "OpenVPN", "UDPGW"]


def servicio_de(prog):
    p = prog.lower()
    if p in ("sshd", "sshd-session"):
        return "SSH"
    if p.startswith("dropbear"):
        return "Dropbear"
    if p.startswith("stunnel"):
        return "SSL / TLS"
    if p.startswith("python") or p in ("nginx", "ws", "wsproxy", "websocket", "ws-epro"):
        return "WebSocket"
    if p in ("v2ray", "xray"):
        return "V2Ray"
    if p.startswith("ss-") or "shadowsocks" in p:
        return "Shadowsocks"
    if p == "openvpn":
        return "OpenVPN"
    if "udpgw" in p:
        return "UDPGW"
    return ""


_ptos = [0.0, []]


def puertos():
    """Lo que está ESCUCHANDO de verdad, no lo que dice un archivo de config.
    Se guarda dos minutos: ss no es gratis y los puertos casi no cambian."""
    if time.time() - _ptos[0] < 120:
        return _ptos[1]
    efimero = 32768
    try:
        efimero = int(open("/proc/sys/net/ipv4/ip_local_port_range").read().split()[0])
    except Exception:
        pass
    por = {}
    for proto in ("t", "u"):
        try:
            out = subprocess.run(["ss", f"-{proto}lnpH"], capture_output=True, text=True, timeout=10).stdout
        except Exception:
            out = ""
        for l in out.splitlines():
            c = l.split()
            m = re.search(r'users:\(\("([^"]+)"', l)
            if len(c) < 5 or not m:
                continue
            ip, _, pto = c[3].rpartition(":")
            if not pto.isdigit():
                continue
            s = servicio_de(m.group(1))
            if not s:
                continue
            # Lo que escucha sólo en 127.0.0.1 no le sirve al cliente, salvo
            # udpgw, que se usa a través del túnel.
            if s != "UDPGW" and (ip.startswith("127.") or ip in ("[::1]", "::1")):
                continue
            # UDP no tiene "escuchando": los puertos altos son flujos sueltos.
            if proto == "u" and int(pto) >= efimero:
                continue
            por.setdefault(s, set()).add(int(pto))
    res = [(s, sorted(por[s])[:4]) for s in ORDEN_SRV if s in por]
    _ptos[0], _ptos[1] = time.time(), res
    return res


_cpu_ant = [0, 0]


def leer_cpu():
    with open("/proc/stat") as f:
        v = [int(x) for x in f.readline().split()[1:]]
    return v[3] + (v[4] if len(v) > 4 else 0), sum(v)


def cpu_pct(espera=0.0):
    if espera:
        _cpu_ant[0], _cpu_ant[1] = leer_cpu()
        time.sleep(espera)
    i2, t2 = leer_cpu()
    di, dt = i2 - _cpu_ant[0], t2 - _cpu_ant[1]
    _cpu_ant[0], _cpu_ant[1] = i2, t2
    return 0 if dt <= 0 else int(100 * (dt - di) / dt)


def ram_pct():
    m = {}
    with open("/proc/meminfo") as f:
        for l in f:
            k, v = l.split(":", 1)
            m[k] = int(v.split()[0])
    tot = m.get("MemTotal", 1)
    usa = tot - m.get("MemAvailable", m.get("MemFree", 0))
    return int(usa * 100 / tot), usa * 1024, tot * 1024


def disco_pct():
    s = os.statvfs("/")
    tot = s.f_blocks * s.f_frsize
    usa = tot - s.f_bfree * s.f_frsize
    return int(usa * 100 / tot) if tot else 0, usa, tot


# ============================================================== ACCIONES ====
def crear_cuenta(nombre, clave, vence, limite, dueno, demo_fin=None):
    """Igual que el módulo 01 del panel: sin carpeta personal y sin consola,
    la clave guardada aparte y el límite en db/limites."""
    ok, err = correr(["useradd", "-M", "-s", "/bin/false", "-e", vence, nombre])
    if not ok:
        return f"No se pudo crear: {err}"
    ok, err = correr(["chpasswd"], f"{nombre}:{clave}\n")
    if not ok:
        correr(["userdel", nombre])
        return f"Falló la contraseña: {err}"
    poner_par("claves", nombre, clave, 0o600)
    poner_par("limites", nombre, str(limite))
    if dueno:
        poner_par("duenos", nombre, dueno)
    if demo_fin:
        poner_par("demos", nombre, str(demo_fin))
    return ""


def cortar(uid):
    n = 0
    for pid in procesos().get(uid, []):
        try:
            os.kill(pid, 9)
            n += 1
        except Exception:
            pass
    return n


def renovar(x, dias):
    """Si todavía está viva, se suma a SU vencimiento: pagó 30 días más, no 30
    desde hoy. Si ya venció, desde hoy. La fecha va en UTC, como chage espera."""
    hoy = int(time.time() // 86400)
    base = x["vto"] if (x["vto"] and x["vto"] > hoy and not x["demo"]) else hoy
    nuevo = base + dias
    fecha = datetime.datetime.fromtimestamp(nuevo * 86400, datetime.timezone.utc).strftime("%Y-%m-%d")
    ok, err = correr(["chage", "-E", fecha, x["nombre"]])
    if not ok:
        raise Aviso(f"No se pudo renovar: {err}")
    if x["demo"]:
        poner_par("demos", x["nombre"], None)     # renovada, deja de ser prueba
    return nuevo


def bloquear(x, motivo):
    ok, err = correr(["usermod", "-L", x["nombre"]])
    if not ok:
        raise Aviso(f"No se pudo bloquear: {err}")
    poner_par("bloqueos", x["nombre"], f"{time.strftime('%d/%m/%Y')}|{motivo}")
    return cortar(x["uid"])


def desbloquear(x):
    # Si detrás del "!" no hay clave, desbloquear dejaría entrar sin contraseña
    clave = leer_shadow().get(x["nombre"], ("", None))[0]
    if clave in ("!", "!!", "!*", ""):
        raise Aviso("No tiene contraseña: generale una antes")
    ok, err = correr(["usermod", "-U", x["nombre"]])
    if not ok:
        raise Aviso(f"No se pudo desbloquear: {err}")
    poner_par("bloqueos", x["nombre"], None, crear=False)


def borrar_cuenta(nombre, uid):
    for pid in procesos(solo_ssh=False).get(uid, []):
        try:
            os.kill(pid, 9)
        except Exception:
            pass
    time.sleep(0.2)
    ok, err = correr(["userdel", nombre])
    if not ok:
        raise Aviso(f"No se pudo borrar: {err}")
    for f in ("limites", "demos", "consumo", "duenos", "bloqueos"):
        poner_par(f, nombre, None, crear=False)
    poner_par("claves", nombre, None, 0o600, crear=False)


# ============================================================== PANTALLAS ===
def pant_inicio(tg):
    c = leer_conf()
    r = rol(tg, c)
    todas = mias(tg, cuentas(), c)
    total = len(todas)
    online = sum(1 for x in todas.values() if x["conex"] > 0)
    pronto = sum(1 for x in todas.values() if x["estado"] == "pronto")
    venc = sum(1 for x in todas.values() if x["estado"] == "vencida")
    pares = [("CUENTAS", total), ("EN LINEA", online), ("POR VENCER", pronto), ("VENCIDAS", venc)]
    if r == "rev":
        pares.append(("CREDITOS", creditos(tg, c)))
    hola = "administrador" if r == "admin" else "revendedor"
    t = [f"✦ {negrita('KIRA')} ✦   <i>{versal('panel de cuentas')}</i>",
         cita(f"🌐 <code>{ip_publica()}</code>",
              f"🕐 {time.strftime('%d/%m · %H:%M')}   ·   👑 {hola}"),
         tabla(pares, 22),
         "<i>Elegí una opción, o escribí un nombre para buscarlo.</i>"]
    filas = [[b("➕ Nueva cuenta", "n"), b(f"🎁 Demo {DEMO_MIN} min", "demo")],
             [b("📋 Cuentas", "L:t:0"), b(f"📡 Conectados · {online}", "on")]]
    if r == "admin":
        filas += [[b("🖥 Servidor", "vps"), b("🔔 Avisos", "av")],
                  [b("🤝 Revendedores", "rv")]]
    filas.append([b("🔄 Actualizar", "m")])
    return "\n".join(t), filas


FILTROS = {"t": "Todas", "p": "Por vencer", "o": "En línea", "v": "Vencidas"}


def pant_lista(tg, filtro, pag):
    todas = mias(tg, cuentas())
    if filtro == "p":
        sel = [x for x in todas.values() if x["estado"] == "pronto"]
    elif filtro == "o":
        sel = [x for x in todas.values() if x["conex"] > 0]
    elif filtro == "v":
        sel = [x for x in todas.values() if x["estado"] in ("vencida", "bloqueada")]
    else:
        filtro = "t"
        sel = list(todas.values())
    sel.sort(key=lambda x: (-x["conex"], x["nombre"]) if filtro == "o"
             else ((x["fin"] or 9e12), x["nombre"]) if filtro == "p" else x["nombre"])
    pags = max(1, (len(sel) + POR_PAGINA - 1) // POR_PAGINA)
    pag = max(0, min(pag, pags - 1))
    trozo = sel[pag * POR_PAGINA:(pag + 1) * POR_PAGINA]
    t = [titulo("📋", "CUENTAS", FILTROS[filtro])]
    if not sel:
        t.append(cita("<i>No hay ninguna cuenta en este filtro.</i>"))
    else:
        t.append(cita(f"<b>{len(sel)}</b> cuentas   ·   página <b>{pag + 1}</b> de {pags}",
                      "🟢 activa  🟡 por vencer  🔴 vencida  🔒 bloqueada  🎁 demo"))
        t.append("<i>Tocá una para abrirla.</i>")
    filas = []
    for x in trozo:
        lim = x["limite"] or "∞"
        filas.append([b(f"{ICONO[x['estado']]} {x['nombre']}  ·  {restante_corto(x)}  ·  📱{x['conex']}/{lim}",
                        f"U:{x['nombre']}")])
    if pags > 1:
        filas.append([b("◀️", f"L:{filtro}:{max(0, pag - 1)}"), b(f"{pag + 1} / {pags}", f"L:{filtro}:{pag}"),
                      b("▶️", f"L:{filtro}:{min(pags - 1, pag + 1)}")])
    filas.append([b(("✓ " if filtro == k else "") + v, f"L:{k}:0") for k, v in list(FILTROS.items())[:2]])
    filas.append([b(("✓ " if filtro == k else "") + v, f"L:{k}:0") for k, v in list(FILTROS.items())[2:]])
    filas.append([b("🏠 Inicio", "m")])
    return "\n".join(t), filas


def pant_cuenta(tg, x, arriba=""):
    c = leer_conf()
    r = rol(tg, c)
    n = x["nombre"]
    lim = x["limite"]
    ahora = time.time()
    t = []
    if arriba:
        # Lo que acaba de pasar va en su propio recuadro, arriba de la tarjeta
        t.append(arriba if arriba.startswith("<blockquote>") else cita(arriba))
    t.append(f"{ICONO[x['estado']]} {negrita(n)}   <i>{versal(x['estado'])}</i>")

    # Bloque 1: lo que se copia y cuánto le queda
    clave = f"<code>{esc(x['clave'])}</code>" if x["clave"] else "<i>sin guardar</i>"
    if x["fin"]:
        falta = x["fin"] - ahora
        # La barra se mide contra 30 días, que es la venta más común; la
        # demo, contra su hora de vida.
        total = DEMO_MIN * 60 if x["demo"] else 30 * 86400
        dias = cita(f"🔑 Clave   {clave}",
                    f"📅 Vence   {fecha_txt(x)}",
                    f"⏳ Quedan  <b>{restante(falta)}</b>",
                    f"<code>{tira(falta * 100 / total)}</code>")
    else:
        dias = cita(f"🔑 Clave   {clave}", "📅 Vence   <i>sin fecha</i>")
    t.append(dias)

    # Bloque 2: uso
    cupo = f"<b>{x['conex']}</b> de {lim}" if lim else f"<b>{x['conex']}</b> · sin tope"
    uso = [f"📱 Conexiones  {cupo}"]
    if lim:
        uso.append(f"<code>{tira(x['conex'] * 100 / lim)}</code>")
    uso.append(f"📊 Consumo  <b>{bytes_hum(x['consumo'])}</b> este mes")
    if r == "admin" and x["dueno"]:
        rv = c["revendedores"].get(x["dueno"], {})
        uso.append(f"🤝 Revendedor  {esc(rv.get('nombre') or x['dueno'])}")
    if x["estado"] == "bloqueada" and x["motivo"]:
        uso.append(f"🔒 Motivo  <i>{esc(x['motivo'])}</i>")
    t.append(cita(*uso))
    if r == "rev":
        t.append(f"💳 Tenés <b>{creditos(tg, c)}</b> créditos · 30 días cuestan <b>{30 * max(lim, 1)}</b>")

    bloq = x["estado"] == "bloqueada"
    filas = [
        [b("➕ 7 días", f"R:{n}:7"), b("➕ 30", f"R:{n}:30"), b("➕ 60", f"R:{n}:60"), b("➕ 90", f"R:{n}:90")],
        [b("🎲 Clave al azar", f"K:{n}"), b("✏️ Escribir clave", f"W:{n}")],
        [b("📱 −1 dispositivo", f"M:{n}:-1"), b("📱 +1 dispositivo", f"M:{n}:1")],
        [b(f"🔌 Cortar · {x['conex']}", f"C:{n}"),
         b("🔓 Desbloquear" if bloq else "🔒 Bloquear", f"B:{n}")],
        [b("📨 Ficha para el cliente", f"F:{n}")],
        [b("⬅️ Cuentas", "L:t:0"), b("🔄", f"U:{n}"), b("🗑 Borrar", f"D:{n}"), b("🏠", "m")],
    ]
    return "\n".join(t), filas


def ficha(x, extra=""):
    """El texto que se le pasa al cliente, TODO en un solo bloque <pre>.
    Telegram le pone a ese bloque un botón de copiar: un toque y se lleva la
    ficha entera para pegarla en WhatsApp. Por eso adentro va texto común,
    sin letras de fantasía: pegadas en otra app saldrían como cuadraditos.
    extra = un renglón más, en texto plano (la duración de una demo)."""
    ip = ip_publica()
    n = x["nombre"]
    clave = x["clave"] or "(la que te pasé)"
    ptos = puertos()
    raya = "━" * 22
    r = [raya, "   ✦ CUENTA SSH PREMIUM ✦", raya,
         f"🌐 IP      : {ip}",
         f"👤 Usuario : {n}",
         f"🔑 Clave   : {clave}"]
    if x["fin"]:
        r.append(f"📅 Vence   : {fecha_txt(x)}")
    lim = x["limite"]
    if lim:
        r.append(f"📱 Límite  : {lim} {'dispositivo' if lim == 1 else 'dispositivos'}")
    if extra:
        r.append(extra)
    if ptos:
        r += [raya, "🔌 PUERTOS"]
        ancho = max(len(s) for s, _ in ptos)
        r += [f"   {s.ljust(ancho)} : {' · '.join(map(str, ps))}" for s, ps in ptos]
    ws = dict(ptos).get("WebSocket")
    if ws:
        r += [raya, "📲 HTTP Injector", f"{ip}:{ws[0]}@{n}:{clave}"]
    sop = soporte()
    r.append(raya)
    if sop:
        r.append(f"💬 Soporte : {sop}")
    return (f"📨 {negrita('FICHA PARA EL CLIENTE')}\n"
            "<i>Tocá el recuadro para copiarla entera y pegala en el chat con tu cliente.</i>\n"
            "<pre>" + esc("\n".join(r)) + "</pre>")


def pant_conectados(tg):
    todas = mias(tg, cuentas())
    on = sorted((x for x in todas.values() if x["conex"] > 0), key=lambda x: (-x["conex"], x["nombre"]))
    total = sum(x["conex"] for x in on)
    t = [titulo("📡", "CONECTADOS", "ahora mismo")]
    if not on:
        t.append(cita("<i>No hay nadie conectado en este momento.</i>"))
    else:
        t.append(cita(f"🟢 <b>{len(on)}</b> cuentas   ·   🔌 <b>{total}</b> conexiones"))
        filas_t = []
        for x in on[:25]:
            lim = x["limite"]
            marca = " !" if lim and x["conex"] > lim else ""
            filas_t.append((x["nombre"], f"{x['conex']}/{lim or '∞'}{marca}"))
        t.append(tabla(filas_t, 26))
        if len(on) > 25:
            t.append(f"<i>… y {len(on) - 25} más</i>")
    filas = [[b(f"🔌 {x['nombre']}", f"U:{x['nombre']}") for x in on[i:i + 2]] for i in range(0, min(len(on), 10), 2)]
    filas.append([b("🔄 Actualizar", "on"), b("🏠 Inicio", "m")])
    return "\n".join(t), filas


def pant_vps():
    cpu = cpu_pct(0.4)
    rp, ru, rt = ram_pct()
    dp, du, dt = disco_pct()
    try:
        up = float(open("/proc/uptime").read().split()[0])
        carga = open("/proc/loadavg").read().split()[:3]
    except Exception:
        up, carga = 0, ["?"] * 3
    todas = cuentas()
    conex = sum(x["conex"] for x in todas.values())
    unidades = [("SSH", "ssh"), ("SSH", "sshd"), ("Dropbear", "dropbear"), ("SSL / TLS", "stunnel4"),
                ("WebSocket", "kira-ws"), ("BadVPN", "kira-badvpn"), ("Vigilante", "kira-vigilante"),
                ("Consumo", "kira-consumo")]
    try:
        out = subprocess.run(["systemctl", "is-active"] + [u for _, u in unidades],
                             capture_output=True, text=True, timeout=10).stdout.split()
    except Exception:
        out = []
    srv = {}
    for (nom, _), e in zip(unidades, out):
        srv[nom] = srv.get(nom, False) or e == "active"
    def fila(nom, pct):
        return f"{nom:<6}{tira(pct, 12)} {pct:>3}%"
    peor = max(cpu, rp, dp)
    salud = "🟢 todo en orden" if peor < 70 else ("🟡 exigido" if peor < 90 else "🔴 al límite")
    t = [titulo("🖥", "SERVIDOR", salud.split(" ", 1)[1]),
         "<pre>" + "\n".join([fila("CPU", cpu), fila("RAM", rp), fila("DISCO", dp)]) + "</pre>",
         cita(f"🧠 RAM  {bytes_hum(ru)} de {bytes_hum(rt)}",
              f"💾 Disco  {bytes_hum(du)} de {bytes_hum(dt)}",
              f"⏱ Encendido  <b>{int(up // 86400)}d {int(up % 86400 // 3600)}h</b>   ·   carga {' '.join(carga)}",
              f"👥 {len(todas)} cuentas   ·   🔌 {conex} conexiones"),
         f"⚙️ {versal('servicios')}",
         cita("   ".join(f"{'🟢' if on else '⚫'} {nom}" for nom, on in srv.items())
              or "<i>No pude leer el estado de los servicios.</i>")]
    return "\n".join(t), [[b("🔄 Actualizar", "vps"), b("🏠 Inicio", "m")]]


AVISOS_TXT = {
    "vence": ("⏳ Cuentas por vencer", "Te avisa cuando a una cuenta le quedan menos de 24 horas."),
    "multi": ("🚨 Cuentas compartidas", f"Si a una cuenta le cortan {MULTI_CORTES} conexiones en una hora por pasarse del límite, la están compartiendo."),
    "vps": ("🔥 Servidor exigido", "CPU, RAM o disco por encima del 90%."),
}


def pant_avisos():
    av = leer_conf()["avisos"]
    t = [titulo("🔔", "AVISOS", "automaticos"), "El bot te escribe solo cuando pasa algo de esto:"]
    for k, (tit, desc) in AVISOS_TXT.items():
        t.append(cita(f"{'✅' if av.get(k) else '⬜'} <b>{tit}</b>", f"<i>{desc}</i>"))
    t.append("<i>Tocá uno para prenderlo o apagarlo. Las demos vencidas se borran solas y te avisa.</i>")
    filas = [[b(f"{'✅' if av.get(k) else '⬜'} {tit}", f"av:{k}")] for k, (tit, _) in AVISOS_TXT.items()]
    filas.append([b("🏠 Inicio", "m")])
    return "\n".join(t), filas


def pant_revendedores():
    c = leer_conf()
    todas = cuentas()
    t = [titulo("🤝", "REVENDEDORES"),
         cita("💳 Cada cuenta les cuesta <b>días × dispositivos</b> en créditos.",
              "👁 Sólo ven y manejan las cuentas que crearon ellos.")]
    filas = []
    if not c["revendedores"]:
        t.append("<i>Todavía no hay ninguno. Tocá ➕ para sumar el primero.</i>")
    for rid, rv in sorted(c["revendedores"].items(), key=lambda kv: kv[1].get("nombre", "")):
        n = sum(1 for x in todas.values() if x["dueno"] == rid)
        filas.append([b(f"🤝 {rv.get('nombre') or rid}  ·  💳 {rv.get('creditos', 0)}  ·  👥 {n}", f"rv:{rid}")])
    filas.append([b("➕ Agregar revendedor", "ra")])
    filas.append([b("🏠 Inicio", "m")])
    return "\n".join(t), filas


def pant_revendedor(rid):
    c = leer_conf()
    rv = c["revendedores"].get(rid)
    if rv is None:
        raise Aviso("Ese revendedor ya no existe")
    mis = [x for x in cuentas().values() if x["dueno"] == rid]
    on = sum(1 for x in mis if x["conex"] > 0)
    t = [f"🤝 {negrita(rv.get('nombre') or rid)}   <i>{versal('revendedor')}</i>",
         cita(f"🆔 <code>{rid}</code>", f"📅 Desde {rv.get('alta', '—')}"),
         tabla([("CREDITOS", rv.get("creditos", 0)), ("CUENTAS", len(mis)), ("EN LINEA", on)], 22)]
    filas = [[b("➕100", f"rc:{rid}:100"), b("➕500", f"rc:{rid}:500"), b("➕1000", f"rc:{rid}:1000")],
             [b("➖100", f"rc:{rid}:-100"), b("🗑 Quitar", f"rq:{rid}")],
             [b("⬅️ Revendedores", "rv"), b("🏠", "m")]]
    return "\n".join(t), filas


# ============================================================ ASISTENTES ====
# Lo que se escribe a mano (nombre, clave, ID) llega como mensaje común. Si
# hay un asistente abierto en ese chat, el mensaje va para él; si no, se toma
# como búsqueda de una cuenta.
CHARLA = {}

PASOS = ["usuario", "clave", "dias", "limite", "ok"]


def pintar_nueva(chat, tg, st, aviso=""):
    d = st["d"]
    i = PASOS.index(st["paso"])
    progreso = "●" * (i + 1) + "○" * (len(PASOS) - i - 1)

    def v(clave, nombre, txt):
        if clave in d:
            return f"✅ {nombre}  <b>{txt}</b>"
        if PASOS[i] == clave:
            return f"👉 <b>{nombre}</b>"
        return f"▫️ <i>{nombre}</i>"
    lim = d.get("limite", "")
    t = [f"{titulo('➕', 'NUEVA CUENTA')}   <code>{progreso}</code>",
         cita(v("usuario", "Usuario", d.get("usuario", "")),
              v("clave", "Clave", "<code>" + esc(d.get("clave", "")) + "</code>"),
              v("dias", "Días", f"{d.get('dias', '')} días"),
              v("limite", "Límite", f"{lim} {'dispositivo' if lim == 1 else 'dispositivos'}"))]
    paso = st["paso"]
    atras_cancelar = [b("⬅️ Atrás", "n:b"), b("✖ Cancelar", "x")]
    if paso == "usuario":
        t += ["✏️ <b>Escribí el nombre de usuario</b>",
              "<i>Minúsculas, números y guion. Máximo 20.</i>"]
        filas = [[b("✖ Cancelar", "x")]]
    elif paso == "clave":
        t += ["✏️ <b>Escribí la contraseña</b>", "<i>o tocá 🎲 y te genero una fácil de dictar.</i>"]
        filas = [[b("🎲 Generar una", "n:c")], atras_cancelar]
    elif paso == "dias":
        t += ["📅 <b>¿Cuántos días dura?</b>", "<i>Tocá uno o escribí otro número.</i>"]
        filas = [[b(f"{n} días", f"n:d:{n}") for n in (7, 15, 30)],
                 [b(f"{n} días", f"n:d:{n}") for n in (60, 90, 180)], atras_cancelar]
    elif paso == "limite":
        t += ["📱 <b>¿Cuántos dispositivos a la vez?</b>"]
        filas = [[b(f"📱 {n}", f"n:l:{n}") for n in (1, 2, 3, 4, 5)], atras_cancelar]
    else:
        t.append("✨ <b>Todo listo. ¿Creo la cuenta?</b>")
        if rol(tg) == "rev":
            costo = d["dias"] * d["limite"]
            t.append(cita(f"💳 Cuesta <b>{costo}</b> créditos · tenés <b>{creditos(tg)}</b>"))
        filas = [[b("✅ Crear cuenta", "n:ok")], atras_cancelar]
    if aviso:
        t.append(cita(f"⚠️ {aviso}"))
    editar(chat, st.get("msg"), "\n".join(t), filas)


def nueva_texto(chat, tg, st, txt, quien):
    d = st["d"]
    paso = st["paso"]
    if paso == "usuario":
        u = txt.strip().lower()
        if not RE_USUARIO.match(u):
            return pintar_nueva(chat, tg, st, "Sólo minúsculas, números, guion y guion bajo (máx. 20, sin empezar con número)")
        try:
            pwd.getpwnam(u)
            return pintar_nueva(chat, tg, st, f"<b>{u}</b> ya existe. Probá con otro.")
        except KeyError:
            pass
        d["usuario"] = u
        st["paso"] = "clave"
    elif paso == "clave":
        e = error_clave(txt.strip())
        if e:
            return pintar_nueva(chat, tg, st, e)
        d["clave"] = txt.strip()
        st["paso"] = "dias"
    elif paso == "dias":
        if not txt.strip().isdigit() or not 1 <= int(txt) <= MAX_DIAS:
            return pintar_nueva(chat, tg, st, f"Escribí un número de 1 a {MAX_DIAS}")
        d["dias"] = int(txt)
        st["paso"] = "limite"
    elif paso == "limite":
        if not txt.strip().isdigit() or not 1 <= int(txt) <= MAX_LIMITE:
            return pintar_nueva(chat, tg, st, f"Escribí un número de 1 a {MAX_LIMITE}")
        d["limite"] = int(txt)
        st["paso"] = "ok"
    else:
        return pintar_nueva(chat, tg, st, "Tocá ✅ Crear cuenta para terminar")
    pintar_nueva(chat, tg, st)


def nueva_confirmar(chat, tg, st, quien):
    d = st["d"]
    r = rol(tg)
    costo = d["dias"] * d["limite"] if r == "rev" else 0
    if costo and not cobrar(tg, costo):
        return pintar_nueva(chat, tg, st, f"No te alcanzan los créditos: necesitás {costo} y tenés {creditos(tg)}")
    vence = (datetime.date.today() + datetime.timedelta(days=d["dias"])).isoformat()
    err = crear_cuenta(d["usuario"], d["clave"], vence, d["limite"], str(tg) if r == "rev" else "")
    if err:
        if costo:
            devolver(tg, costo)
        return pintar_nueva(chat, tg, st, err)
    CHARLA.pop(chat, None)
    registro(f"{quien} creo {d['usuario']} ({d['dias']} dias, {d['limite']} disp.)"
             + (f" -{costo} creditos" if costo else ""))
    x = cuentas()[d["usuario"]]
    arriba = "✅ <b>Cuenta creada.</b> Abajo te mandé la ficha para reenviarle al cliente."
    if costo:
        arriba += f"\n💳 Se descontaron {costo} créditos · te quedan <b>{creditos(tg)}</b>"
    t, f = pant_cuenta(tg, x, arriba)
    editar(chat, st.get("msg"), t, f)
    enviar(chat, ficha(x))


def hacer_demo(chat, tg, msg, quien):
    r = rol(tg)
    todas = cuentas()
    if r == "rev":
        vivas = sum(1 for x in todas.values() if x["demo"] and x["dueno"] == str(tg))
        if vivas >= DEMOS_POR_REV:
            raise Aviso(f"Ya tenés {vivas} demos activas: esperá a que venza alguna")
    nombre = ""
    for _ in range(20):
        cand = f"demo{secrets.randbelow(9000) + 1000}"
        if cand not in todas:
            try:
                pwd.getpwnam(cand)
            except KeyError:
                nombre = cand
                break
    if not nombre:
        raise Aviso("No encontré un nombre libre para la demo")
    clave = clave_azar()
    fin = int(time.time()) + DEMO_MIN * 60
    # Techo de seguridad: aunque el bot se caiga, el sistema la da de baja mañana
    vence = (datetime.date.today() + datetime.timedelta(days=1)).isoformat()
    err = crear_cuenta(nombre, clave, vence, 1, str(tg) if r == "rev" else "", fin)
    if err:
        raise Aviso(err)
    registro(f"{quien} creo la demo {nombre}")
    x = cuentas()[nombre]
    t, f = pant_cuenta(tg, x, f"🎁 <b>Demo creada.</b> Se borra sola en {DEMO_MIN} minutos.")
    editar(chat, msg, t, f)
    enviar(chat, ficha(x, f"⏱ Prueba  : dura {DEMO_MIN} minutos"))
    return "🎁 Demo lista"


def rev_texto(chat, tg, st, txt, quien):
    if st["paso"] == "id":
        if not re.match(r"^-?\d{4,15}$", txt.strip()):
            return pintar_rev(chat, st, "Eso no parece un ID de Telegram: son sólo números")
        st["d"]["id"] = txt.strip()
        if int(txt) in leer_conf()["admins"]:
            return pintar_rev(chat, st, "Ese ID ya es administrador")
        st["paso"] = "nombre"
        return pintar_rev(chat, st)
    nombre = txt.strip()[:30]
    if not nombre:
        return pintar_rev(chat, st, "Escribí un nombre")
    rid = st["d"]["id"]

    def f(c):
        c["revendedores"].setdefault(rid, {"creditos": 0, "alta": time.strftime("%d/%m/%Y")})
        c["revendedores"][rid]["nombre"] = nombre
    cambiar_conf(f)
    CHARLA.pop(chat, None)
    registro(f"{quien} agrego al revendedor {nombre} ({rid})")
    t, fl = pant_revendedor(rid)
    editar(chat, st.get("msg"), cita("✅ <b>Revendedor agregado.</b> Cargale créditos para que empiece.") + "\n" + t, fl)
    enviar(int(rid), "🎉 <b>¡Te habilitaron como revendedor!</b>\n\nMandá /start para abrir tu panel.")


def pintar_rev(chat, st, aviso=""):
    if st["paso"] == "id":
        t = [f"{titulo('🤝', 'NUEVO REVENDEDOR')}   <code>●○</code>",
             cita("👉 <b>ID de Telegram</b>", "▫️ <i>Nombre</i>"),
             "✏️ <b>Escribí su ID de Telegram</b>",
             "<i>Que le mande /start a este bot: el bot le contesta con su ID.</i>"]
    else:
        t = [f"{titulo('🤝', 'NUEVO REVENDEDOR')}   <code>●●</code>",
             cita(f"✅ ID  <code>{st['d']['id']}</code>", "👉 <b>Nombre</b>"),
             "✏️ <b>¿Cómo se llama?</b>", "<i>Es sólo para que lo reconozcas en la lista.</i>"]
    if aviso:
        t.append(cita(f"⚠️ {aviso}"))
    editar(chat, st.get("msg"), "\n".join(t), [[b("✖ Cancelar", "x")]])


def cambiar_clave(chat, mid, tg, x, clave, quien):
    ok, err = correr(["chpasswd"], f"{x['nombre']}:{clave}\n")
    if not ok:
        raise Aviso(f"No se pudo cambiar: {err}")
    poner_par("claves", x["nombre"], clave, 0o600)
    # Las conexiones abiertas siguen vivas con la clave vieja y ocupan el
    # cupo: al reconectar con la nueva parecería que no anda. Se cortan.
    n = cortar(x["uid"])
    registro(f"{quien} cambio la clave de {x['nombre']}")
    t, f = pant_cuenta(tg, obtener(tg, x["nombre"]),
                       cita(f"🔑 Clave nueva  <code>{esc(clave)}</code>",
                            f"🔌 Se cortaron {n} conexiones con la clave vieja" if n else None))
    editar(chat, mid, t, f)


def pintar_clave(chat, st, aviso=""):
    n = st["nombre"]
    t = [titulo("✏️", "CLAVE NUEVA", n),
         cita("✏️ <b>Escribí la contraseña nueva</b>",
              "<i>Mínimo 4 caracteres, sin espacios ni dos puntos.</i>",
              "<i>Tu mensaje se borra del chat apenas lo leo.</i>"),
         "🔌 <i>Las conexiones abiertas se cortan para que entre con la nueva.</i>"]
    if aviso:
        t.append(cita(f"⚠️ {aviso}"))
    editar(chat, st.get("msg"), "\n".join(t),
           [[b("🎲 Mejor una al azar", f"K:{n}")], [b("✖ Cancelar", f"U:{n}")]])


def clave_texto(chat, tg, st, txt, quien):
    clave = txt.strip()
    e = error_clave(clave)
    if e:
        return pintar_clave(chat, st, e)
    try:
        cambiar_clave(chat, st.get("msg"), tg, obtener(tg, st["nombre"]), clave, quien)
        CHARLA.pop(chat, None)
    except Aviso as a:
        pintar_clave(chat, st, str(a))


def buscar(chat, tg, txt):
    q = txt.strip().lower()
    todas = mias(tg, cuentas())
    if q in todas:
        t, f = pant_cuenta(tg, todas[q])
        return enviar(chat, t, f)
    hay = sorted(n for n in todas if q and q in n)
    if not hay:
        return enviar(chat, f"🔍 No encontré ninguna cuenta con <b>{esc(txt[:30])}</b>.",
                      [[b("📋 Ver todas", "L:t:0"), b("🏠 Inicio", "m")]])
    filas = [[b(f"{ICONO[todas[n]['estado']]} {n}", f"U:{n}")] for n in hay[:10]]
    filas.append([b("🏠 Inicio", "m")])
    enviar(chat, f"🔍 <b>{len(hay)}</b> cuentas con <b>{esc(txt[:30])}</b>:", filas)


# ============================================================== BOTONES =====
def despachar(chat, mid, tg, r, data, quien):
    p = data.split(":")
    k = p[0]
    # Tocar cualquier otro botón abandona el asistente que hubiera abierto.
    # Si no, lo próximo que escribas (una búsqueda, por ejemplo) se tomaría
    # como la clave nueva de la cuenta que dejaste a medias.
    if k not in ("n", "W", "ra"):
        CHARLA.pop(chat, None)

    if k == "m":
        CHARLA.pop(chat, None)
        t, f = pant_inicio(tg)
        editar(chat, mid, t, f)
    elif k == "x":
        CHARLA.pop(chat, None)
        t, f = pant_inicio(tg)
        editar(chat, mid, t, f)
        return "Cancelado"
    elif k == "L":
        t, f = pant_lista(tg, p[1], int(p[2]))
        editar(chat, mid, t, f)
    elif k == "U":
        t, f = pant_cuenta(tg, obtener(tg, p[1]))
        editar(chat, mid, t, f)
    elif k == "on":
        t, f = pant_conectados(tg)
        editar(chat, mid, t, f)

    # ---- acciones sobre una cuenta
    elif k == "R":
        x = obtener(tg, p[1])
        dias = int(p[2])
        costo = dias * max(x["limite"], 1) if r == "rev" else 0
        if costo and not cobrar(tg, costo):
            raise Aviso(f"No te alcanza: cuesta {costo} y tenés {creditos(tg)} créditos")
        try:
            renovar(x, dias)
        except Aviso:
            if costo:
                devolver(tg, costo)
            raise
        registro(f"{quien} renovo {x['nombre']} {dias} dias" + (f" -{costo} creditos" if costo else ""))
        t, f = pant_cuenta(tg, obtener(tg, p[1]), f"✅ Renovada <b>{dias} días</b>."
                           + (f" Se descontaron {costo} créditos." if costo else ""))
        editar(chat, mid, t, f)
        return f"✔ +{dias} días"
    elif k == "K":
        CHARLA.pop(chat, None)
        cambiar_clave(chat, mid, tg, obtener(tg, p[1]), clave_azar(), quien)
        return "🔑 Clave cambiada"
    elif k == "W":
        x = obtener(tg, p[1])
        st = {"t": "clave", "nombre": x["nombre"], "msg": mid}
        CHARLA[chat] = st
        pintar_clave(chat, st)
    elif k == "M":
        x = obtener(tg, p[1])
        actual = x["limite"] or 1
        nuevo = actual + int(p[2])
        if nuevo < 1:
            raise Aviso("El mínimo es 1 dispositivo")
        if nuevo > MAX_LIMITE:
            raise Aviso(f"El máximo es {MAX_LIMITE}")
        costo = 0
        if r == "rev" and nuevo > actual:
            # Un dispositivo más vale lo que le queda de vida a la cuenta
            costo = max(1, -(-int(max(0, x["fin"] - time.time())) // 86400))
            if not cobrar(tg, costo):
                raise Aviso(f"Sumar un dispositivo cuesta {costo} créditos y tenés {creditos(tg)}")
        poner_par("limites", x["nombre"], str(nuevo))
        registro(f"{quien} puso {x['nombre']} en {nuevo} disp.")
        t, f = pant_cuenta(tg, obtener(tg, p[1]))
        editar(chat, mid, t, f)
        return f"📱 Límite: {nuevo}" + (f" · -{costo} créditos" if costo else "")
    elif k == "C":
        x = obtener(tg, p[1])
        n = cortar(x["uid"])
        registro(f"{quien} corto {n} conexiones de {x['nombre']}")
        t, f = pant_cuenta(tg, obtener(tg, p[1]))
        editar(chat, mid, t, f)
        return f"🔌 Se cortaron {n} conexiones"
    elif k == "B":
        x = obtener(tg, p[1])
        if x["estado"] == "bloqueada":
            desbloquear(x)
            registro(f"{quien} desbloqueo {x['nombre']}")
            aviso = "🔓 Desbloqueada"
        else:
            n = bloquear(x, f"desde el bot ({quien})"[:40])
            registro(f"{quien} bloqueo {x['nombre']}")
            aviso = "🔒 Bloqueada" + (f" · {n} conexiones cortadas" if n else "")
        t, f = pant_cuenta(tg, obtener(tg, p[1]))
        editar(chat, mid, t, f)
        return aviso
    elif k == "D":
        x = obtener(tg, p[1])
        t = [f"🗑 <b>¿Borrar {x['nombre']}?</b>", LINEA,
             "Se borra la cuenta y se le cortan las conexiones.",
             "<b>No se puede deshacer.</b>"]
        if r == "rev":
            t.append("<i>Los créditos que usaste no se devuelven.</i>")
        editar(chat, mid, "\n".join(t), [[b("🗑 Sí, borrar", f"DD:{x['nombre']}")],
                                         [b("✖ No", f"U:{x['nombre']}")]])
    elif k == "DD":
        x = obtener(tg, p[1])
        borrar_cuenta(x["nombre"], x["uid"])
        registro(f"{quien} borro {x['nombre']}")
        t, f = pant_lista(tg, "t", 0)
        editar(chat, mid, f"🗑 <b>{x['nombre']}</b> borrada.\n\n" + t, f)
        return "🗑 Borrada"
    elif k == "F":
        enviar(chat, ficha(obtener(tg, p[1])))
        return "📨 Ficha enviada: reenviásela al cliente"

    # ---- crear
    elif k == "n":
        sub = p[1] if len(p) > 1 else ""
        st = CHARLA.get(chat)
        if not sub or st is None or st.get("t") != "nueva":
            st = {"t": "nueva", "paso": "usuario", "d": {}, "msg": mid}
            CHARLA[chat] = st
            pintar_nueva(chat, tg, st)
            return None
        st["msg"] = mid
        d = st["d"]
        if sub == "b":
            i = PASOS.index(st["paso"])
            if i > 0:
                st["paso"] = PASOS[i - 1]
                d.pop(st["paso"], None)
        elif sub == "c" and st["paso"] == "clave":
            d["clave"] = clave_azar()
            st["paso"] = "dias"
        elif sub == "d" and st["paso"] == "dias":
            d["dias"] = int(p[2])
            st["paso"] = "limite"
        elif sub == "l" and st["paso"] == "limite":
            d["limite"] = int(p[2])
            st["paso"] = "ok"
        elif sub == "ok" and st["paso"] == "ok":
            return nueva_confirmar(chat, tg, st, quien)
        pintar_nueva(chat, tg, st)
    elif k == "demo":
        CHARLA.pop(chat, None)
        return hacer_demo(chat, tg, mid, quien)

    # ---- sólo admin
    elif r != "admin":
        raise Aviso("Eso es sólo para el administrador")
    elif k == "vps":
        t, f = pant_vps()
        editar(chat, mid, t, f)
    elif k == "av":
        if len(p) > 1 and p[1] in DEF_AVISOS:
            cambiar_conf(lambda c: c["avisos"].__setitem__(p[1], not c["avisos"].get(p[1])))
        t, f = pant_avisos()
        editar(chat, mid, t, f)
    elif k == "rv":
        t, f = pant_revendedor(p[1]) if len(p) > 1 else pant_revendedores()
        editar(chat, mid, t, f)
    elif k == "rc":
        rid, n = p[1], int(p[2])

        def f(c):
            rv = c["revendedores"].get(rid)
            if rv is None:
                raise Aviso("Ese revendedor ya no existe")
            rv["creditos"] = max(0, int(rv.get("creditos", 0)) + n)
            return rv["creditos"], rv.get("nombre") or rid
        total, nom = cambiar_conf(f)
        registro(f"{quien} {'cargo' if n > 0 else 'quito'} {abs(n)} creditos a {nom}")
        t, fl = pant_revendedor(rid)
        editar(chat, mid, t, fl)
        if n > 0:
            enviar(int(rid), f"💳 Te cargaron <b>{n}</b> créditos. Ahora tenés <b>{total}</b>.")
        return f"💳 Ahora tiene {total}"
    elif k == "rq":
        rv = leer_conf()["revendedores"].get(p[1], {})
        editar(chat, mid, f"🗑 <b>¿Quitar a {esc(rv.get('nombre') or p[1])}?</b>\n{LINEA}\n"
                          "Deja de poder usar el bot. Sus cuentas siguen funcionando y pasan a ser tuyas.",
               [[b("🗑 Sí, quitarlo", f"rqq:{p[1]}")], [b("✖ No", f"rv:{p[1]}")]])
    elif k == "rqq":
        rid = p[1]
        nom = cambiar_conf(lambda c: (c["revendedores"].pop(rid, None) or {}).get("nombre") or rid)
        for n, x in cuentas().items():
            if x["dueno"] == rid:
                poner_par("duenos", n, None, crear=False)
        registro(f"{quien} quito al revendedor {nom}")
        t, f = pant_revendedores()
        editar(chat, mid, t, f)
        return "Revendedor quitado"
    elif k == "ra":
        st = {"t": "rev", "paso": "id", "d": {}, "msg": mid}
        CHARLA[chat] = st
        pintar_rev(chat, st)
    return None


def manejar_boton(q):
    tg = q["from"]["id"]
    msg = q.get("message") or {}
    chat = msg.get("chat", {}).get("id")
    if not chat or rol(tg) is None:
        api("answerCallbackQuery", callback_query_id=q["id"], text="⛔ No autorizado")
        return
    try:
        aviso = despachar(chat, msg.get("message_id"), tg, rol(tg), q.get("data", ""), nombre_de(q["from"]))
    except Aviso as e:
        aviso = f"⚠️ {e}"
    except Exception as e:
        registro(f"error en boton {q.get('data')}: {e}")
        aviso = "⚠️ Algo falló. Probá de nuevo."
    # Los errores van en ventanita que hay que cerrar; lo demás, en el cartel
    # que se va solo.
    api("answerCallbackQuery", callback_query_id=q["id"], text=aviso[:190] if aviso else None,
        show_alert=True if aviso and aviso.startswith("⚠️") else None)


# ============================================================== MENSAJES ====
def manejar_mensaje(m):
    if m.get("chat", {}).get("type") != "private":
        return
    chat = m["chat"]["id"]
    tg = m["from"]["id"]
    texto = (m.get("text") or "").strip()
    r = rol(tg)
    if r is None:
        enviar(chat, "⛔ <b>No estás autorizado.</b>\n\n"
                     f"Tu ID de Telegram es <code>{tg}</code>.\n"
                     "Pasáselo al dueño del servidor para que te habilite.")
        return
    quien = nombre_de(m["from"])
    if texto.startswith("/"):
        cmd = texto.split()[0].split("@")[0].lower()
        CHARLA.pop(chat, None)
        if cmd == "/cuentas":
            t, f = pant_lista(tg, "t", 0)
        elif cmd == "/conectados":
            t, f = pant_conectados(tg)
        elif cmd == "/servidor" and r == "admin":
            t, f = pant_vps()
        elif cmd == "/id":
            t, f = f"🆔 Tu ID de Telegram es <code>{tg}</code>", [[b("🏠 Inicio", "m")]]
        elif cmd == "/nueva":
            st = {"t": "nueva", "paso": "usuario", "d": {}, "msg": None}
            CHARLA[chat] = st
            r2 = enviar(chat, "👤 …")
            st["msg"] = r2.get("result", {}).get("message_id")
            pintar_nueva(chat, tg, st)
            return
        elif cmd == "/demo":
            try:
                hacer_demo(chat, tg, None, quien)
            except Aviso as e:
                enviar(chat, f"⚠️ {e}", [[b("🏠 Inicio", "m")]])
            return
        else:
            t, f = pant_inicio(tg)
        enviar(chat, t, f)
        return

    st = CHARLA.get(chat)
    if st:
        # Se borra lo que escribió: el asistente queda prolijo, y una clave
        # no queda dando vueltas en el chat.
        api("deleteMessage", chat_id=chat, message_id=m["message_id"])
        try:
            if st["t"] == "nueva":
                nueva_texto(chat, tg, st, texto, quien)
            elif st["t"] == "rev":
                rev_texto(chat, tg, st, texto, quien)
            elif st["t"] == "clave":
                clave_texto(chat, tg, st, texto, quien)
        except Exception as e:
            registro(f"error en asistente: {e}")
            enviar(chat, "⚠️ Algo falló. Probá de nuevo.", [[b("🏠 Inicio", "m")]])
        return
    if texto:
        buscar(chat, tg, texto)


# ================================================================ AVISOS ====
def avisar(c, dueno, texto, filas=None, admins=True):
    """Al revendedor dueño de la cuenta (si tiene) y, si corresponde, a los
    admins. Si la cuenta no tiene dueño, va siempre a los admins."""
    para = set()
    if dueno and dueno in c["revendedores"]:
        para.add(int(dueno))
    if admins or not para:
        para.update(c["admins"])
    for p in para:
        enviar(p, texto, filas)


def hilo_avisos():
    est = _cargar(ESTADO)
    vence_av = est.get("vence", {})
    hist, multi_av = {}, {}
    vps_av = 0.0
    desde = int(time.time())
    cpu_pct()                    # primera muestra: la siguiente ya mide un intervalo
    while True:
        time.sleep(60)
        try:
            c = leer_conf()
            av = c["avisos"]
            ahora = time.time()

            # 1. Demos vencidas: se borran acá. El panel también las borra,
            #    pero sólo cuando alguien lo abre.
            cli = clientes()
            due = leer_pares("duenos")
            for n, v in leer_pares("demos").items():
                v = v.split()[0] if v else ""
                if v.isdigit() and int(v) <= ahora and n in cli:
                    try:
                        borrar_cuenta(n, cli[n])
                        registro(f"la demo {n} termino y se borro")
                        avisar(c, due.get(n, ""), f"⌛ La demo <b>{n}</b> terminó y se borró sola.", admins=False)
                    except Exception as e:
                        registro(f"no se pudo borrar la demo {n}: {e}")

            todas = cuentas()

            # 2. Cuentas que vencen en menos de 24 horas, una vez por día
            if av.get("vence"):
                hoy = time.strftime("%Y-%m-%d")
                for n, x in todas.items():
                    if x["demo"] or not x["fin"] or x["estado"] in ("bloqueada", "sin clave"):
                        continue
                    falta = x["fin"] - ahora
                    if 0 < falta <= 86400 and vence_av.get(n) != hoy:
                        vence_av[n] = hoy
                        avisar(c, x["dueno"], f"⏳ <b>{n}</b> vence en <b>{restante(falta)}</b>.\n"
                                              "¿Lo renovás?",
                               [[b("➕30 días", f"R:{n}:30"), b("👤 Ver", f"U:{n}")]], admins=False)
                vence_av = {k: v for k, v in vence_av.items() if k in todas}
                guardar_json(ESTADO, {"vence": vence_av})

            # 3. Cuentas compartidas: se leen los cortes que hacen kira-limite
            #    y el vigilante. Uno suelto es un celular que reconectó; muchos
            #    en una hora son dos o más personas peleándose el cupo.
            out = ""
            if av.get("multi"):
                try:
                    out = subprocess.run(["journalctl", "-t", "kira-limite", "-t", "kira-vigilante",
                                          f"--since=@{desde}", "-o", "cat", "--no-pager"],
                                         capture_output=True, text=True, timeout=20).stdout
                except Exception:
                    out = ""
            desde = int(ahora)
            for l in out.splitlines():
                m = re.match(r"^(\S+) (?:entró con|tenia) ", l)
                if m and "cort" in l:
                    hist.setdefault(m.group(1), []).append(ahora)
            for n in list(hist):
                hist[n] = [t for t in hist[n] if ahora - t < 3600]
                if not hist[n]:
                    del hist[n]
                    continue
                if len(hist[n]) >= MULTI_CORTES and ahora - multi_av.get(n, 0) > 3600 and n in todas:
                    multi_av[n] = ahora
                    x = todas[n]
                    avisar(c, x["dueno"],
                           f"🚨 <b>{n}</b> parece estar <b>compartiendo la cuenta</b>.\n"
                           f"Se le cortaron {len(hist[n])} conexiones en la última hora por pasarse "
                           f"de su límite ({x['limite'] or '∞'}).",
                           [[b("🔒 Bloquear", f"B:{n}"), b("👤 Ver", f"U:{n}")]])

            # 4. Servidor exigido, como mucho un aviso por hora
            cpu = cpu_pct()
            if av.get("vps"):
                rp = ram_pct()[0]
                dp = disco_pct()[0]
                if max(cpu, rp, dp) >= 90 and ahora - vps_av > 3600:
                    vps_av = ahora
                    t = ["🔥 <b>El servidor está exigido</b>", LINEA,
                         f"⚙️ CPU    {barra(cpu)}", f"🧠 RAM    {barra(rp)}", f"💾 Disco  {barra(dp)}"]
                    for a in c["admins"]:
                        enviar(a, "\n".join(t), [[b("🖥 Ver servidor", "vps")]])
        except Exception as e:
            registro(f"error en avisos: {e}")


# ============================================================== MIGRACIÓN ===
# El bot viejo (bash) guardaba todo en /etc/kira. Se trae una sola vez: el
# token y los admins, y las claves y límites de las cuentas que creó.
def migrar_viejo():
    viejo = "/etc/kira/bot/bot.conf"
    if not os.path.exists(CONF) and os.path.exists(viejo):
        txt = open(viejo).read()
        tok = re.search(r'^TOKEN="?([^"\n]*)', txt, re.M)
        adm = re.search(r'^ADMIN_IDS="?([^"\n]*)', txt, re.M)
        guardar_json(CONF, _completar({
            "token": tok.group(1).strip() if tok else "",
            "admins": [int(x) for x in re.findall(r"-?\d+", adm.group(1))] if adm else []}))
        registro("se importo la configuracion del bot viejo")
    try:
        cli = clientes()
    except Exception:
        return
    clv = leer_pares("claves")
    lim = leer_pares("limites")
    for n in cli:
        try:
            if n not in clv and os.path.exists(f"/etc/kira/pass/{n}"):
                v = open(f"/etc/kira/pass/{n}").read().strip()
                if v and not error_clave(v):
                    poner_par("claves", n, v, 0o600)
            if n not in lim and os.path.exists(f"/etc/kira/limits/{n}"):
                v = open(f"/etc/kira/limits/{n}").read().strip()
                if v.isdigit() and int(v) > 0:
                    poner_par("limites", n, v)
        except Exception:
            pass


# ================================================================== MAIN =====
def main():
    global TOKEN
    if os.geteuid() != 0:
        print("El bot tiene que correr como root: crea y borra cuentas.")
        sys.exit(1)
    migrar_viejo()
    c = leer_conf()
    TOKEN = c["token"].strip()
    if not TOKEN:
        print("Falta el token del bot: configuralo desde el panel, módulo 11.")
        time.sleep(30)
        sys.exit(1)
    me = api("getMe")
    if not me.get("ok"):
        print(f"Telegram rechazó el token: {me.get('description')}")
        registro("Telegram rechazo el token")
        time.sleep(30)
        sys.exit(1)
    usuario = me["result"].get("username", "")
    cambiar_conf(lambda x: x.update(bot_usuario=usuario))
    # Si quedó corriendo el bot viejo con el mismo token, Telegram le da los
    # mensajes a uno o al otro al azar. Se lo apaga.
    subprocess.run(["pkill", "-f", "/etc/kira/bot/telegram_bot.sh"], capture_output=True)
    api("deleteWebhook")
    api("setMyCommands", commands=[
        {"command": "start", "description": "Abrir el panel"},
        {"command": "nueva", "description": "Crear una cuenta"},
        {"command": "demo", "description": f"Demo de {DEMO_MIN} minutos"},
        {"command": "cuentas", "description": "Ver las cuentas"},
        {"command": "conectados", "description": "Quién está conectado"},
        {"command": "id", "description": "Mi ID de Telegram"},
    ])
    threading.Thread(target=hilo_avisos, daemon=True).start()
    registro(f"bot encendido (@{usuario})")
    print(f"KIRA bot en línea: @{usuario}")

    offset = 0
    while True:
        r = api("getUpdates", offset=offset, timeout=50, allowed_updates=["message", "callback_query"])
        if not r.get("ok"):
            if r.get("error_code") == 401:
                registro("Telegram rechazo el token")
                sys.exit(1)
            time.sleep(5)
            continue
        for u in r.get("result", []):
            offset = u["update_id"] + 1
            try:
                if "callback_query" in u:
                    manejar_boton(u["callback_query"])
                elif "message" in u:
                    manejar_mensaje(u["message"])
            except Exception as e:
                registro(f"error: {e}")


if __name__ == "__main__":
    main()
