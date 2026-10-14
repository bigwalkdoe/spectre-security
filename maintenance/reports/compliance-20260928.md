=== Compliance Report - 20260928 ===

## Backup Status
- Last database backup: neo4j_backup_20260928_020002.tar.gz
- Last full backup: modelink-security_pgdata_20260928_030000.tar.gz
- Backup size: 50G

## Security Status
- Fail2Ban status: Status
- AIDE last check: 
- Running containers: 56

## System Health
- Uptime: up 9 hours, 30 minutes
- CPU: 7.0% used
- Memory: 8.7Gi/15Gi
- Disk: 83% used

## Monitoring Status
- prometheus: Running
- grafana: Running
- alertmanager: NOT RUNNING

## Recent Security Events (24h)
Sep 27 17:06:55 fedora systemd[1]: Stopping fail2ban.service - Fail2Ban Service...
Sep 27 17:06:56 fedora fail2ban-client[1972829]: Shutdown successful
Sep 27 17:06:56 fedora systemd[1]: fail2ban.service: Deactivated successfully.
Sep 27 17:06:56 fedora systemd[1]: Stopped fail2ban.service - Fail2Ban Service.
Sep 27 17:06:56 fedora systemd[1]: fail2ban.service: Consumed 2min 22.826s CPU time over 15h 48min 31.361s wall clock time, 39.5M memory peak, 4.3M memory swap peak.
-- Boot 2508f6e45bd64e0a8d84e9aeaab81fdf --
Sep 27 22:30:36 fedora systemd[1]: Starting fail2ban.service - Fail2Ban Service...
Sep 27 22:30:36 fedora systemd[1]: Started fail2ban.service - Fail2Ban Service.
Sep 27 22:30:37 fedora fail2ban-server[1839]: 2026-09-27 22:30:37,112 fail2ban.configreader   [1839]: ERROR   Found no accessible config files for 'filter.d/nginx-limit' under /etc/fail2ban
Sep 27 22:30:37 fedora fail2ban-server[1839]: 2026-09-27 22:30:37,113 fail2ban.jailreader     [1839]: ERROR   Unable to read the filter 'nginx-limit'
Sep 27 22:30:37 fedora fail2ban-server[1839]: 2026-09-27 22:30:37,113 fail2ban.jailsreader    [1839]: ERROR   Errors in jail 'nginx-limit'. Skipping...
Sep 27 22:30:37 fedora fail2ban-server[1839]: Server ready

---
Report generated: Mon Sep 28 08:00:02 AM PKT 2026
