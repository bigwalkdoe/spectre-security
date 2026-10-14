package network.security

# Test: Compliant network passes
test_compliant_network {
    deny := data.network.security.deny with input as {
        "remote_access": true,
        "vpn_enabled": true,
        "container_network": "bridge",
        "open_ports": [22, 80, 443, 3002, 9090, 9093, 8081, 3100]
    }
    count(deny) == 0
}

# Test: Remote access without VPN is denied
test_remote_without_vpn_denied {
    deny := data.network.security.deny with input as {
        "remote_access": true,
        "vpn_enabled": false,
        "container_network": "bridge",
        "open_ports": [22, 80, 443]
    }
    deny[_] == "Remote access requires VPN"
}

# Test: Host networking is denied
test_host_network_denied {
    deny := data.network.security.deny with input as {
        "remote_access": false,
        "vpn_enabled": true,
        "container_network": "host",
        "open_ports": [22, 80, 443]
    }
    deny[_] == "Container host networking is not allowed"
}

# Test: Disallowed high port (>10000) is denied
test_disallowed_port_denied {
    deny := data.network.security.deny with input as {
        "remote_access": false,
        "vpn_enabled": true,
        "container_network": "bridge",
        "open_ports": [22, 80, 443, 10001]
    }
    deny[_] == "Port 10001 is open but not in allowed list"
}

# Test: Multiple violations (4 total: host networking, VPN, port 10001, port 10002)
test_multiple_violations {
    deny := data.network.security.deny with input as {
        "remote_access": true,
        "vpn_enabled": false,
        "container_network": "host",
        "open_ports": [22, 80, 443, 10001, 10002]
    }
    count(deny) == 4
}

# Test: No remote access, VPN not required
test_no_remote_access_ok {
    deny := data.network.security.deny with input as {
        "remote_access": false,
        "vpn_enabled": false,
        "container_network": "bridge",
        "open_ports": [22, 80, 443]
    }
    count(deny) == 0
}