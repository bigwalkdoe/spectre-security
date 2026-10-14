#!/bin/bash
set -euo pipefail

CLIENT_NAME="${1:-client1}"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_SUBNET="10.0.0.0/24"
SERVER_IP="2400:adc1:40a:fd00::1"
SERVER_PORT="51820"
CLIENT_IP="${2:-10.0.0.2}"

# Generate client keys
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)
SERVER_PUB=$(sudo cat $WG_DIR/server.key | wg pubkey)

# Add client as peer to server
sudo bash -c "cat >> $WG_DIR/$WG_INTERFACE.conf << EOF

[Peer]
# $CLIENT_NAME
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32
EOF"

# Generate client config
cat > "$HOME/$CLIENT_NAME.conf" << CLIENT_CONF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENT_CONF

echo "Client configuration generated: $HOME/$CLIENT_NAME.conf"
echo "Run on server: sudo wg addconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)"

# Apply to running interface
sudo wg addconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE) 2>/dev/null || true

echo "Add client $CLIENT_NAME with IP $CLIENT_IP"
echo "Public key: $CLIENT_PUB"
