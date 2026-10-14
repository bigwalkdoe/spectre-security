#!/bin/bash
# WireGuard VPN Setup for secure remote access
set -euo pipefail

echo "=== WireGuard VPN Setup ==="

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_SUBNET="10.0.0.0/24"
SERVER_IP="${1:-}"

if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "CHANGE_THIS_TO_YOUR_SERVER_IP")
fi

setup_wireguard() {
    echo "Installing WireGuard..."
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y wireguard-tools 2>/dev/null || true
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install -y wireguard 2>/dev/null || true
    fi

    if ! command -v wg >/dev/null 2>&1; then
        echo "ERROR: WireGuard not installed. Install manually."
        exit 1
    fi

    sudo mkdir -p "$WG_DIR"
    sudo chmod 700 "$WG_DIR"

    # Generate server keys
    if [ ! -f "$WG_DIR/server.key" ]; then
        wg genkey | sudo tee "$WG_DIR/server.key"
        sudo chmod 600 "$WG_DIR/server.key"
    fi
    SERVER_PRIV=$(sudo cat "$WG_DIR/server.key")
    SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)

    # Create server configuration
    cat > /tmp/wg0.conf << WG_CONF
[Interface]
Address = ${WG_SUBNET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}

# Enable NAT and forwarding
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $(ip route get 1 | awk '{print $5;exit}') -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $(ip route get 1 | awk '{print $5;exit}') -j MASQUERADE

# DNS
DNS = 1.1.1.1, 8.8.8.8

# Client configurations (add peers below)
# [Peer]
# PublicKey = <client_public_key>
# AllowedIPs = ${WG_SUBNET}.2/32
WG_CONF
    sudo mv /tmp/wg0.conf "$WG_DIR/$WG_INTERFACE.conf"
    sudo chmod 600 "$WG_DIR/$WG_INTERFACE.conf"
    echo "Server public key: $SERVER_PUB"

    # Create client config generator
    cat > [REDACTED_PATH]/scripts/network/add-vpn-client.sh << CLIENT_SCRIPT
#!/bin/bash
set -euo pipefail

CLIENT_NAME="\${1:-client1}"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_SUBNET="10.0.0.0/24"
SERVER_IP="$SERVER_IP"
SERVER_PORT="$WG_PORT"
CLIENT_IP="\${2:-10.0.0.2}"

# Generate client keys
CLIENT_PRIV=\$(wg genkey)
CLIENT_PUB=\$(echo "\$CLIENT_PRIV" | wg pubkey)
SERVER_PUB=\$(sudo cat \$WG_DIR/server.key | wg pubkey)

# Add client as peer to server
sudo bash -c "cat >> \$WG_DIR/\$WG_INTERFACE.conf << EOF

[Peer]
# \$CLIENT_NAME
PublicKey = \$CLIENT_PUB
AllowedIPs = \$CLIENT_IP/32
EOF"

# Generate client config
cat > "\$HOME/\$CLIENT_NAME.conf" << CLIENT_CONF
[Interface]
PrivateKey = \$CLIENT_PRIV
Address = \$CLIENT_IP/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = \$SERVER_PUB
Endpoint = \$SERVER_IP:\$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENT_CONF

echo "Client configuration generated: \$HOME/\$CLIENT_NAME.conf"
echo "Run on server: sudo wg addconf \$WG_INTERFACE <(wg-quick strip \$WG_INTERFACE)"

# Apply to running interface
sudo wg addconf \$WG_INTERFACE <(wg-quick strip \$WG_INTERFACE) 2>/dev/null || true

echo "Add client \$CLIENT_NAME with IP \$CLIENT_IP"
echo "Public key: \$CLIENT_PUB"
CLIENT_SCRIPT
    chmod +x [REDACTED_PATH]/scripts/network/add-vpn-client.sh
    echo "Client management script created"
}

setup_firewall() {
    echo "Configuring firewall for VPN..."
    if command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --add-port="$WG_PORT/udp" --permanent
        sudo firewall-cmd --add-masquerade --permanent
        sudo firewall-cmd --reload
    elif command -v ufw >/dev/null 2>&1; then
        sudo ufw allow "$WG_PORT/udp"
    fi
    echo "Firewall configured for WireGuard port $WG_PORT/udp"
}

setup_systemd() {
    echo "Creating systemd service..."
    sudo bash -c "cat > /etc/systemd/system/wg-quick@.service << 'SYSTEMD'
[Unit]
Description=WireGuard via wg-quick(8) for %i
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wg-quick up %i
ExecStop=/usr/bin/wg-quick down %i
Environment=WG_SUBNET=$WG_SUBNET
StandardOutput=journal

[Install]
WantedBy=multi-user.target
SYSTEMD"
    sudo systemctl daemon-reload
    sudo systemctl enable "wg-quick@$WG_INTERFACE"
    echo "systemd service created"
}

# Network segmentation
setup_network_segmentation() {
    echo "Setting up Docker network segmentation..."
    
    # Create isolated Docker networks
    docker network create --driver bridge --subnet 172.20.0.0/16 --internal internal-net 2>/dev/null || true
    docker network create --driver bridge --subnet 172.21.0.0/16 dmz-net 2>/dev/null || true
    
    # Label networks for segmentation
    docker network ls --filter name=monitoring --format "{{.Name}}" 2>/dev/null | while read net; do
        docker network inspect "$net" --format '{{.Name}} is isolated: {{json .Internal}}' 2>/dev/null || true
    done
    
    echo "Network segments created: internal-net (isolated), dmz-net"
}

# DDoS protection
setup_ddos_protection() {
    echo "Configuring DDoS protection..."
    
    sudo bash -c 'cat >> /etc/sysctl.conf << "SYSCTL"

# DDoS Protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
SYSCTL'
    sudo sysctl -p
    
    # Create DDoS mitigation script
    cat > [REDACTED_PATH]/scripts/network/ddos-mitigation.sh << 'DDoS'
#!/bin/bash
# DDoS Mitigation Script
set -euo pipefail

echo "=== DDoS Mitigation Check ==="

# Check for high connection count
CONNECTIONS=$(ss -tan | grep ESTAB | wc -l)
SYN_RECV=$(ss -tan | grep SYN-RECV | wc -l)
TIME_WAIT=$(ss -tan | grep TIME-WAIT | wc -l)

echo "Active connections: $CONNECTIONS"
echo "SYN-RECV (potential SYN flood): $SYN_RECV"
echo "TIME-WAIT: $TIME_WAIT"

if [ "$SYN_RECV" -gt 100 ]; then
    echo "WARNING: Possible SYN flood detected! ($SYN_RECV)"
    logger -p user.warning "Possible SYN flood attack detected"
    # Enable SYN cookies if not already
    sudo sysctl -w net.ipv4.tcp_syncookies=1
fi

if [ "$CONNECTIONS" -gt 1000 ]; then
    echo "WARNING: High connection count! ($CONNECTIONS)"
    logger -p user.warning "High connection count detected"
fi

# Top talkers
echo ""
echo "Top connection sources:"
ss -tan | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10

# Rate limiting with iptables
echo "Configuring rate limiting..."
sudo iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 -j REJECT 2>/dev/null || true
sudo iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 -j REJECT 2>/dev/null || true

echo "DDoS mitigation check completed"
DDoS
    chmod +x [REDACTED_PATH]/scripts/network/ddos-mitigation.sh
    echo "DDoS protection configured"
}

# Run all setups
setup_wireguard
echo ""
setup_firewall
echo ""
setup_systemd
echo ""
setup_network_segmentation
echo ""
setup_ddos_protection
echo ""

echo "=== WireGuard VPN Setup Complete ==="
echo ""
echo "Configuration:"
echo "  - Interface: $WG_INTERFACE"
echo "  - Port: $WG_PORT"
echo "  - Subnet: $WG_SUBNET"
echo ""
echo "To start VPN:"
echo "  sudo systemctl start wg-quick@$WG_INTERFACE"
echo "  sudo systemctl enable wg-quick@$WG_INTERFACE"
echo ""
echo "To add clients:"
echo "  [REDACTED_PATH]/scripts/network/add-vpn-client.sh <client_name> [client_ip]"
echo ""
echo "Network segments:"
echo "  - internal-net (172.20.0.0/16) - isolated internal traffic"
echo "  - dmz-net (172.21.0.0/16) - DMZ services"
echo ""
echo "DDoS protection enabled via sysctl and iptables"
echo "Monitor: [REDACTED_PATH]/scripts/network/ddos-mitigation.sh"
