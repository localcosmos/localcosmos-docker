#!/usr/bin/env bash
# Backup script for the localcosmos-docker LIVE containers.
# Backs up:
#   1. lc-database PostgreSQL dump (app data)
#   2. lc-appkit media and published apps directories
# The lc-taxonomy database is read-only and restored from its source SQL dump,
# so it is intentionally excluded.
# Staging and testing containers are not covered by this script.
#
# Backup sets are stored LOCALLY on this server.
# The target (backup) machine pulls them via pull-backup.sh.
#
# Usage:
#   ./backup.sh [--dry-run]
#
# Prerequisites:
#   - The Docker containers must be running for the database dump step
#
# ---------------------------------------------------------------------------
# Environment variables (override the defaults below, e.g. via Jenkins credentials)
# ---------------------------------------------------------------------------
#   LC_DB_CONTAINER              Name of the live lc-database container
#   LC_APPKIT_CONTAINER_PATTERN  Pattern to match the live lc-appkit container name
#   LC_DB_USER                   PostgreSQL superuser (must match POSTGRES_USER in compose)
#   LC_DB_NAME                   Database name to dump (empty = dump all)
#   LC_LOCAL_BACKUP_DIR          Local directory where backup sets are stored
#   LC_RETENTION_DAYS            Number of daily backup sets to keep locally
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

# PostgreSQL credentials inside lc-database (must match POSTGRES_USER in compose env)
DB_USER="${LC_DB_USER:-localcosmos}"
DB_NAME="${LC_DB_NAME:-localcosmos}"      # set to empty string "" to dump ALL databases

# Local directory where backup sets are permanently stored (must have enough free space)
LOCAL_BACKUP_DIR="${LC_LOCAL_BACKUP_DIR:-/var/backups/localcosmos}"

# Number of daily backup sets to keep locally
RETENTION_DAYS="${LC_RETENTION_DAYS:-7}"

# Directories to snapshot from the appkit volumes.
# www volume              → /var/www/localcosmos      (media, served apps, static)
# apps volume             → /opt/apps                 (app kit source/build files)
# private_frontends volume → /opt/localcosmos_frontends
# Static files under /var/www/localcosmos/static can be regenerated with
# collectstatic, but are included here to make restore self-contained.
APPKIT_DIRS=(
    "/var/www/localcosmos"
    "/opt/apps"
    "/opt/localcosmos_frontends"
)

# ---------------------------------------------------------------------------
# Internals — no need to edit below this line
# ---------------------------------------------------------------------------

TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
BACKUP_DIR="$LOCAL_BACKUP_DIR/$TIMESTAMP"
DRY_RUN=false

# Resolve the appkit container name from the pattern at runtime
APPKIT_CONTAINER=$(docker ps --format '{{.Names}}' | grep -m1 "${APPKIT_CONTAINER_PATTERN//\*/}" || true)
[[ -n "$APPKIT_CONTAINER" ]] || { echo "Error: no running container matching '$APPKIT_CONTAINER_PATTERN'" >&2; exit 1; }

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
# 1. Create backup directory
# ---------------------------------------------------------------------------
log "Creating backup directory: $BACKUP_DIR"
run mkdir -p "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# 2. Dump PostgreSQL database from lc-database container
# ---------------------------------------------------------------------------
log "Dumping PostgreSQL database '$DB_NAME' from container '$DB_CONTAINER' ..."

DB_DUMP_FILE="$BACKUP_DIR/lc-database-${TIMESTAMP}.sql.gz"

if $DRY_RUN; then
    echo "[dry-run] docker exec $DB_CONTAINER pg_dump -U $DB_USER $DB_NAME | gzip > $DB_DUMP_FILE"
else
    if [[ -z "$DB_NAME" ]]; then
        docker exec "$DB_CONTAINER" pg_dumpall -U "$DB_USER" \
            | gzip > "$DB_DUMP_FILE"
    else
        # -Fp = plain SQL; --clean adds DROP statements so restore overwrites existing data cleanly
        docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -Fp --clean --if-exists "$DB_NAME" \
            | gzip > "$DB_DUMP_FILE"
    fi
    log "Database dump written to $DB_DUMP_FILE ($(du -sh "$DB_DUMP_FILE" | cut -f1))"
fi

# ---------------------------------------------------------------------------
# 3. Archive appkit directories (media, apps)
# ---------------------------------------------------------------------------
log "Archiving appkit directories from container '$APPKIT_CONTAINER' ..."

APPKIT_ARCHIVE="$BACKUP_DIR/lc-appkit-${TIMESTAMP}.tar.gz"

if $DRY_RUN; then
    echo "[dry-run] docker run --rm <ro-mounts> alpine tar czf - ${APPKIT_DIRS[*]} > $APPKIT_ARCHIVE"
else
    # Mount each volume read-only; unlike --volumes-from this enforces no-write at the kernel level
    RO_MOUNTS=()
    while read -r src dst; do
        [[ -n "$src" ]] && RO_MOUNTS+=(-v "$src:$dst:ro")
    done < <(docker inspect --format \
        '{{range .Mounts}}{{.Source}} {{.Destination}}{{"\n"}}{{end}}' \
        "$APPKIT_CONTAINER")

    docker run --rm \
        "${RO_MOUNTS[@]}" \
        alpine \
        tar czf - "${APPKIT_DIRS[@]}" \
        > "$APPKIT_ARCHIVE"
    log "Appkit archive written to $APPKIT_ARCHIVE ($(du -sh "$APPKIT_ARCHIVE" | cut -f1))"
fi

# ---------------------------------------------------------------------------
# 4. Write a manifest
# ---------------------------------------------------------------------------
MANIFEST="$BACKUP_DIR/MANIFEST.txt"
log "Writing manifest ..."
run bash -c "cat > '$MANIFEST' <<EOF
backup_timestamp: $TIMESTAMP
db_container:     $DB_CONTAINER
db_name:          ${DB_NAME:-ALL}
appkit_container: $APPKIT_CONTAINER
appkit_dirs:      ${APPKIT_DIRS[*]}
host:             $(hostname -f 2>/dev/null || hostname)
EOF"

# ---------------------------------------------------------------------------
# 5. Prune old local backup sets
# ---------------------------------------------------------------------------
log "Pruning backup sets older than $RETENTION_DAYS days in $LOCAL_BACKUP_DIR ..."

if $DRY_RUN; then
    echo "[dry-run] find $LOCAL_BACKUP_DIR -maxdepth 1 -mindepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} +"
else
    find "$LOCAL_BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} +
    echo "Pruning done."
fi

log "Backup finished successfully: $TIMESTAMP"

