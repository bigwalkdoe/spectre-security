# Spectre Security

Defense-in-depth security baseline with continuous compliance monitoring, drift detection, and SBOM generation for containerized infrastructure.

## Overview

Spectre Security implements a defense-in-depth security strategy with automated compliance monitoring, drift detection, and CI/CD integration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Security Baseline                           │
├─────────────────────────────────────────────────────────────────┤
│  1. OPA Policy Validation    │  4 policy packages, 27 tests     │
│  2. Security Hardening       │  Docker, files, permissions      │
│  3. Trivy FS Scan            │  Vulnerability & secret scanning │
│  4. Wazuh Status             │  Agent health check              │
│  5. AIDE File Integrity      │  Immutable file monitoring       │
│  6. Gitleaks Secret Scan     │  Credential detection            │
│  7. Trivy Image Scan         │  Docker image vulnerabilities    │
│  8. SBOM Generation          │  CycloneDX + SPDX formats        │
│  9. Drift Detection          │  Live vs baseline comparison     │
│  10. Alerting                │  Slack, webhook, email           │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# Run full security baseline
./security/baseline-runner.sh

# Check for infrastructure drift
./security/drift-detection.sh

# Generate compliance report
./security/compliance-report.sh all markdown

# Generate SBOM
./security/generate-sbom.sh

# Run OPA policy tests
./security/test-opa-policies.sh
```

## Policy Framework

### 1. Backup Policy (`security/opa/policies/backup-policy.rego`)
- Encryption at rest required
- Minimum 7-day retention
- Off-site replication required
- Backup freshness ≤ 24 hours

### 2. Docker Security (`security/opa/policies/docker-security.rego`)
- No privileged containers
- No sensitive bind mounts (`/etc`, `/var/run`, `/proc`, `/sys`, `/dev`)
- Memory limits required
- No 0.0.0.0 port bindings
- Health checks required

### 3. Network Security (`security/opa/policies/network-security.rego`)
- VPN required for remote access
- No host networking
- Only allowed ports open (22, 80, 443, 3002, 9090, 9093, 8081, 3100, 8123, 5432, 6379)

### 4. Security Compliance (`security/opa/policies/security-compliance.rego`)
- Firewall enabled
- SSH key-based authentication
- Audit logging enabled
- Intrusion detection active
- File integrity monitoring (AIDE)
- Automated security scanning

## CI/CD Pipeline

### Security Baseline Workflow (`.github/workflows/security-baseline.yml`)
**Triggers**: Push to main/develop, PR, Daily at 2 AM UTC

| Job | Description |
|-----|-------------|
| security-baseline | Full 10-phase baseline scan |
| docker-image-scan | Trivy scan of Docker images (main branch) |
| dependency-review | Dependency vulnerability check on PR |

### Drift Detection Workflow (`.github/workflows/drift-detection.yml`)
**Triggers**: Every 6 hours, Push, Manual

- Runs drift detection against baseline
- Creates/updates/closes GitHub issues automatically
- Uploads drift reports as artifacts (30-day retention)

## Compliance Mapping

Policies mapped to frameworks:
- **CIS Controls v8 / Docker Benchmark**: 90% coverage
- **NIST 800-53 Rev 5**: 88% coverage
- **SOC 2 Type II**: 89% coverage
- **ISO 27001:2022**: 87% coverage

See [`security/compliance/COMPLIANCE_MAPPING.md`](security/compliance/COMPLIANCE_MAPPING.md)

## Key Files

```
security/
├── baseline-runner.sh            # Main orchestrator (10 phases)
├── drift-detection.sh            # Live vs baseline comparison
├── remediate-drift.sh            # Auto-fix where possible
├── remediation-report.sh         # Per-violation fix commands
├── generate-remediation-commands.sh  # Prioritized fix commands
├── alerting.sh                   # Webhook/Slack/Email notifications
├── update-baseline.sh            # Sync baseline to live state
├── generate-sbom.sh              # CycloneDX + SPDX SBOM
├── trivy-image-scan.sh           # Docker image scanning
├── compliance-report.sh          # Multi-format compliance reports
├── test-opa-policies.sh          # 27 OPA policy unit tests
├── run-security-hardening.sh     # Local hardening checks
├── check-file-integrity-local.sh # AIDE file integrity
├── check-wazuh-status.sh         # Wazuh agent status
├── security-baseline-exporter.sh # Prometheus exporter (metrics)
├── logs/                         # Execution logs & reports
├── compliance/                   # Framework mappings
├── opa/policies/                 # 4 policy packages + 27 tests
└── test-data/
    └── current-infrastructure.json  # Live infrastructure baseline
```

## Running Tests

```bash
# OPA policy unit tests (27 tests)
./security/test-opa-policies.sh

# Or directly with OPA
opa test -v security/opa/policies/
```

## Drift Detection

```bash
# Check for drift
./security/drift-detection.sh

# View latest report
cat security/logs/drift-report-latest.json | jq '.'

# Update baseline to current state
./security/update-baseline.sh

# Generate remediation commands
./security/generate-remediation-commands.sh
sudo bash security/logs/remediation-commands-*.sh
```

## SBOM Generation

```bash
# Source code SBOM
./security/generate-sbom.sh

# Docker image SBOM
IMAGE_NAME=myapp:latest ./security/generate-sbom.sh

# Output: security/logs/sbom-*/sbom-source.cdx.json (CycloneDX)
#         security/logs/sbom-*/sbom-source.spdx.json (SPDX)
```

## Alerting Configuration

Set environment variables to enable notifications:

```bash
# Slack
export SECURITY_SLACK_WEBHOOK="https://hooks.slack.com/services/XXX/YYY/ZZZ"

# Generic webhook
export SECURITY_WEBHOOK_URL="https://your-webhook.example.com"

# Email (requires sendmail)
export SECURITY_EMAIL_TO="security@example.com"
```

## Requirements

- Docker
- Trivy (`pip install trivy` or binary)
- Gitleaks (`go install github.com/gitleaks/gitleaks/v8@latest`)
- OPA (`curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/v0.67.0/opa_linux_amd64_static`)
- AIDE (`dnf install aide` / `apt install aide`)
- jq, curl, systemd

## Adding New Policies

1. Create `.rego` file in `security/opa/policies/`
2. Create corresponding `_test.rego` with unit tests
3. Run `./security/test-opa-policies.sh`
4. Update `security/compliance/COMPLIANCE_MAPPING.md`
5. Add to `security/baseline-runner.sh` if new phase needed

## Directory Structure

```
.
├── .github/
│   ├── workflows/
│   │   ├── security-baseline.yml
│   │   ├── drift-detection.yml
│   │   └── policy-gate.yml
│   ├── dependabot.yml
│   └── dependency-review-config.yml
├── .gitleaks.toml
├── .gitignore
├── LICENSE
├── README.md
├── README-SECURITY.md
├── RUNBOOK.md
├── security/
│   ├── baseline-runner.sh
│   ├── drift-detection.sh
│   ├── remediate-drift.sh
│   ├── remediation-report.sh
│   ├── alerting.sh
│   ├── update-baseline.sh
│   ├── generate-sbom.sh
│   ├── generate-remediation-commands.sh
│   ├── priority-remediation.sh
│   ├── compliance-report.sh
│   ├── test-opa-policies.sh
│   ├── trivy-image-scan.sh
│   ├── run-trivy-scan.sh
│   ├── run-zap-scan.sh
│   ├── run-sonarqube-analysis.sh
│   ├── run-security-hardening.sh
│   ├── scan-dependencies.sh
│   ├── scan-docker-images.sh
│   ├── api-security-hardening.sh
│   ├── docker-security-hardening.sh
│   ├── monitor-api-security.sh
│   ├── check-file-integrity.sh
│   ├── check-file-integrity-local.sh
│   ├── check-wazuh-status.sh
│   ├── inject-secrets.sh
│   ├── setup-opa-policies.sh
│   ├── setup-intrusion-detection.sh
│   ├── setup-rate-limiting.sh
│   ├── setup-secrets-management.sh
│   ├── setup-security-scanning.sh
│   ├── security-baseline-exporter.sh
│   ├── security-baseline-http-exporter.sh
│   ├── logs/
│   ├── compliance/
│   ├── compliance-reports/
│   ├── reports/
│   ├── opa/
│   │   ├── policies/
│   │   └── versions/
│   ├── test-data/
│   ├── zap/
│   └── sonarqube/
├── scripts/
│   ├── configure-alerting.sh
│   └── policy-version-manager.sh
├── backups/
├── logging/
├── maintenance/
├── monitoring/
├── network/
├── performance/
└── *.sh (utility scripts)
```

## License

MIT License - See LICENSE file for details.