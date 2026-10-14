package backup.policy

# Backups must be encrypted
deny[msg] {
    not input.encrypted
    msg = "Backups must be encrypted at rest"
}

# Backups must be retained for minimum 7 days
deny[msg] {
    input.retention_days < 7
    msg = sprintf("Backup retention (%d days) is less than minimum 7 days", [input.retention_days])
}

# Backups must have off-site replication
deny[msg] {
    not input.offsite_replication
    msg = "Backups must be replicated off-site"
}

# Backup must complete within 24 hours
deny[msg] {
    input.last_success_age > 86400
    msg = "Last successful backup is more than 24 hours old"
}
# Additional test rule
