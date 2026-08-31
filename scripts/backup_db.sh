#!/usr/bin/env bash
# ==============================================================================
# VisionGate / Attenda - PostgreSQL Database Backup Script
# ==============================================================================
set -e

BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "${BACKUP_DIR}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/attenda_db_backup_${TIMESTAMP}.sql.gz"

echo "Creating PostgreSQL backup from 'attenda-postgres' container..."
docker exec -t attenda-postgres pg_dump -U attenda -d attenda --clean --if-exists | gzip > "${BACKUP_FILE}"

echo "Backup completed successfully: ${BACKUP_FILE}"
ls -lh "${BACKUP_FILE}"
