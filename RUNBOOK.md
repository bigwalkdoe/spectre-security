# Security Baseline Operations Runbook

## Overview

This runbook covers daily operations, incident response, and maintenance procedures for the security baseline system.

## System Architecture

```
Security Baseline (10 phases)
├── 1. OPA Policy Validation
├── 2. Security Hardening
├── 3. Trivy FS Scan
├── 4. Wazuh Status
├── 5. AIDE File Integrity
├── 6. Gitleaks Secret Scan
├── 7. Trivy Image Scan
├── 8. SBOM Generation
├── 9. Drift Detection
└── 10. Alerting
```

---

## Daily Operations

### Morning Checklist (Run Daily)

```bash
# 1. Check GitHub Actions for overnight baseline run
gh run list --workflow="Security Baseline Scan" --limit 5

# 2. Check for drift issues
gh issue list --label="drift-detection" --state=open

# 3. Review latest drift report
cat security/logs/drift-report-latest.json | jq '.'

# 4. Verify SBOM artifacts
ls -la security/logs/sbom-latest/
```

### GitHub Actions Monitoring

```bash
# Check recent workflow runs
gh run list --workflow="Security Baseline Scan" --limit 10
gh run list --workflow="Infrastructure Drift Detection" --limit 10

# View specific run details
gh run view <RUN_ID> --log

# Re-run failed workflow
gh run rerun <RUN_ID>
```

### Security Tab Review

```bash
# Check for new vulnerability findings
# Go to: https://github.com/bigwalkdoe/scripts/security/code-scanning
# Or via CLI:
gh api repos/bigwalkdoe/scripts/code-scanning/alerts --paginate
```

---

## Incident Response

### Drift Detected

**Symptoms:**
- GitHub Issue created with label `drift-detection`
- Alert notification (Slack/Email/Webhook)
- GitHub Actions workflow failure

**Response Steps:**

```bash
# 1. Review drift details
cat security/logs/drift-report-latest.json | jq '.categories'

# 2. Categorize drift
# - Network: Ports on 0.0.0.0, missing bindings
# - Docker: Privileged, no memory limits, no healthchecks
# - Compliance: Firewall, auditd, fail2ban, AIDE
# - Backup: Scheduling issues

# 3. Determine if drift is authorized
# - Check recent deployments/changes
# - Consult change management records

# 4. If unauthorized → Remediate
./security/remediate-drift.sh

# 5. If authorized → Update baseline
./security/update-baseline.sh

# 5. Verify remediation
./security/drift-detection.sh

# 6. Close GitHub issue (auto-closes if no drift)
```

### Drift Categories & Response

| Category | Severity | Auto-Fix | Manual Steps |
|----------|----------|----------|--------------|
| Network (0.0.0.0 ports) | HIGH | ❌ | Recreate container with `-p 127.0.0.1:PORT:PORT` |
| Docker (privileged, no limits) | HIGH | ❌ | Recreate with `--memory`, remove `--privileged` |
| Compliance (auditd, fail2ban) | HIGH | ✅ | Run `./security/remediate-drift.sh` |
| Docker (healthchecks, memory) | MEDIUM | ❌ | Update Dockerfile / docker-compose |
| Backup scheduling | LOW | ✅ | Configure cron / backup scripts |

### Secret Leak Detected

**Symptoms:**
- Gitleaks finding in GitHub Security tab
- Alert notification

**Response:**

```bash
# 1. View finding in GitHub Security → Code scanning
# 2. Rotate compromised credential immediately
# 3. Remove from git history (if in history)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch PATH_TO_SECRET" \
  --prune-empty --tag-name-filter cat -- --all
# 4. Force push (coordinate with team)
git push origin --force --all
# 5. Add pattern to .gitleaks.toml allowlist if false positive
```

### Vulnerability Found (Trivy)

**Symptoms:**
- SARIF upload to GitHub Security
- High/Critical CVEs

**Response:**

```bash
# 1. Review in GitHub Security → Code scanning
# 2. Check if fixed version available
trivy image --ignore-unfixed --severity HIGH,CRITICAL <image>
# 3. Update base image / dependencies
# 4. Rebuild and redeploy
# 4. Re-scan to verify
```

---

## Maintenance Procedures

### Weekly

```bash
# 1. Update baseline to current state
./security/update-baseline.sh

# 2. Run full baseline
./security/baseline-runner.sh

# 3. Update Trivy database
trivy image --download-db-only

# 4. Update Gitleaks
go install github.com/gitleaks/gitleaks/v8@latest

# 5. Review and rotate credentials
# Check for expired certs, old keys
```

### Monthly

```bash
# 1. Review compliance mapping
cat security/compliance/COMPLIANCE_MAPPING.md

# 2. Update OPA policies if needed
opa test -v security/opa/policies/

# 3. Review and update SBOM process
./security/generate-sbom.sh

# 4. Audit alerting channels
# Test Slack/webhook/email notifications
./security/alerting.sh info "Monthly test" "Test notification"

# 5. Review GitHub Actions usage
gh api repos/bigwalkdoe/scripts/actions/runs --paginate | jq '.workflow_runs | length'
```

### Quarterly

```bash
# 1. Full policy review
opa test -v security/opa/policies/
# Update COMPLIANCE_MAPPING.md

# 2. Penetration testing coordination
# Engage security team for deeper scan

# 3. Disaster recovery test
# Verify backup restoration
./backups/check-backup-health.sh

# 4. Review and update runbook
# Update RUNBOOK.md with lessons learned
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| `opa: command not found` | OPA not in PATH | `export PATH="$HOME/.local/bin:$PATH"` |
| `trivy: DB error` | DB download failed | `trivy image --download-db-only` |
| `gitleaks: no leaks found` | False negative | Check `.gitleaks.toml` allowlist |
| `auditctl: permission denied` | Not root | Use `systemctl is-active auditd` instead |
| `fail2ban failed` | Missing filters | Fix `/etc/fail2ban/jail.local` |
| `Drift: network ports` | Containers on 0.0.0.0 | Recreate with `-p 127.0.0.1:PORT:PORT` |
| `Drift: auditd` | Check needs root | Use `systemctl is-active auditd` |
| `SBOM generation failed` | Trivy DB missing | Run `trivy image --download-db-only` |

### Debug Commands

```bash
# Debug OPA policies
opa eval -i security/test-data/current-infrastructure.json \
  -d security/opa/policies/docker-security.rego \
  "data.docker.security.deny"

# Debug drift detection
./security/drift-detection.sh 2>&1 | grep -A5 "DRIFT"

# Debug Trivy
trivy fs --debug .

# Debug Gitleaks
gitleaks detect --source . --no-banner --verbose --config .gitleaks.toml

# Debug Drift
./security/drift-detection.sh 2>&1 | tee /tmp/drift-debug.log
```

---

## Contacts & Escalation

| Role | Contact | Escalation |
|------|---------|------------|
| Security Team | security@example.com | P1: 15 min |
| Platform Team | platform@example.com | P2: 1 hour |
| On-Call | oncall@example.com | P0: 5 min |

### Escalation Matrix

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| P0 (Critical) | 5 min | On-Call → Security Lead |
| P1 (High) | 15 min | Security Team → Platform |
| P2 (Medium) | 1 hour | Security Team |
| P3 (Low) | 4 hours | Next business day |

---

## Useful Links

- [GitHub Actions](https://github.com/bigwalkdoe/scripts/actions)
- [Security Tab](https://github.com/bigwalkdoe/scripts/security)
- [Drift Issues](https://github.com/bigwalkdoe/scripts/issues?q=label%3Adrift-detection)
- [Dependabot Alerts](https://github.com/bigwalkdoe/scripts/security/dependabot)
- [Code Scanning Alerts](https://github.com/bigwalkdoe/scripts/security/code-scanning)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-10-15 | Initial release |
| 1.1 | TBD | Add Kubernetes policies |

---

*Last Updated: $(date +%Y-%m-%d)*
*Maintained by: Security Team*