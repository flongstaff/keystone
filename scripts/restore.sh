#!/usr/bin/env bash
# restore.sh — Restore all runtime configurations from backup
#
# USAGE:
#   ./restore.sh [--dry-run] [--target claude|pi|opencode|all]
#
# ROLLBACK:
#   This IS the rollback script. Re-run to restore again.

set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
TARGET="all"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n) DRY_RUN=true ;;
    --target)     [[ $# -lt 2 ]] && echo "ERROR: --target requires a value" >&2 && exit 1; TARGET="$2"; shift ;;
    --help|-h)    echo "Usage: $0 [--dry-run] [--target claude|pi|opencode|all]"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
  shift
done

run() {
  if $DRY_RUN; then
    echo "[DRY RUN] $*"
  else
    "$@"
  fi
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

case "$TARGET" in
  all|claude|pi|opencode) ;;
  *) echo "ERROR: Unknown target '$TARGET'. Valid targets: claude, pi, opencode, all" >&2; exit 1 ;;
esac

validate_source() {
  local dir="$1" label="$2"
  if [[ ! -d "$dir" ]]; then
    log "WARNING: Backup source '$dir' does not exist. Skipping $label restore."
    return 1
  fi
  if [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    log "WARNING: Backup source '$dir' is empty. Skipping $label restore to prevent data loss."
    return 1
  fi
  return 0
}

# Pre-restore backup: snapshot existing target before overwriting
backup_existing() {
  local target="$1"
  $DRY_RUN && return 0
  if [[ -e "$target" ]]; then
    cp -a "$target" "${target}.pre-restore.$(date +%s)" 2>/dev/null || true
  fi
}

# Validate source dir, backup existing target, then rsync
restore_dir() {
  local src="$1" dest="$2" label="$3"
  shift 3
  # remaining args are extra rsync flags (e.g. --exclude)
  if validate_source "$src" "$label"; then
    backup_existing "$dest"
    log "Restoring $label..."
    run rsync -a --delete "$@" "$src" "$dest"
  fi
}

log "Restoring from: $BACKUP_DIR"
$DRY_RUN && log "DRY RUN MODE — no changes will be made"

if [[ "$TARGET" == "all" || "$TARGET" == "claude" ]]; then
  restore_dir "$BACKUP_DIR/claude-agents/" "$HOME/.claude/agents/" "Claude Code agents"
  restore_dir "$BACKUP_DIR/claude-hooks/" "$HOME/.claude/hooks/" "Claude Code hooks"
  if [[ -f "$BACKUP_DIR/claude-settings.json" ]]; then
    backup_existing "$HOME/.claude/settings.json"
    log "Restoring Claude Code settings..."
    run cp "$BACKUP_DIR/claude-settings.json" "$HOME/.claude/settings.json"
  else
    log "WARNING: $BACKUP_DIR/claude-settings.json not found. Skipping settings restore."
  fi
  log "Claude Code restored."
fi

if [[ "$TARGET" == "all" || "$TARGET" == "pi" ]]; then
  restore_dir "$BACKUP_DIR/pi-agent/" "$HOME/.pi/agent/" "Pi agents" --exclude='sessions'
fi

if [[ "$TARGET" == "all" || "$TARGET" == "opencode" ]]; then
  restore_dir "$BACKUP_DIR/opencode/" "$HOME/.config/opencode/" "OpenCode config" --exclude='cache' --exclude='node_modules'
fi

log "Restore complete."
