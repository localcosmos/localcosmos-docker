#!/usr/bin/env bash
# Pull backup script — runs on the TARGET (backup) machine.
# Downloads backup sets from the source server via HTTPS (nginx with basic auth).
# Handles local retention.
#
# Usage:
#   ./pull-backup.sh [--dry-run]
#
# Prerequisites on the backup machine:
#   - wget installed
#
# ---------------------------------------------------------------------------
# Environment variables (override the defaults below, e.g. via Jenkins credentials)
# ---------------------------------------------------------------------------
#   LC_SOURCE_HOST        Hostname of the source server
#   LC_BACKUP_HTTP_USER   HTTP basic auth username (set in nginx htpasswd)
#   LC_BACKUP_HTTP_PASS   HTTP basic auth password
#   LC_BACKUP_HTTP_PATH   URL path where backups are served (default: /backups/)
#   LC_LOCAL_BACKUP_DIR   Local directory on this machine where pulled backups are stored
#   LC_RETENTION_DAYS     Number of daily backup sets to keep locally
# ---------------------------------------------------------------------------

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — defaults used when environment variables are not set
# ---------------------------------------------------------------------------

SOURCE_HOST="${LC_SOURCE_HOST:-geomar.dev}"
BACKUP_HTTP_USER="${LC_BACKUP_HTTP_USER:-backupuser}"
BACKUP_HTTP_PASS="${LC_BACKUP_HTTP_PASS:-}"
BACKUP_HTTP_PATH="${LC_BACKUP_HTTP_PATH:-/backups/}"

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
# 1. Pull backup sets from source server via HTTPS
# ---------------------------------------------------------------------------
log "Pulling backups from https://$SOURCE_HOST$BACKUP_HTTP_PATH ..."

run mkdir -p "$LOCAL_BACKUP_DIR"

# --timestamping skips files already present locally with the same modification time
# --reject=index.html prevents saving the nginx autoindex page
run wget \
    --recursive \
    --no-parent \
    --no-host-directories \
    --cut-dirs=1 \
    --timestamping \
    --reject=index.html \
    --http-user="$BACKUP_HTTP_USER" \
    --http-password="$BACKUP_HTTP_PASS" \
    --directory-prefix="$LOCAL_BACKUP_DIR" \
    "https://$SOURCE_HOST$BACKUP_HTTP_PATH"

log "Pull complete."

# ---------------------------------------------------------------------------
# 2. Prune old local backup sets
# ---------------------------------------------------------------------------
log "Pruning backup sets older than $RETENTION_DAYS days in $LOCAL_BACKUP_DIR ..."

# Prune by the timestamp in the directory name, not local mtime.
# mtime-based pruning would delete all sets after RETENTION_DAYS of source silence.
CUTOFF=$(date -u -d "$RETENTION_DAYS days ago" +"%Y-%m-%dT%H-%M-%SZ")

while IFS= read -r -d '' dir; do
    name=$(basename "$dir")
    if [[ "$name" < "$CUTOFF" ]]; then
        if $DRY_RUN; then
            echo "[dry-run] rm -rf $dir"
        else
            rm -rf "$dir"
        fi
    fi
done < <(find "$LOCAL_BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d -print0)

if ! $DRY_RUN; then
    echo "Pruning done."
fi

log "Pull finished successfully."
