#!/usr/bin/env bash
# Restore script for the localcosmos-docker LIVE containers.
# Restores from backup sets stored locally by backup.sh.
# Restores:
#   1. lc-database PostgreSQL dump
#   2. lc-appkit media and published apps directories
# Staging and testing containers are not covered by this script.
#
# ============================================================
# FULL RESTORE ON A BLANK SYSTEM — run these steps in order
# ============================================================
#
# This script only restores DATA. The Docker environment must
# exist before running it. On a blank server:
#
# Step 1 — Install Docker
#   Follow https://docs.docker.com/engine/install/
#
# Step 2 — Copy this repository to the new server
#   git clone <your-repo-url> localcosmos-docker
#   cd localcosmos-docker
#
# Step 3 — Build the images, as shown below or better: use jenkins jobs as usual for localcosmos installations
#   docker build -t lc-database  ./lc-database/
#   docker build -t lc-appkit    ./lc-appkit/
#   docker build -t lc-taxonomy  ./lc-taxonomy/
#
# Step 4 — Start the containers
#   Start them the same way you normally deploy (docker run /
#   docker compose up). This creates the volumes and initialises
#   an empty PostgreSQL cluster inside lc-database.
#   The lc-database container must be running before Step 6.
#
# Step 5 — Copy backup files from the backup machine to this server
#   rsync -az <BACKUP_USER>@<BACKUP_HOST>:<BACKUP_DIR>/ /var/backups/localcosmos/
#
# Step 6 — Run this script
#   ./restore.sh --list             # see what backups are available
#   ./restore.sh --latest           # restore the most recent backup
#   ./restore.sh <timestamp>        # or restore a specific one
#
# Step 7 — Restart the appkit container
#   Restart lc-appkit so the application picks up the restored files.
#   docker restart lc-appkit
#
# ============================================================
#
# DATA-ONLY RESTORE (containers already running, e.g. accidental
# data deletion):
#   ./restore.sh --latest
#   docker restart lc-appkit
#
# Usage:
#   ./restore.sh <timestamp>            # e.g. 2026-10-19T02-00-00Z
#   ./restore.sh --list                 # list locally available backups
#   ./restore.sh --latest               # restore the most recent local backup
#   ./restore.sh <timestamp> --dry-run
#
# ---------------------------------------------------------------------------
# Environment variables (override the defaults below, e.g. via Jenkins credentials)
# ---------------------------------------------------------------------------
#   LC_DB_CONTAINER              Name of the live lc-database container
#   LC_APPKIT_CONTAINER_PATTERN  Pattern to match the live lc-appkit container name
#   LC_DB_USER                   PostgreSQL superuser (must match POSTGRES_USER in compose)
#   LC_DB_NAME                   Database name to restore into
#   LC_LOCAL_BACKUP_DIR          Local directory where backup sets are stored (must match backup.sh)
# ---------------------------------------------------------------------------

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — defaults used when environment variables are not set
# ---------------------------------------------------------------------------

# Live container names (as shown by `docker ps`)
# lc-database uses an explicit container_name in the compose file
DB_CONTAINER="${LC_DB_CONTAINER:-lc-database-live}"
# lc-appkit is named by docker compose as <project>-lc-appkit-<n>; resolved at runtime
APPKIT_CONTAINER_PATTERN="${LC_APPKIT_CONTAINER_PATTERN:-localcosmosorg-lc-appkit-*}"

# Must match POSTGRES_USER in the compose env
DB_USER="${LC_DB_USER:-localcosmos}"
DB_NAME="${LC_DB_NAME:-localcosmos}"

# Must match LC_LOCAL_BACKUP_DIR in backup.sh
LOCAL_BACKUP_DIR="${LC_LOCAL_BACKUP_DIR:-/var/backups/localcosmos}"

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

DRY_RUN=false
TIMESTAMP=""

usage() {
    echo "Usage:"
    echo "  $0 --list                  List locally available backups"
    echo "  $0 --latest                Restore the most recent local backup"
    echo "  $0 <timestamp>             Restore a specific backup"
    echo "  $0 <timestamp> --dry-run   Show what would be done without doing it"
    exit 1
}

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then usage; fi

case "${1:-}" in
    --list)
        echo "Available backups in $LOCAL_BACKUP_DIR:"
        ls -1 "$LOCAL_BACKUP_DIR" | sort
        exit 0
        ;;
    --latest)
        TIMESTAMP=$(ls -1 "$LOCAL_BACKUP_DIR" | sort | tail -n1)
        if [[ -z "$TIMESTAMP" ]]; then
            echo "Error: no backups found in $LOCAL_BACKUP_DIR" >&2
            exit 1
        fi
        log "Latest backup: $TIMESTAMP"
        ;;
    --*)
        usage
        ;;
    *)
        TIMESTAMP="$1"
        ;;
esac

if [[ "${2:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[dry-run] No changes will be made."
fi

BACKUP_DIR="$LOCAL_BACKUP_DIR/$TIMESTAMP"
DB_DUMP_FILE="$BACKUP_DIR/lc-database-${TIMESTAMP}.sql.gz"
APPKIT_ARCHIVE="$BACKUP_DIR/lc-appkit-${TIMESTAMP}.tar.gz"

# Resolve the appkit container name from the pattern at runtime
APPKIT_CONTAINER=$(docker ps --format '{{.Names}}' | grep -m1 "${APPKIT_CONTAINER_PATTERN//\*/}" || true)
[[ -n "$APPKIT_CONTAINER" ]] || { echo "Error: no running container matching '$APPKIT_CONTAINER_PATTERN'" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Verify backup files exist
# ---------------------------------------------------------------------------
if ! $DRY_RUN; then
    [[ -d "$BACKUP_DIR" ]]      || { echo "Error: backup set not found: $BACKUP_DIR" >&2; exit 1; }
    [[ -f "$DB_DUMP_FILE" ]]    || { echo "Error: DB dump not found: $DB_DUMP_FILE" >&2; exit 1; }
    [[ -f "$APPKIT_ARCHIVE" ]]  || { echo "Error: Appkit archive not found: $APPKIT_ARCHIVE" >&2; exit 1; }
    log "Manifest:"
    cat "$BACKUP_DIR/MANIFEST.txt" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 3. Restore PostgreSQL database
# ---------------------------------------------------------------------------
log "Restoring PostgreSQL database '$DB_NAME' into container '$DB_CONTAINER' ..."

if $DRY_RUN; then
    echo "[dry-run] gunzip -c $DB_DUMP_FILE | docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME"
else
    # Ensure the target database exists before restoring
    docker exec "$DB_CONTAINER" \
        psql -U "$DB_USER" -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" \
        | grep -q 1 \
        || docker exec "$DB_CONTAINER" createdb -U "$DB_USER" "$DB_NAME"

    # Plain SQL dump restores with psql, no pg_restore needed
    gunzip -c "$DB_DUMP_FILE" \
        | docker exec -i "$DB_CONTAINER" \
            psql -U "$DB_USER" -d "$DB_NAME"

    log "Database restored."
fi

# ---------------------------------------------------------------------------
# 4. Restore appkit media and apps
# ---------------------------------------------------------------------------
log "Restoring appkit files into container '$APPKIT_CONTAINER' ..."

if $DRY_RUN; then
    echo "[dry-run] docker run --rm --volumes-from $APPKIT_CONTAINER -v $BACKUP_DIR:/backup alpine tar xzf /backup/$(basename "$APPKIT_ARCHIVE") -C /"
else
    # Throwaway alpine container writes to the volumes directly; works even if the appkit container is stopped
    docker run --rm \
        --volumes-from "$APPKIT_CONTAINER" \
        -v "$BACKUP_DIR:/backup" \
        alpine \
        tar xzf "/backup/$(basename "$APPKIT_ARCHIVE")" -C /
    log "Appkit files restored."
fi

log "Restore finished successfully from backup: $TIMESTAMP"
