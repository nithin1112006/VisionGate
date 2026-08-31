#!/usr/bin/env bash
# ==============================================================================
# VisionGate / Attenda - PostgreSQL Database Restore Script
# Usage: ./scripts/restore_db.sh <path_to_backup_file.sql.gz>
# ==============================================================================
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_backup.sql.gz>"
    echo "Example: $0 ./backups/attenda_db_backup_20260831_120000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Error: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "WARNING: This operation will restore database 'attenda' from ${BACKUP_FILE}."
read -p "Are you sure you want to proceed? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Restore aborted."
    exit 0
fi

echo "Restoring database into 'attenda-postgres' container..."
gunzip -c "${BACKUP_FILE}" | docker exec -i attenda-postgres psql -U attenda -d attenda

echo "Database restored successfully."
