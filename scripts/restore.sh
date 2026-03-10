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
    --target)     TARGET="$2"; shift ;;
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

log "Restoring from: $BACKUP_DIR"
$DRY_RUN && log "DRY RUN MODE — no changes will be made"

if [[ "$TARGET" == "all" || "$TARGET" == "claude" ]]; then
  log "Restoring Claude Code agents..."
  run rsync -a --delete "$BACKUP_DIR/claude-agents/" "$HOME/.claude/agents/"
  log "Restoring Claude Code hooks..."
  run rsync -a --delete "$BACKUP_DIR/claude-hooks/" "$HOME/.claude/hooks/"
  log "Restoring Claude Code settings..."
  run cp "$BACKUP_DIR/claude-settings.json" "$HOME/.claude/settings.json"
  log "Claude Code restored."
fi

if [[ "$TARGET" == "all" || "$TARGET" == "pi" ]]; then
  log "Restoring Pi agent config..."
  run rsync -a --delete --exclude='sessions' "$BACKUP_DIR/pi-agent/" "$HOME/.pi/agent/"
  log "Pi restored."
fi

if [[ "$TARGET" == "all" || "$TARGET" == "opencode" ]]; then
  log "Restoring OpenCode config..."
  run rsync -a --delete --exclude='cache' --exclude='node_modules' "$BACKUP_DIR/opencode/" "$HOME/.config/opencode/"
  log "OpenCode restored."
fi

log "Restore complete."
