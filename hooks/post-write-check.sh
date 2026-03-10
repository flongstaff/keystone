#!/usr/bin/env bash
# post-write-check.sh — Claude Code PostToolUse (Write) hook
#
# Runs after every file write. Checks for common safety issues.
# Non-blocking: outputs warnings to stderr only.

FILE="${1:-}"
LOG="$HOME/.claude/logs/post-write-check.log"
mkdir -p "$(dirname "$LOG")"

# If no file argument (Claude Code passes it via env or stdin), try to detect
[[ -z "$FILE" ]] && FILE="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
[[ -z "$FILE" ]] && exit 0
[[ -f "$FILE" ]] || exit 0

WARNINGS=()
ERRORS=()

EXT="${FILE##*.}"

# ── Check: Hardcoded secrets ──────────────────────────────────────────
# Applies to all scripts and config files
if [[ "$EXT" =~ ^(sh|bash|ps1|py|js|ts|json|yaml|yml|env|conf|cfg|ini)$ ]]; then
  # Patterns that suggest real hardcoded secrets
  if grep -qiE "(password|passwd|secret|apikey|api_key|token|credential)\s*[=:]\s*['\"][^'\"]{4,}" "$FILE" 2>/dev/null; then
    if ! grep -qiE "(password|secret|token|apikey).*(\\\$|env\.|ENV\[|getenv|KeyVault|vault|prompt|Get-Credential|read -s|example|placeholder|changeme|your-|<|>)" "$FILE" 2>/dev/null; then
      ERRORS+=("HARDCODED SECRET detected in $FILE — use environment variables or a secrets manager")
    fi
  fi
fi

# ── Check: Shell scripts ──────────────────────────────────────────────
if [[ "$EXT" =~ ^(sh|bash)$ ]] || head -1 "$FILE" 2>/dev/null | grep -q "^#!.*bash\|^#!.*sh"; then
  # set -e not present
  grep -q "set -e\|set -euo pipefail" "$FILE" || WARNINGS+=("$FILE: missing 'set -euo pipefail' — script won't exit on errors")

  # No dry-run flag in scripts that make changes
  if grep -qiE "(rm |mv |chmod |chown |useradd |userdel |groupadd |mkdir |cp )" "$FILE"; then
    grep -qiE "(dry.run|DRY_RUN|\-n |\-\-dry)" "$FILE" || \
      WARNINGS+=("$FILE: contains destructive commands but no dry-run flag detected")
  fi
fi

# ── Check: PowerShell scripts ─────────────────────────────────────────
if [[ "$EXT" == "ps1" ]]; then
  # No error action preference
  grep -qi "ErrorActionPreference\|SupportsShouldProcess\|WhatIf" "$FILE" || \
    WARNINGS+=("$FILE: missing ErrorActionPreference='Stop' or SupportsShouldProcess — add error handling")

  # Hardcoded paths (C:\Users\specific.user\...)
  grep -qiE "C:\\\\Users\\\\[a-zA-Z]" "$FILE" && \
    WARNINGS+=("$FILE: hardcoded user path detected — use \$env:USERPROFILE or \$env:HOME")
fi

# ── Check: GDScript (Godot) ───────────────────────────────────────────
if [[ "$EXT" == "gd" ]]; then
  # Absolute node paths
  grep -qE 'get_node\("/[^"]+"\)|\$/' "$FILE" && \
    WARNINGS+=("$FILE: absolute node path detected — use relative paths or @export variables")

  # yield (Godot 3 syntax)
  grep -q "^[[:space:]]*yield(" "$FILE" && \
    ERRORS+=("$FILE: 'yield()' is Godot 3 syntax — use 'await' in Godot 4")

  # Game logic in UI script (heuristic)
  if [[ "$FILE" =~ (ui|UI|panel|Panel|button|Button|screen|Screen) ]]; then
    grep -qi "health\|damage\|score\|inventory\|player_stats" "$FILE" && \
      WARNINGS+=("$FILE: game logic detected in UI script — move to autoload or game node")
  fi
fi

# ── Output results ────────────────────────────────────────────────────
if [[ ${#ERRORS[@]} -gt 0 || ${#WARNINGS[@]} -gt 0 ]]; then
  echo "" >&2
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "┌─ POST-WRITE ERRORS (" "$(basename "$FILE")" ") ─────────────────" >&2
    for e in "${ERRORS[@]}"; do
      echo "│ ❌ $e" >&2
    done
    echo "└────────────────────────────────────────────────" >&2
  fi

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "┌─ POST-WRITE WARNINGS (" "$(basename "$FILE")" ") ──────────────" >&2
    for w in "${WARNINGS[@]}"; do
      echo "│ ⚠ $w" >&2
    done
    echo "└────────────────────────────────────────────────" >&2
  fi
  echo "" >&2
fi

# Log issues
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
for e in "${ERRORS[@]}"; do echo "[$TIMESTAMP] ERROR: $e" >> "$LOG"; done
for w in "${WARNINGS[@]}"; do echo "[$TIMESTAMP] WARN:  $w" >> "$LOG"; done

exit 0  # Never block — warnings only
