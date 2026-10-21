#!/usr/bin/env bash
# Pull backup script — runs on the TARGET (backup) machine.
# SSHes into the source server and rsyncs backup sets to local storage.
# Handles local retention.
#
# This script runs on the backup machine because the source server
# cannot SSH into the backup machine (VPN restriction).
#
# Usage:
#   ./pull-backup.sh [--dry-run]
#
# Prerequisites on the backup machine:
#   - SSH key-based auth to the source server (LC_SOURCE_HOST)
#   - rsync installed
#
# ---------------------------------------------------------------------------
# Environment variables (override the defaults below, e.g. via Jenkins credentials)
# ---------------------------------------------------------------------------
#   LC_SOURCE_USER        SSH user on the source (live) server
#   LC_SOURCE_HOST        Hostname or IP of the source server
#   LC_SOURCE_BACKUP_DIR  Path of the local backup dir on the source server (must match LC_LOCAL_BACKUP_DIR in backup.sh)
#   LC_LOCAL_BACKUP_DIR   Local directory on this machine where pulled backups are stored
#   LC_RETENTION_DAYS     Number of daily backup sets to keep locally
# ---------------------------------------------------------------------------

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — defaults used when environment variables are not set
# ---------------------------------------------------------------------------

SOURCE_USER="${LC_SOURCE_USER:-backupuser}"
SOURCE_HOST="${LC_SOURCE_HOST:-live.example.com}"
SOURCE_BACKUP_DIR="${LC_SOURCE_BACKUP_DIR:-/var/backups/localcosmos}"

LOCAL_BACKUP_DIR="${LC_LOCAL_BACKUP_DIR:-/var/backups/localcosmos}"
RETENTION_DAYS="${LC_RETENTION_DAYS:-7}"

# ---------------------------------------------------------------------------
# Internals — no need to edit below this line
# ---------------------------------------------------------------------------

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[dry-run] No files will be written."
fi

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# 1. Pull backup sets from source server
# ---------------------------------------------------------------------------
log "Pulling backups from $SOURCE_USER@$SOURCE_HOST:$SOURCE_BACKUP_DIR ..."

run mkdir -p "$LOCAL_BACKUP_DIR"

run rsync \
    --archive \
    --compress \
    --human-readable \
    --progress \
    --mkpath \
    "$SOURCE_USER@$SOURCE_HOST:$SOURCE_BACKUP_DIR/" \
    "$LOCAL_BACKUP_DIR/"

log "Pull complete."

# ---------------------------------------------------------------------------
# 2. Prune old local backup sets
# ---------------------------------------------------------------------------
log "Pruning backup sets older than $RETENTION_DAYS days in $LOCAL_BACKUP_DIR ..."

if $DRY_RUN; then
    echo "[dry-run] find $LOCAL_BACKUP_DIR -maxdepth 1 -mindepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} +"
else
    find "$LOCAL_BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} +
    echo "Pruning done."
fi

log "Pull finished successfully."
