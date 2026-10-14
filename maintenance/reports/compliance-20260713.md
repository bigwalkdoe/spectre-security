=== Compliance Report - 20260713 ===

## Backup Status
- Last database backup: postgres_guardrail_20260712_163607.sql.gz
- Last full backup: 
- Backup size: 292K

## Security Status
- Fail2Ban status: not running
- AIDE last check: 
- Running containers: 17

## System Health
- Uptime: up 14 hours, 14 minutes
- CPU: 36.4% used
- Memory: 10Gi/15Gi
- Disk: 68% used

## Monitoring Status
- prometheus: NOT RUNNING
- grafana: Running
- alertmanager: Running

## Recent Security Events (24h)
-- Boot 14dc5ba3cb1d4f33b176a100786e3da2 --
Jul 12 18:29:02 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Jul 12 18:29:02 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Jul 12 18:29:02 fedora fail2ban-server[1550]: 2026-07-12 18:29:02,616 fail2ban.configreader   [1550]: ERROR   Found no accessible config files for 'filter.d/sshd-ddos' under /etc/fail2ban
Jul 12 18:29:02 fedora fail2ban-server[1550]: 2026-07-12 18:29:02,616 fail2ban.jailreader     [1550]: ERROR   Unable to read the filter 'sshd-ddos'
Jul 12 18:29:02 fedora fail2ban-server[1550]: 2026-07-12 18:29:02,617 fail2ban.jailsreader    [1550]: ERROR   Errors in jail 'sshd-ddos'. Skipping...
Jul 12 18:29:02 fedora fail2ban-server[1550]: 2026-07-12 18:29:02,656 fail2ban                [1550]: ERROR   Failed during configuration: Have not found any log file for docker jail
Jul 12 18:29:02 fedora fail2ban-server[1550]: 2026-07-12 18:29:02,667 fail2ban                [1550]: ERROR   Async configuration of server failed
Jul 12 18:29:02 fedora systemd[1]: fail2ban.service: Main process exited, code=exited, status=255/EXCEPTION
Jul 12 18:29:02 fedora systemd[1]: fail2ban.service: Failed with result 'exit-code'.
-- Boot 6f82ab630d494f1ab818f3ce56cca7b7 --
Jul 12 18:49:09 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Jul 12 18:49:09 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Jul 12 18:49:10 fedora fail2ban-server[4084]: 2026-07-12 18:49:10,184 fail2ban.configreader   [4084]: ERROR   Found no accessible config files for 'filter.d/sshd-ddos' under /etc/fail2ban
Jul 12 18:49:10 fedora fail2ban-server[4084]: 2026-07-12 18:49:10,184 fail2ban.jailreader     [4084]: ERROR   Unable to read the filter 'sshd-ddos'
Jul 12 18:49:10 fedora fail2ban-server[4084]: 2026-07-12 18:49:10,184 fail2ban.jailsreader    [4084]: ERROR   Errors in jail 'sshd-ddos'. Skipping...
Jul 12 18:49:10 fedora fail2ban-server[4084]: 2026-07-12 18:49:10,212 fail2ban                [4084]: ERROR   Failed during configuration: Have not found any log file for docker jail
Jul 12 18:49:10 fedora fail2ban-server[4084]: 2026-07-12 18:49:10,218 fail2ban                [4084]: ERROR   Async configuration of server failed
Jul 12 18:49:10 fedora systemd[1]: fail2ban.service: Main process exited, code=exited, status=255/EXCEPTION
Jul 12 18:49:10 fedora systemd[1]: fail2ban.service: Failed with result 'exit-code'.

---
Report generated: Mon Jul 13 09:01:26 AM PKT 2026
