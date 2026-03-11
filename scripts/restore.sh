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

log "Restoring from: $BACKUP_DIR"
$DRY_RUN && log "DRY RUN MODE — no changes will be made"

if [[ "$TARGET" == "all" || "$TARGET" == "claude" ]]; then
  if validate_source "$BACKUP_DIR/claude-agents/" "Claude Code agents"; then
    [[ -d "$HOME/.claude/agents/" ]] && ! $DRY_RUN && \
      cp -a "$HOME/.claude/agents/" "$HOME/.claude/agents.pre-restore.$(date +%s)" 2>/dev/null || true
    log "Restoring Claude Code agents..."
    run rsync -a --delete "$BACKUP_DIR/claude-agents/" "$HOME/.claude/agents/"
  fi
  if validate_source "$BACKUP_DIR/claude-hooks/" "Claude Code hooks"; then
    log "Restoring Claude Code hooks..."
    run rsync -a --delete "$BACKUP_DIR/claude-hooks/" "$HOME/.claude/hooks/"
  fi
  if [[ -f "$BACKUP_DIR/claude-settings.json" ]]; then
    [[ -f "$HOME/.claude/settings.json" ]] && ! $DRY_RUN && \
      cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-restore.$(date +%s)" 2>/dev/null || true
    log "Restoring Claude Code settings..."
    run cp "$BACKUP_DIR/claude-settings.json" "$HOME/.claude/settings.json"
  else
    log "WARNING: $BACKUP_DIR/claude-settings.json not found. Skipping settings restore."
  fi
  log "Claude Code restored."
fi

if [[ "$TARGET" == "all" || "$TARGET" == "pi" ]]; then
  if validate_source "$BACKUP_DIR/pi-agent/" "Pi agents"; then
    log "Restoring Pi agent config..."
    run rsync -a --delete --exclude='sessions' "$BACKUP_DIR/pi-agent/" "$HOME/.pi/agent/"
    log "Pi restored."
  fi
fi

if [[ "$TARGET" == "all" || "$TARGET" == "opencode" ]]; then
  if validate_source "$BACKUP_DIR/opencode/" "OpenCode config"; then
    log "Restoring OpenCode config..."
    run rsync -a --delete --exclude='cache' --exclude='node_modules' "$BACKUP_DIR/opencode/" "$HOME/.config/opencode/"
    log "OpenCode restored."
  fi
fi

log "Restore complete."
