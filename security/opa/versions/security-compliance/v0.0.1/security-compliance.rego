package security.compliance

# Firewall must be enabled
deny[msg] {
    not input.firewall_enabled
    msg = "Firewall must be enabled on all systems"
}

# SSH must use key-based auth
deny[msg] {
    input.ssh_password_auth == true
    msg = "SSH password authentication must be disabled"
}

# Audit logging must be enabled
deny[msg] {
    not input.audit_logging_enabled
    msg = "Audit logging must be enabled"
}

# Intrusion detection must be active
deny[msg] {
    not input.intrusion_detection_active
    msg = "Intrusion detection (Fail2Ban) must be active"
}

# File integrity monitoring
deny[msg] {
    not input.file_integrity_monitoring
    msg = "File integrity monitoring (AIDE) must be active"
}

# Automated security scanning
deny[msg] {
    not input.security_scanning_enabled
    msg = "Automated security scanning must be enabled"
}
