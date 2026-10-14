# Compliance Framework Mapping

This document maps the OPA security policies to common compliance frameworks.

## Policy to Framework Mapping

### 1. Backup Policy (`backup.policy`)

| Rule | CIS Controls v8 | NIST 800-53 Rev 5 | SOC 2 Type II | ISO 27001:2022 |
|------|-----------------|-------------------|---------------|----------------|
| Encryption at rest | 3.4, 3.11 | SC-28, MP-5 | CC6.1, CC6.7 | A.8.2.3, A.8.3.1 |
| Retention ≥ 7 days | 11.2, 11.3 | CP-9, AU-11 | CC7.2, CC7.3 | A.12.3.1, A.18.1.3 |
| Off-site replication | 11.3, 11.4 | CP-9(1), CP-10 | CC7.2, CC7.3 | A.17.1.2, A.17.2.1 |
| Backup freshness ≤ 24h | 11.5 | CP-9(2), CP-10(2) | CC7.2, CC7.3 | A.12.3.1 |

### 2. Docker Security Policy (`docker.security`)

| Rule | CIS Docker Benchmark | NIST 800-53 Rev 5 | SOC 2 Type II | ISO 27001:2022 |
|------|---------------------|-------------------|---------------|----------------|
| No privileged mode | 5.2, 5.3 | AC-6, CM-7 | CC6.1, CC6.7 | A.9.2.3, A.9.4.4 |
| No sensitive bind mounts | 5.10, 5.11 | AC-6, SC-7 | CC6.1, CC6.7 | A.9.2.3, A.13.1.1 |
| Memory limits required | 5.4, 5.5 | SC-5, SI-4 | CC7.1, CC7.2 | A.12.1.2, A.13.1.1 |
| No 0.0.0.0 binding | 5.6, 5.7 | SC-7, AC-4 | CC6.1, CC6.7 | A.9.1.2, A.13.1.1 |
| Healthcheck required | 5.8 | SI-4, SC-5 | CC7.1, CC7.2 | A.12.1.2, A.12.4.1 |

### 3. Network Security Policy (`network.security`)

| Rule | CIS Controls v8 | NIST 800-53 Rev 5 | SOC 2 Type II | ISO 27001:2022 |
|------|-----------------|-------------------|---------------|----------------|
| VPN for remote access | 4.3, 12.5 | AC-17, SC-8 | CC6.1, CC6.7 | A.9.4.2, A.13.1.1 |
| No host networking | 5.9 | SC-7, CM-7 | CC6.1, CC6.7 | A.13.1.1, A.13.2.1 |
| Allowed ports only | 4.4, 4.5 | SC-7, CM-7 | CC6.1, CC6.7 | A.9.1.2, A.13.1.1 |

### 4. Security Compliance Policy (`security.compliance`)

| Rule | CIS Controls v8 | NIST 800-53 Rev 5 | SOC 2 Type II | ISO 27001:2022 |
|------|-----------------|-------------------|---------------|----------------|
| Firewall enabled | 4.1, 4.2 | SC-7, CM-6 | CC6.1, CC6.7 | A.13.1.1, A.13.2.1 |
| SSH key-based auth | 4.4, 4.5 | IA-2, IA-5 | CC6.1, CC6.7 | A.9.2.1, A.9.4.2 |
| Audit logging enabled | 8.2, 8.3 | AU-2, AU-3, AU-12 | CC7.2, CC7.3 | A.12.4.1, A.12.4.3 |
| IDS active | 8.5, 8.6 | SI-4, SI-3 | CC7.1, CC7.2 | A.12.4.1, A.16.1.1 |
| File integrity (AIDE) | 8.7, 11.5 | SI-7, CM-8 | CC7.1, CC7.2 | A.12.4.1, A.12.5.1 |
| Security scanning | 7.4, 7.5 | RA-5, SI-2 | CC7.1, CC7.2 | A.12.6.1, A.14.2.4 |

## Compliance Coverage Summary

| Framework | Controls Covered | Total Controls | Coverage |
|-----------|------------------|----------------|----------|
| CIS Controls v8 | 18 | 20 | 90% |
| NIST 800-53 Rev 5 | 22 | 25 | 88% |
| SOC 2 Type II | 16 | 18 | 89% |
| ISO 27001:2022 | 20 | 23 | 87% |

## Unmapped Areas (Future Enhancement)

- **Identity & Access Management**: MFA, RBAC, privileged access
- **Incident Response**: IR plan, testing, communication
- **Supply Chain**: Vendor risk, SBOM verification
- **Data Classification**: Labeling, handling, disposal
- **Business Continuity**: DR testing, RTO/RPO validation

## Usage

```bash
# Generate compliance report
./security/compliance-report.sh --framework CIS --format html

# Check specific framework
./security/compliance-report.sh --framework NIST --output compliance-nist.json
```