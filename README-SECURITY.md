# Spectre Security Architecture

## Overview
This repository implements a defense-in-depth security strategy for Spectre Security.

## OPA Security Policies
Four policy packages enforce security baselines:

### 1. Backup Policies (`security/opa/policies/backup-policy.rego`)
- **Encryption**: Backups must be encrypted at rest
- **Retention**: Minimum 7 days retention
- **Off-site Replication**: Backups must be replicated off-site
- **Freshness**: Last successful backup within 24 hours

### 2. Docker Security (`security/opa/policies/docker-security.rego`)
- **Privileged Mode**: Containers must not run in privileged mode
- **Bind Mounts**: No sensitive paths (/etc, /var/run, /proc, /sys, /dev) as bind mounts
- **Resource Limits**: Memory limits required (no unlimited containers)
- **Network Exposure**: Ports must not be exposed on all interfaces (0.0.0.0)
- **Health Checks**: Healthcheck must be configured

### 3. Network Security (`security/opa/policies/network-security.rego`)
- **VPN Requirement**: Remote access requires VPN
- **Container Networks**: Host networking is prohibited
- **Port Restrictions**: Only allowed ports (SSH, HTTP, HTTPS, Grafana, Prometheus, etc.) may be open

### 4. Compliance (`security/opa/policies/security-compliance.rego`)
- **Firewall**: Must be enabled on all systems
- **SSH Authentication**: Password-based SSH authentication must be disabled
- **Audit Logging**: Audit logging must be enabled
- **Intrusion Detection**: Fail2Ban (intrusion detection) must be active
- **File Integrity**: AIDE file integrity monitoring must be active
- **Security Scanning**: Automated security scanning must be enabled

## Security Scripts

### AIDE File Integrity Check (`security/check-file-integrity.sh`)
- Initializes AIDE database on first run
- Runs `aide --check` to validate file integrity
- Updates the database on successful checks

### Wazuh Agent Status (`security/check-wazuh-status.sh`)
- Verifies Wazuh agent is installed and running
- Checks service status
- Reports agent logs location

### Security Scanners
- **Trivy** - Vulnerability scanning for container images
- **SonarQube** - Code quality and static analysis
- **ZAP** - Web application security scanning
- **SonarQube Analysis** - Additional code quality checks
- **Trivy Image Scans** - Detailed vulnerability reports
- **Snyk/Other** - Additional security tools

## Implementation Guidelines

### Policy Enforcement
- All OPA policies should be validated in CI/CD pipelines
- Failed policy violations should block merges
- Regular policy reviews recommended

### Monitoring
- AIDE checks should run periodically
- Wazuh agent should be active and monitored
- Security scanner outputs should be logged and alerted on

### Maintenance
- Regular updates to OPA policies for new threats
- Periodic security audit of the scripts themselves
- Secret scanning should be added to prevent credential leakage

## Quick Reference

| Area | Policy | Key Requirement |
|------|--------|-----------------|
| Backups | backup-policy.rego | Encryption, 7-day retention, off-site replication |
| Containers | docker-security.rego | No privileged mode, no sensitive bind mounts, resource limits |
| Network | network-security.rego | VPN for remote access, isolated networks, limited ports |
| Compliance | security-compliance.rego | Firewall, SSH key auth, audit logging, IDS, file integrity, scanning |

## Getting Started

1. **Enable OPA policies** in your CI/CD pipeline
2. **Run security scans** regularly:
   - `./run-security-hardening.sh`
   - `./run-trivy-scan.sh`
   - `./run-security-hardening.sh`
3. **Monitor AIDE** and Wazuh agent status
4. **Review compliance** weekly

## License

MIT License - See [LICENSE](LICENSE) for details.
