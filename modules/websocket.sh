#!/bin/bash

CONFIG="/etc/kira/domain"

# ===== USAR DOMINIO =====
if [ ! -f "$CONFIG" ]; then
    read -p "🌐 Ingresa tu dominio: " DOMAIN
    mkdir -p /etc/kira
    echo "$DOMAIN" > "$CONFIG"
else
    DOMAIN=$(cat $CONFIG)
fi

echo -e "\nUsando dominio: $DOMAIN\n"

apt install nodejs npm -y >/dev/null 2>&1
npm install -g ws

cat > /usr/local/bin/ws.js <<'EOF'
const WebSocket = require('ws');
const net = require('net');

const wss = new WebSocket.Server({ port: 8888 });

wss.on('connection', function connection(ws) {
    const socket = net.connect(22, '127.0.0.1');

    ws.on('message', function incoming(message) {
        socket.write(message);
    });

    socket.on('data', function(data) {
        ws.send(data);
    });

    socket.on('close', function() {
        ws.close();
    });
});
EOF

cat > /etc/systemd/system/websocket.service <<EOF
[Unit]
Description=KIRA WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/node /usr/local/bin/ws.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable websocket
systemctl restart websocket

echo -e "✔ WebSocket activo"
echo -e "🌐 Dominio configurado: $DOMAIN"