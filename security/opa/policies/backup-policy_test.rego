package backup.policy

# Test: Backup is compliant when all requirements met
test_compliant_backup {
    deny := data.backup.policy.deny with input as {"encrypted": true, "retention_days": 30, "offsite_replication": true, "last_success_age": 3600}
    count(deny) == 0
}

# Test: Missing encryption is denied
test_missing_encryption {
    deny := data.backup.policy.deny with input as {"encrypted": false, "retention_days": 30, "offsite_replication": true, "last_success_age": 3600}
    deny[_] == "Backups must be encrypted at rest"
}

# Test: Retention below 7 days is denied
test_short_retention {
    deny := data.backup.policy.deny with input as {"encrypted": true, "retention_days": 3, "offsite_replication": true, "last_success_age": 3600}
    deny[_] == "Backup retention (3 days) is less than minimum 7 days"
}

# Test: Missing off-site replication is denied
test_missing_offsite {
    deny := data.backup.policy.deny with input as {"encrypted": true, "retention_days": 30, "offsite_replication": false, "last_success_age": 3600}
    deny[_] == "Backups must be replicated off-site"
}

# Test: Stale backup (>24hrs) is denied
test_stale_backup {
    deny := data.backup.policy.deny with input as {"encrypted": true, "retention_days": 30, "offsite_replication": true, "last_success_age": 90000}
    deny[_] == "Last successful backup is more than 24 hours old"
}

# Test: Multiple violations return all errors
test_multiple_violations {
    deny := data.backup.policy.deny with input as {"encrypted": false, "retention_days": 3, "offsite_replication": false, "last_success_age": 90000}
    count(deny) == 4
}