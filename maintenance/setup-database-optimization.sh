#!/bin/bash
# Database Optimization Setup
# - Automated vacuum/analyze for PostgreSQL
# - Connection pooling (PgBouncer)
# - Read replicas
set -euo pipefail

echo "=== Database Optimization Setup ==="
echo ""

# 1. PostgreSQL Automated Vacuum/Analyze
setup_vacuum() {
    echo "[1/3] Setting up PostgreSQL automated vacuum/analyze..."
    
    cat > /home/deon/scripts/performance/pg-vacuum.sh << 'VACUUM'
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
VACUUM
    chmod +x /home/deon/scripts/performance/pg-vacuum.sh
    echo "  Vacuum script created"

    # Add to cron - run daily at 2:30 AM
    if ! crontab -l 2>/dev/null | grep -q "pg-vacuum"; then
        (crontab -l 2>/dev/null
         echo "# PostgreSQL vacuum/analyze - Daily at 2:30 AM"
         echo "30 2 * * * /home/deon/scripts/performance/pg-vacuum.sh"
        ) | crontab -
        echo "  Vacuum scheduled daily at 2:30 AM"
    fi
}

# 2. PgBouncer Connection Pooling
setup_pgbouncer() {
    echo "[2/3] Setting up PgBouncer connection pooling..."
    
    mkdir -p /home/deon/scripts/performance/pgbouncer
    
    # Create PgBouncer config
    cat > /home/deon/scripts/performance/pgbouncer/pgbouncer.ini << 'PGBOUNCER'
[databases]
guardrail = host=postgres port=5432 dbname=guardrail
postgres = host=postgres port=5432 dbname=postgres

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

# Pool settings
pool_mode = transaction
default_pool_size = 25
max_client_conn = 100
max_db_connections = 50
idle_transaction_timeout = 300

# Resource limits
reserve_pool_size = 5
reserve_pool_timeout = 3.0
server_idle_timeout = 600

# Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
stats_period = 60

# Timeouts
query_timeout = 30
query_wait_timeout = 10
client_idle_timeout = 600
PGBOUNCER

    # Create userlist
    cat > /home/deon/scripts/performance/pgbouncer/userlist.txt << 'USERLIST'
"postgres" "postgres"
USERLIST

    # Create Docker Compose for PgBouncer
    cat > /home/deon/scripts/performance/pgbouncer/docker-compose.yml << 'PG_COMPOSE'
services:
  pgbouncer:
    image: bitnami/pgbouncer:latest
    container_name: pgbouncer
    ports:
      - "6432:6432"
    environment:
      - POSTGRESQL_HOST=postgres
      - POSTGRESQL_PORT=5432
      - POSTGRESQL_USERNAME=postgres
      - POSTGRESQL_PASSWORD=${DB_PASSWORD:-postgres}
      - PGBOUNCER_POOL_MODE=transaction
      - PGBOUNCER_DEFAULT_POOL_SIZE=25
      - PGBOUNCER_MAX_CLIENT_CONN=100
      - PGBOUNCER_IGNORE_STARTUP_PARAMETERS=extra_float_digits
    restart: unless-stopped
    networks:
      - monitoring
PG_COMPOSE
    echo "  PgBouncer configuration created at $HOME/scripts/performance/pgbouncer/"
    echo "  Start with: docker-compose -f pgbouncer/docker-compose.yml up -d"
    echo "  Connect via: psql -h localhost -p 6432 -U postgres -d guardrail"
}

# 3. Read Replica Setup
setup_replicas() {
    echo "[3/3] Creating read replica setup..."
    
    cat > /home/deon/scripts/performance/setup-read-replica.sh << 'REPLICA'
#!/bin/bash
# PostgreSQL Read Replica Setup
set -euo pipefail

echo "=== PostgreSQL Read Replica Setup ==="

PRIMARY_HOST="${1:-postgres}"
REPLICA_NAME="${2:-postgres-replica}"

# Create replica configuration
docker exec "$PRIMARY_HOST" psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator';" 2>/dev/null || true

docker exec "$PRIMARY_HOST" bash -c 'cat >> /var/lib/postgresql/data/postgresql.conf << "EOF"
wal_level = replica
max_wal_senders = 3
wal_keep_size = 1024
EOF'

docker exec "$PRIMARY_HOST" bash -c 'cat > /var/lib/postgresql/data/pg_hba.conf << "EOF"
host replication replicator 0.0.0.0/0 md5
EOF'

docker exec "$PRIMARY_HOST" psql -U postgres -c "SELECT pg_reload_conf();"

echo ""
echo "To create the replica container, run:"
echo ""
echo "docker run -d \\"
echo "  --name $REPLICA_NAME \\"
echo "  -e POSTGRES_USER=postgres \\"
echo "  -e POSTGRES_PASSWORD=postgres \\"
echo "  -e POSTGRES_DB=postgres \\"
echo "  --network=monitoring \\"
echo "  postgres:latest"
echo ""
echo "Then in the replica:"
echo "  pg_basebackup -h $PRIMARY_HOST -D /var/lib/postgresql/data -U replicator -P -v"
REPLICA
    chmod +x /home/deon/scripts/performance/setup-read-replica.sh
    echo "  Read replica setup script created"
}

# Run all
setup_vacuum
echo ""
setup_pgbouncer
echo ""
setup_replicas

echo ""
echo "=== Database Optimization Setup Complete ==="
echo ""
echo "Components:"
echo "  - Automated vacuum/analyze (daily at 2:30 AM)"
echo "  - PgBouncer connection pool (port 6432)"
echo "  - Read replica setup script"
echo ""
echo "Next steps:"
echo "  1. Start PgBouncer: docker-compose -f pgbouncer/docker-compose.yml up -d"
echo "  2. Update app configs to use localhost:6432 instead of localhost:5432"
echo "  3. For read replicas: /home/deon/scripts/performance/setup-read-replica.sh"
