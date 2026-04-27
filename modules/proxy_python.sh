#!/bin/bash

PORT=80
CONFIG="/etc/kira/domain"

# ===== PEDIR DOMINIO SI NO EXISTE =====
if [ ! -f "$CONFIG" ]; then
    read -p "🌐 Ingresa tu dominio (ej: kira.tudominio.com): " DOMAIN
    mkdir -p /etc/kira
    echo "$DOMAIN" > "$CONFIG"
else
    DOMAIN=$(cat $CONFIG)
fi

echo -e "\nUsando dominio: $DOMAIN\n"

# ===== INSTALAR =====
apt update -y >/dev/null 2>&1
apt install python3 -y >/dev/null 2>&1

cat > /usr/local/bin/proxy.py <<'EOF'
import socket
import threading

def handle(client):
    try:
        data = client.recv(4096)
        if b"CONNECT" in data or b"GET" in data:
            client.send(b"HTTP/1.1 200 OK\r\n\r\n")
        while True:
            client.recv(4096)
    except:
        pass
    client.close()

def start():
    s = socket.socket()
    s.bind(("0.0.0.0", 80))
    s.listen(100)
    while True:
        c, addr = s.accept()
        threading.Thread(target=handle, args=(c,)).start()

start()
EOF

# ===== SERVICE =====
cat > /etc/systemd/system/proxy-python.service <<EOF
[Unit]
Description=KIRA Proxy Python
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/proxy.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable proxy-python
systemctl restart proxy-python

echo -e "✔ Proxy activo"
echo -e "🌐 Conectar con: $DOMAIN:$PORT"