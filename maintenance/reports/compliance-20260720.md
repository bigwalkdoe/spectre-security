=== Compliance Report - 20260720 ===

## Backup Status
- Last database backup: neo4j_backup_20260719_010000.tar.gz
- Last full backup: 
- Backup size: 292K

## Security Status
- Fail2Ban status: not running
- AIDE last check: 
- Running containers: 2

## System Health
- Uptime: up 3 hours, 48 minutes
- CPU: 27.6% used
- Memory: 10Gi/15Gi
- Disk: 98% used

## Monitoring Status
- prometheus: NOT RUNNING
- grafana: NOT RUNNING
- alertmanager: NOT RUNNING

## Recent Security Events (24h)
-- Boot d9da38adc1524ea5aa1ba9b9778029aa --
Jul 20 03:28:25 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Jul 20 03:28:25 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Jul 20 03:28:25 fedora fail2ban-server[1786]: 2026-07-20 03:28:25,681 fail2ban.configreader   [1786]: ERROR   Found no accessible config files for 'filter.d/sshd-ddos' under /etc/fail2ban
Jul 20 03:28:25 fedora fail2ban-server[1786]: 2026-07-20 03:28:25,681 fail2ban.jailreader     [1786]: ERROR   Unable to read the filter 'sshd-ddos'
Jul 20 03:28:25 fedora fail2ban-server[1786]: 2026-07-20 03:28:25,681 fail2ban.jailsreader    [1786]: ERROR   Errors in jail 'sshd-ddos'. Skipping...
Jul 20 03:28:25 fedora fail2ban-server[1786]: 2026-07-20 03:28:25,700 fail2ban                [1786]: ERROR   Failed during configuration: Have not found any log file for docker jail
Jul 20 03:28:25 fedora fail2ban-server[1786]: 2026-07-20 03:28:25,702 fail2ban                [1786]: ERROR   Async configuration of server failed
Jul 20 03:28:25 fedora systemd[1]: fail2ban.service: Main process exited, code=exited, status=255/EXCEPTION
Jul 20 03:28:25 fedora systemd[1]: fail2ban.service: Failed with result 'exit-code'.
-- Boot 0457536f8d6842b39d1c34fbed6f0bd2 --
Jul 20 04:11:36 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Jul 20 04:11:36 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Jul 20 04:11:36 fedora fail2ban-server[1613]: 2026-07-20 04:11:36,639 fail2ban.configreader   [1613]: ERROR   Found no accessible config files for 'filter.d/sshd-ddos' under /etc/fail2ban
Jul 20 04:11:36 fedora fail2ban-server[1613]: 2026-07-20 04:11:36,639 fail2ban.jailreader     [1613]: ERROR   Unable to read the filter 'sshd-ddos'
Jul 20 04:11:36 fedora fail2ban-server[1613]: 2026-07-20 04:11:36,639 fail2ban.jailsreader    [1613]: ERROR   Errors in jail 'sshd-ddos'. Skipping...
Jul 20 04:11:36 fedora fail2ban-server[1613]: 2026-07-20 04:11:36,661 fail2ban                [1613]: ERROR   Failed during configuration: Have not found any log file for docker jail
Jul 20 04:11:36 fedora fail2ban-server[1613]: 2026-07-20 04:11:36,665 fail2ban                [1613]: ERROR   Async configuration of server failed
Jul 20 04:11:36 fedora systemd[1]: fail2ban.service: Main process exited, code=exited, status=255/EXCEPTION
Jul 20 04:11:36 fedora systemd[1]: fail2ban.service: Failed with result 'exit-code'.

---
Report generated: Mon Jul 20 08:00:03 AM PKT 2026
