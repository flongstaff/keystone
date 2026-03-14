#!/usr/bin/env bash
# Non-blocking update banner. Reads from cache only — never blocks Claude Code.
# Background async refresh triggers when current time passes next_check_recommended (set 7 days after last check).

# Note: -e is intentionally omitted — conditional checks (jq, date parsing) return
# non-zero in normal operation. -u catches unset vars.
set -uo pipefail

CACHE="$HOME/.claude/stack-update-cache.json"
LOG="$HOME/.claude/logs/update-checks.log"
mkdir -p "$HOME/.claude/logs" 2>/dev/null || true

# ── Quick exit if no framework markers ────────────────────────────────
# No point showing BMAD/GSD update banners in projects that use neither.
if ! [[ -d "_bmad" || -d ".bmad" || -f ".planning/config.json" || -f ".claude/CLAUDE.md" || -f "CLAUDE.md" ]] \
   && ! compgen -G "docs/prd*.md" > /dev/null 2>&1; then
  exit 0
fi

if ! command -v jq &>/dev/null; then
    echo "stack-update-banner: 'jq' required but not found. Install with: brew install jq" >&2
    exit 0
fi

if [ -f "$CACHE" ]; then
    BMAD_LOCAL=$(jq -r '.bmad_installed // "?"' "$CACHE" 2>/dev/null)
    BMAD_LATEST=$(jq -r '.bmad_latest // "?"' "$CACHE" 2>/dev/null)
    GSD_LOCAL=$(jq -r '.gsd_installed // "?"' "$CACHE" 2>/dev/null)
    GSD_LATEST=$(jq -r '.gsd_latest // "?"' "$CACHE" 2>/dev/null)
    REQUIRED=$(jq -r '.required_actions_count // 0' "$CACHE" 2>/dev/null)
    NEXT_CHECK=$(jq -r '.next_check_recommended // ""' "$CACHE" 2>/dev/null)

    BMAD_OUTDATED=false
    GSD_OUTDATED=false
    [ "$BMAD_LOCAL" != "$BMAD_LATEST" ] && [ "$BMAD_LATEST" != "?" ] && BMAD_OUTDATED=true
    [ "$GSD_LOCAL" != "$GSD_LATEST" ] && [ "$GSD_LATEST" != "?" ] && GSD_OUTDATED=true

    [[ "$REQUIRED" =~ ^[0-9]+$ ]] || REQUIRED=0
    if $BMAD_OUTDATED || $GSD_OUTDATED || [ "$REQUIRED" -gt 0 ]; then
        echo "" >&2
        echo "┌─────────────────────────────────────────────────┐" >&2
        echo "│  STACK UPDATE AVAILABLE                          │" >&2
        echo "├─────────────────────────────────────────────────┤" >&2
        $BMAD_OUTDATED && printf "│  BMAD: %-8s → %-18s       │\n" "$BMAD_LOCAL" "$BMAD_LATEST" >&2
        $GSD_OUTDATED  && printf "│  GSD:  %-8s → %-18s       │\n" "$GSD_LOCAL" "$GSD_LATEST" >&2
        [ "$REQUIRED" -gt 0 ] && printf "│  %s required agent fix(es) pending              │\n" "$REQUIRED" >&2
        echo "│  Say: 'check for updates' for details           │" >&2
        echo "└─────────────────────────────────────────────────┘" >&2
        echo "" >&2
    fi

    # Async background refresh if cache stale
    NOW_EPOCH=$(date +%s)
    if [ -n "$NEXT_CHECK" ] && [ "$NEXT_CHECK" != "null" ]; then
        # Cross-platform date parsing: try BSD (macOS) then GNU (Linux), fallback to skip
        NEXT_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${NEXT_CHECK%%+*}" +%s 2>/dev/null \
                  || date -d "${NEXT_CHECK%%+*}" +%s 2>/dev/null \
                  || echo "")
        if [ -z "$NEXT_EPOCH" ]; then
            # Both date commands failed — skip refresh rather than crash
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] BG refresh skipped: could not parse next_check date '$NEXT_CHECK'" >> "$LOG" 2>/dev/null || true
        elif [ "$NOW_EPOCH" -gt "$NEXT_EPOCH" ]; then
            (
                BMAD_NEW=$(npm view bmad-method version 2>/dev/null || echo "")
                GSD_NEW=$(npm view get-shit-done-cc version 2>/dev/null || echo "")
                if [ -n "$BMAD_NEW" ] && [ -n "$GSD_NEW" ]; then
                    NEXT=$(date -v+7d -Iseconds 2>/dev/null || date -d "+7 days" --iso-8601=seconds 2>/dev/null || echo "")
                    REQ=$(jq -r '.required_actions_count // 0' "$CACHE" 2>/dev/null || echo 0)
                    BMAD_CUR=$(python3 -c "import json; print(json.load(open('$HOME/.claude/skills/bmad/core/package.json'))['version'])" 2>/dev/null || echo "?")
                    GSD_CUR=$(tr -d '[:space:]' < "$HOME/.claude/commands/gsd/.version" 2>/dev/null || echo "?")
                    # Preserve Pi fields from existing cache
                    PI_CUR=$(jq -r '.pi_installed // "?"' "$CACHE" 2>/dev/null || echo "?")
                    PI_LAT=$(jq -r '.pi_latest // "?"' "$CACHE" 2>/dev/null || echo "?")
                    TMPFILE="${CACHE}.tmp.$$"
                    if jq -n --arg last "$(date -Iseconds)" \
                          --arg bi "$BMAD_CUR" --arg bl "$BMAD_NEW" \
                          --arg gi "$GSD_CUR" --arg gl "$GSD_NEW" \
                          --arg pi "$PI_CUR" --arg pl "$PI_LAT" \
                          --arg next "$NEXT" --argjson req "${REQ:-0}" \
                        '{last_checked:$last,bmad_installed:$bi,bmad_latest:$bl,gsd_installed:$gi,gsd_latest:$gl,pi_installed:$pi,pi_latest:$pl,required_actions_count:$req,next_check_recommended:$next}' \
                        > "$TMPFILE" 2>/dev/null; then
                        mv "$TMPFILE" "$CACHE"
                    else
                        rm -f "$TMPFILE"
                    fi
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] BG refresh: BMAD=$BMAD_NEW GSD=$GSD_NEW" >> "$LOG" 2>/dev/null || true
                fi
            ) &>/dev/null &
            disown
        fi
    fi
else
    echo "" >&2
    echo "No update cache yet. Say 'check for updates' to initialise." >&2
    echo "" >&2
    TMPFILE="${CACHE}.tmp.$$"
    if jq -n '{last_checked:"never",bmad_installed:"?",bmad_latest:"?",gsd_installed:"?",gsd_latest:"?",required_actions_count:0}' \
        > "$TMPFILE" 2>/dev/null; then
        mv "$TMPFILE" "$CACHE"
    else
        rm -f "$TMPFILE"
    fi
fi
