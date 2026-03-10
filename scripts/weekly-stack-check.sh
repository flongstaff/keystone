#!/bin/bash
# weekly-stack-check.sh — Standalone version check. Fetches npm versions, writes cache.
# Run manually or via cron. Does NOT apply changes.
#
# Cron:  0 9 * * 1 ~/.claude/scripts/weekly-stack-check.sh
#
# ROLLBACK: Delete ~/.claude/stack-update-cache.json to reset.

set -euo pipefail
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
GSD_LOCAL=$(cat "$HOME/.claude/commands/gsd/.version" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
PI_LOCAL=$(pi --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

NEXT=$(date -v+7d -Iseconds 2>/dev/null || date -d "+7 days" --iso-8601=seconds 2>/dev/null || echo "")
REQ=$(jq -r '.required_actions_count // 0' "$CACHE" 2>/dev/null || echo 0)

jq -n --arg last "$(date -Iseconds)" \
      --arg bi "$BMAD_LOCAL" --arg bl "$BMAD_LATEST" \
      --arg gi "$GSD_LOCAL"  --arg gl "$GSD_LATEST" \
      --arg pi "$PI_LOCAL"   --arg pl "$PI_LATEST" \
      --arg next "$NEXT" --argjson req "${REQ:-0}" \
    '{last_checked:$last,bmad_installed:$bi,bmad_latest:$bl,gsd_installed:$gi,gsd_latest:$gl,pi_installed:$pi,pi_latest:$pl,required_actions_count:$req,next_check_recommended:$next}' \
    > "$CACHE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done. BMAD=$BMAD_LOCAL>$BMAD_LATEST GSD=$GSD_LOCAL>$GSD_LATEST Pi=$PI_LOCAL>$PI_LATEST" >> "$LOG" 2>/dev/null || true

echo "BMAD: $BMAD_LOCAL > $BMAD_LATEST $( [ "$BMAD_LOCAL" = "$BMAD_LATEST" ] && echo "(current)" || echo "(UPDATE)" )"
echo "GSD:  $GSD_LOCAL > $GSD_LATEST $( [ "$GSD_LOCAL" = "$GSD_LATEST" ] && echo "(current)" || echo "(UPDATE)" )"
echo "Pi:   $PI_LOCAL > $PI_LATEST $( [ "$PI_LOCAL" = "$PI_LATEST" ] && echo "(current)" || echo "(UPDATE)" )"
echo "Say 'check for updates' in Claude Code for full changelog analysis."
