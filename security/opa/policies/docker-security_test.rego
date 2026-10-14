package docker.security

# Test: Compliant container passes
test_compliant_container {
    deny := data.docker.security.deny with input as {
        "name": "test-app",
        "privileged": false,
        "mounts": [{"source": "/data/app"}],
        "memory_limit": 2147483648,
        "ports": [{"host_ip": "127.0.0.1", "host_port": 8080}],
        "healthcheck": "http://localhost:8080/health"
    }
    count(deny) == 0
}

# Test: Privileged mode is denied
test_privileged_denied {
    deny := data.docker.security.deny with input as {
        "name": "priv-app",
        "privileged": true,
        "mounts": [{"source": "/data/app"}],
        "memory_limit": 2147483648,
        "ports": [{"host_ip": "127.0.0.1", "host_port": 8080}],
        "healthcheck": "http://localhost:8080/health"
    }
    deny[_] == "Container priv-app is running in privileged mode"
}

# Test: Sensitive bind mount (/etc) is denied
test_sensitive_mount_denied {
    deny := data.docker.security.deny with input as {
        "name": "mount-app",
        "privileged": false,
        "mounts": [{"source": "/etc/passwd"}],
        "memory_limit": 2147483648,
        "ports": [{"host_ip": "127.0.0.1", "host_port": 8080}],
        "healthcheck": "http://localhost:8080/health"
    }
    deny[_] == "Container mount-app has sensitive bind mount: /etc/passwd"
}

# Test: No memory limit is denied
test_no_memory_limit_denied {
    deny := data.docker.security.deny with input as {
        "name": "nolimit-app",
        "privileged": false,
        "mounts": [{"source": "/data/app"}],
        "memory_limit": 0,
        "ports": [{"host_ip": "127.0.0.1", "host_port": 8080}],
        "healthcheck": "http://localhost:8080/health"
    }
    deny[_] == "Container nolimit-app has no memory limit"
}

# Test: Binding to 0.0.0.0 is denied
test_all_interfaces_denied {
    deny := data.docker.security.deny with input as {
        "name": "public-app",
        "privileged": false,
        "mounts": [{"source": "/data/app"}],
        "memory_limit": 2147483648,
        "ports": [{"host_ip": "0.0.0.0", "host_port": 8080}],
        "healthcheck": "http://localhost:8080/health"
    }
    deny[_] == "Container public-app exposes port 8080 on all interfaces"
}

# Test: Missing healthcheck is denied
test_missing_healthcheck_denied {
    deny := data.docker.security.deny with input as {
        "name": "nohealth-app",
        "privileged": false,
        "mounts": [{"source": "/data/app"}],
        "memory_limit": 2147483648,
        "ports": [{"host_ip": "127.0.0.1", "host_port": 8080}],
        "healthcheck": ""
    }
    deny[_] == "Container nohealth-app has no healthcheck configured"
}

# Test: Multiple violations (6 total)
test_multiple_violations {
    deny := data.docker.security.deny with input as {
        "name": "bad-app",
        "privileged": true,
        "mounts": [{"source": "/etc/passwd"}, {"source": "/var/run/docker.sock"}],
        "memory_limit": 0,
        "ports": [{"host_ip": "0.0.0.0", "host_port": 8080}],
        "healthcheck": ""
    }
    count(deny) == 6
}