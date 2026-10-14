# Automated Remediation Report

**Generated:** $(date)
**Source:** $(cat "$LATEST_DRIFT_JSON" | jq -r '.baseline_file')
**Drift Detected:** $(cat "$LATEST_DRIFT_JSON" | jq -r '.drift_detected')

---

## Summary

| Category | Issues | Auto-Fixable | Manual Required |
|----------|--------|--------------|-----------------|
| network | 7 | TBD | TBD |

### network

