#!/usr/bin/env bash
# weekly-stack-check.sh — Standalone version check. Fetches npm versions, writes cache.
# Run manually or via cron. Does NOT apply changes.
#
# Cron:  0 9 * * 1 ~/.claude/scripts/weekly-stack-check.sh
#
# ROLLBACK: Delete ~/.claude/stack-update-cache.json to reset.

set -euo pipefail

for dep in jq npm; do
    if ! command -v "$dep" &>/dev/null; then
        echo "ERROR: '$dep' is required but not installed." >&2
        exit 1
    fi
done

CACHE="$HOME/.claude/stack-update-cache.json"
LOG="$HOME/.claude/logs/update-checks.log"
mkdir -p "$HOME/.claude/logs" 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Weekly check starting..." >> "$LOG" 2>/dev/null || true

BMAD_LATEST=$(npm view bmad-method version 2>/dev/null || echo "FETCH_FAILED")
GSD_LATEST=$(npm view get-shit-done-cc version 2>/dev/null || echo "FETCH_FAILED")
PI_LATEST=$(npm view @mariozechner/pi-coding-agent version 2>/dev/null || echo "unknown")

if [ "$BMAD_LATEST" = "FETCH_FAILED" ] || [ "$GSD_LATEST" = "FETCH_FAILED" ]; then
    echo "Fetch failed — check connectivity. Retry manually." && exit 1
fi

BMAD_LOCAL=$(python3 -c "import json; print(json.load(open('$HOME/.claude/skills/bmad/core/package.json'))['version'])" 2>/dev/null || echo "unknown")
GSD_LOCAL=$(tr -d '[:space:]' < "$HOME/.claude/commands/gsd/.version" 2>/dev/null || echo "unknown")
PI_LOCAL=$(pi --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

NEXT=$(date -v+7d -Iseconds 2>/dev/null || date -d "+7 days" --iso-8601=seconds 2>/dev/null || echo "")
REQ=$(jq -r '.required_actions_count // 0' "$CACHE" 2>/dev/null || echo 0)

TMPFILE="${CACHE}.tmp.$$"
if jq -n --arg last "$(date -Iseconds)" \
      --arg bi "$BMAD_LOCAL" --arg bl "$BMAD_LATEST" \
      --arg gi "$GSD_LOCAL"  --arg gl "$GSD_LATEST" \
      --arg pi "$PI_LOCAL"   --arg pl "$PI_LATEST" \
      --arg next "$NEXT" --argjson req "${REQ:-0}" \
    '{last_checked:$last,bmad_installed:$bi,bmad_latest:$bl,gsd_installed:$gi,gsd_latest:$gl,pi_installed:$pi,pi_latest:$pl,required_actions_count:$req,next_check_recommended:$next}' \
    > "$TMPFILE"; then
    mv "$TMPFILE" "$CACHE"
else
    rm -f "$TMPFILE"
    echo "ERROR: Failed to write cache file" >&2
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done. BMAD=$BMAD_LOCAL>$BMAD_LATEST GSD=$GSD_LOCAL>$GSD_LATEST Pi=$PI_LOCAL>$PI_LATEST" >> "$LOG" 2>/dev/null || true

version_status() {
    local label="$1" local_ver="$2" latest_ver="$3"
    local status="(UPDATE)"
    [ "$local_ver" = "$latest_ver" ] && status="(current)"
    printf "%-5s %s > %s %s\n" "$label" "$local_ver" "$latest_ver" "$status"
}

version_status "BMAD:" "$BMAD_LOCAL" "$BMAD_LATEST"
version_status "GSD:"  "$GSD_LOCAL"  "$GSD_LATEST"
version_status "Pi:"   "$PI_LOCAL"   "$PI_LATEST"
echo "Say 'check for updates' in Claude Code for full changelog analysis."
