=== Cloud Cost Report - 20260713 ===

## Docker Resource Usage
CONTAINER ID   NAME                             CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
1eff321d00ae   modelink-staging-control-plane   20.09%    679.9MiB / 15.27GiB   4.35%     16.8MB / 117MB    87.8GB / 15.6GB   262
9d7f7fe89eb8   modelink-staging-worker          10.94%    780.6MiB / 15.27GiB   4.99%     132MB / 22.7MB    86.9GB / 2.5GB    596
a1b52f0325c2   guardrail-ai-frontend-1          0.00%     3.012MiB / 15.27GiB   0.02%     369kB / 126B      7MB / 5.95MB      9
c24898810217   loki                             1.05%     57.17MiB / 15.27GiB   0.37%     390kB / 26.7kB    1.45GB / 34.2MB   14
693c147f564e   grafana-logging                  0.43%     86.01MiB / 15.27GiB   0.55%     636kB / 143kB     897MB / 345MB     18
0f8ce001d32f   promtail                         0.80%     19.14MiB / 15.27GiB   0.12%     370kB / 2.1kB     574MB / 258MB     12
a2cad45e355f   guardrail-ai-celery-worker-1     0.18%     19.55MiB / 15.27GiB   0.13%     7.72MB / 7.21MB   46.4MB / 382MB    9
ae58a54cdc7f   guardrail-ai-celery-beat-1       0.00%     14.62MiB / 15.27GiB   0.09%     705kB / 788kB     91.2MB / 82.2MB   1
31f6393124c5   guardrail-ai-grafana-1           0.52%     92.7MiB / 15.27GiB    0.59%     638kB / 141kB     1.73GB / 329MB    17
44a6da1ffb4b   guardrail-postgres-exporter      0.00%     14.32MiB / 15.27GiB   0.09%     368kB / 126B      222MB / 1.62MB    11
d6a6444eef15   guardrail-redis-exporter         0.00%     5.617MiB / 15.27GiB   0.04%     368kB / 126B      52.6MB / 1.36MB   10
02e616ee31e7   guardrail-ai-postgres-1          0.00%     4.711MiB / 15.27GiB   0.03%     369kB / 126B      229MB / 13.9MB    6
24cb9bb40f0e   guardrail-ai-rabbitmq-1          0.35%     39.98MiB / 15.27GiB   0.26%     7.98MB / 7.39MB   462MB / 252MB     40
2cdd7d86b44b   guardrail-ai-redis-1             1.25%     10.29MiB / 15.27GiB   0.07%     751kB / 305kB     120MB / 7.72MB    6
9575fe291cf6   guardrail-alertmanager           0.09%     13.21MiB / 15.27GiB   0.08%     369kB / 126B      256MB / 7.95MB    10
77b050e00344   guardrail-cadvisor               16.66%    231.3MiB / 15.27GiB   1.48%     368kB / 126B      582MB / 47.8MB    191
59fdf4ed9e83   guardrail-node-exporter          0.00%     740KiB / 15.27GiB     0.00%     369kB / 126B      25.7MB / 2.38MB   6

## Disk Usage by Directory
24M	/home/deon/scripts/
292K	/backups/
1.7G	/var/log/
