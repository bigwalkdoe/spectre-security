package network.security

# VPN required for remote access
deny[msg] {
    input.remote_access == true
    not input.vpn_enabled
    msg = "Remote access requires VPN"
}

# Container networks should be isolated
deny[msg] {
    input.container_network == "host"
    msg = "Container host networking is not allowed"
}

# Unused ports must be closed
deny[msg] {
    port := input.open_ports[_]
    port > 10000
    not allowed_port(port)
    msg = sprintf("Port %d is open but not in allowed list", [port])
}

allowed_port(port) {
    port == 22    # SSH
    port == 80    # HTTP
    port == 443   # HTTPS
    port == 3002  # Grafana
    port == 9090  # Prometheus
    port == 9093  # Alertmanager
    port == 8081  # Web Dashboard
    port == 3100  # Loki
}
