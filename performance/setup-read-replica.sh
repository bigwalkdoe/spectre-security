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
