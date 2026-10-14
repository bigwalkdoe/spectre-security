#!/bin/bash
# Automated PostgreSQL vacuum and analyze
set -euo pipefail

LOG_FILE="/var/log/pg-vacuum.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "==========================================" >> "$LOG_FILE"
echo "PostgreSQL Maintenance - $DATE" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

# Get list of databases
DATABASES=$(docker exec guardrail-ai-postgres-1 psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)

for db in $DATABASES; do
    echo "Processing database: $db" >> "$LOG_FILE"
    
    # Analyze (update statistics)
    echo "  Running ANALYZE..." >> "$LOG_FILE"
    docker exec guardrail-ai-postgres-1 psql -U postgres -d "$db" -c "ANALYZE;" >> "$LOG_FILE" 2>&1
    
    # Vacuum (reclaim storage)
    echo "  Running VACUUM..." >> "$LOG_FILE"
    docker exec guardrail-ai-postgres-1 psql -U postgres -d "$db" -c "VACUUM (ANALYZE, VERBOSE);" >> "$LOG_FILE" 2>&1
    
    # Reindex
    echo "  Running REINDEX..." >> "$LOG_FILE"
    docker exec guardrail-ai-postgres-1 psql -U postgres -d "$db" -c "REINDEX DATABASE $db;" >> "$LOG_FILE" 2>&1
done

# Check for bloat
echo "" >> "$LOG_FILE"
echo "Table bloat check:" >> "$LOG_FILE"
docker exec guardrail-ai-postgres-1 psql -U postgres -t -c "
SELECT
    schemaname || '.' || relname as table_name,
    pg_size_pretty(pg_total_relation_size(relid)) as total_size,
    n_dead_tup as dead_tuples,
    n_live_tup as live_tuples,
    CASE WHEN n_live_tup > 0
        THEN round(n_dead_tup::numeric / n_live_tup * 100, 2)
        ELSE 0
    END as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 10;" >> "$LOG_FILE" 2>&1

echo "PostgreSQL vacuum/analyze completed: $DATE" >> "$LOG_FILE"
logger -p user.info "PostgreSQL vacuum/analyze completed"
