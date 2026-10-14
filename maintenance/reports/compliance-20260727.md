=== Compliance Report - 20260727 ===

## Backup Status
- Last database backup: neo4j_backup_20260727_043642.tar.gz
- Last full backup: 
- Backup size: 11M

## Security Status
- Fail2Ban status: not running
- AIDE last check: 
- Running containers: 2

## System Health
- Uptime: up 3 hours, 24 minutes
- CPU: 68.2% used
- Memory: 9.8Gi/15Gi
- Disk: 35% used

## Monitoring Status
- prometheus: NOT RUNNING
- grafana: NOT RUNNING
- alertmanager: NOT RUNNING

## Recent Security Events (24h)
-- Boot 6b7795b186004180855b368746a1fc45 --
Jul 26 23:29:48 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Jul 26 23:29:48 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Jul 26 23:29:49 fedora fail2ban-server[12758]: 2026-07-26 23:29:49,286 fail2ban.configreader   [12758]: ERROR   Found no accessible config files for 'filter.d/sshd-ddos' under /etc/fail2ban
Jul 26 23:29:49 fedora fail2ban-server[12758]: 2026-07-26 23:29:49,286 fail2ban.jailreader     [12758]: ERROR   Unable to read the filter 'sshd-ddos'
Jul 26 23:29:49 fedora fail2ban-server[12758]: 2026-07-26 23:29:49,287 fail2ban.jailsreader    [12758]: ERROR   Errors in jail 'sshd-ddos'. Skipping...
Jul 26 23:29:49 fedora fail2ban-server[12758]: 2026-07-26 23:29:49,304 fail2ban                [12758]: ERROR   Failed during configuration: Have not found any log file for docker jail
Jul 26 23:29:49 fedora fail2ban-server[12758]: 2026-07-26 23:29:49,308 fail2ban                [12758]: ERROR   Async configuration of server failed
Jul 26 23:29:49 fedora systemd[1]: fail2ban.service: Main process exited, code=exited, status=255/EXCEPTION
Jul 26 23:29:49 fedora systemd[1]: fail2ban.service: Failed with result 'exit-code'.
-- Boot f47fc542ac484b23b4da73fb07f0f573 --
Jul 27 04:36:41 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Jul 27 04:36:41 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Jul 27 04:36:41 fedora fail2ban-server[2040]: 2026-07-27 04:36:41,907 fail2ban.configreader   [2040]: ERROR   Found no accessible config files for 'filter.d/sshd-ddos' under /etc/fail2ban
Jul 27 04:36:41 fedora fail2ban-server[2040]: 2026-07-27 04:36:41,907 fail2ban.jailreader     [2040]: ERROR   Unable to read the filter 'sshd-ddos'
Jul 27 04:36:41 fedora fail2ban-server[2040]: 2026-07-27 04:36:41,907 fail2ban.jailsreader    [2040]: ERROR   Errors in jail 'sshd-ddos'. Skipping...
Jul 27 04:36:41 fedora fail2ban-server[2040]: 2026-07-27 04:36:41,929 fail2ban                [2040]: ERROR   Failed during configuration: Have not found any log file for docker jail
Jul 27 04:36:41 fedora fail2ban-server[2040]: 2026-07-27 04:36:41,938 fail2ban                [2040]: ERROR   Async configuration of server failed
Jul 27 04:36:41 fedora systemd[1]: fail2ban.service: Main process exited, code=exited, status=255/EXCEPTION
Jul 27 04:36:41 fedora systemd[1]: fail2ban.service: Failed with result 'exit-code'.

---
Report generated: Mon Jul 27 08:00:03 AM PKT 2026
