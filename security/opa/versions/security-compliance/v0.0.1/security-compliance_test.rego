package security.compliance

# Test: Fully compliant system passes
test_compliant_system {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": true,
        "ssh_password_auth": false,
        "audit_logging_enabled": true,
        "intrusion_detection_active": true,
        "file_integrity_monitoring": true,
        "security_scanning_enabled": true
    }
    count(deny) == 0
}

# Test: Disabled firewall is denied
test_firewall_disabled_denied {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": false,
        "ssh_password_auth": false,
        "audit_logging_enabled": true,
        "intrusion_detection_active": true,
        "file_integrity_monitoring": true,
        "security_scanning_enabled": true
    }
    deny[_] == "Firewall must be enabled on all systems"
}

# Test: SSH password auth enabled is denied
test_ssh_password_auth_denied {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": true,
        "ssh_password_auth": true,
        "audit_logging_enabled": true,
        "intrusion_detection_active": true,
        "file_integrity_monitoring": true,
        "security_scanning_enabled": true
    }
    deny[_] == "SSH password authentication must be disabled"
}

# Test: Audit logging disabled is denied
test_audit_logging_disabled_denied {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": true,
        "ssh_password_auth": false,
        "audit_logging_enabled": false,
        "intrusion_detection_active": true,
        "file_integrity_monitoring": true,
        "security_scanning_enabled": true
    }
    deny[_] == "Audit logging must be enabled"
}

# Test: Intrusion detection inactive is denied
test_ids_inactive_denied {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": true,
        "ssh_password_auth": false,
        "audit_logging_enabled": true,
        "intrusion_detection_active": false,
        "file_integrity_monitoring": true,
        "security_scanning_enabled": true
    }
    deny[_] == "Intrusion detection (Fail2Ban) must be active"
}

# Test: File integrity monitoring inactive is denied
test_fim_inactive_denied {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": true,
        "ssh_password_auth": false,
        "audit_logging_enabled": true,
        "intrusion_detection_active": true,
        "file_integrity_monitoring": false,
        "security_scanning_enabled": true
    }
    deny[_] == "File integrity monitoring (AIDE) must be active"
}

# Test: Security scanning disabled is denied
test_scanning_disabled_denied {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": true,
        "ssh_password_auth": false,
        "audit_logging_enabled": true,
        "intrusion_detection_active": true,
        "file_integrity_monitoring": true,
        "security_scanning_enabled": false
    }
    deny[_] == "Automated security scanning must be enabled"
}

# Test: All controls disabled - 6 violations
test_all_disabled {
    deny := data.security.compliance.deny with input as {
        "firewall_enabled": false,
        "ssh_password_auth": true,
        "audit_logging_enabled": false,
        "intrusion_detection_active": false,
        "file_integrity_monitoring": false,
        "security_scanning_enabled": false
    }
    count(deny) == 6
}