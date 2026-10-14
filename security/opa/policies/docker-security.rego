package docker.security

# Deny containers running with privileged mode
deny[msg] {
    input.privileged == true
    msg = sprintf("Container %s is running in privileged mode", [input.name])
}

# Deny containers with bind mounts to sensitive paths
deny[msg] {
    mount := input.mounts[_]
    sensitive_paths := ["/etc", "/var/run", "/proc", "/sys", "/dev"]
    startswith(mount.source, sensitive_paths[_])
    msg = sprintf("Container %s has sensitive bind mount: %s", [input.name, mount.source])
}

# Deny containers without resource limits
deny[msg] {
    input.memory_limit == 0
    msg = sprintf("Container %s has no memory limit", [input.name])
}

# Deny containers exposed on all interfaces (0.0.0.0)
deny[msg] {
    port := input.ports[_]
    port.host_ip == "0.0.0.0"
    msg = sprintf("Container %s exposes port %d on all interfaces", [input.name, port.host_port])
}

# Require healthcheck
deny[msg] {
    input.healthcheck == ""
    msg = sprintf("Container %s has no healthcheck configured", [input.name])
}
