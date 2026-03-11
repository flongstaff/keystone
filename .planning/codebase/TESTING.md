# Testing Patterns

**Analysis Date:** 2026-03-11

## Test Framework

**Runner:**
- No formal test framework configured
- Testing is done via shell script validation and post-write hooks
- `shellcheck` could be used but is not configured in the project

**Assertion Library:**
- Not applicable (shell project)

**Run Commands:**
- No automated test suite
- Scripts are validated manually and via `post-write-check.sh` hook

## Test File Organization

**Location:**
- No dedicated test files
- Validation occurs via:
  - `post-write-check.sh` (hook) — runs after every file write
  - `weekly-stack-check.sh` (manual/cron) — validates stack versions

**Naming:**
- Not applicable (hook-based validation rather than test files)

**Structure:**
- Validation logic embedded in shell scripts
- Checks organized by file type (shell, PowerShell, GDScript, Python, JSON, YAML)

## Test Structure

**Hook-Based Validation:**
`post-write-check.sh` validates written files after every write:

```bash
# Pattern: Read file, extract extension, run type-specific checks
FILE="${1:-}"
EXT="${FILE##*.}"

# Dispatch on file type
if [[ "$EXT" =~ ^(sh|bash)$ ]]; then
  # Shell-specific checks
fi

if [[ "$EXT" == "ps1" ]]; then
  # PowerShell-specific checks
fi
```

**Patterns:**
- File extension detection: `"${FILE##*.}"` (removes everything up to last dot)
- Shebang detection: `head -1 "$FILE" | grep -q "^#!.*bash"`
- Grep-based pattern matching for validation
- Warnings and errors collected in arrays: `WARNINGS+=()`, `ERRORS+=()`
- Non-blocking output to stderr with visual formatting

## Validation Categories

**1. Hardcoded Secrets (All Files)**

```bash
# Pattern from post-write-check.sh
if [[ "$EXT" =~ ^(sh|bash|ps1|py|js|ts|json|yaml|yml|env|conf|cfg|ini)$ ]]; then
  if grep -qiE "(password|passwd|secret|apikey|api_key|token|credential)\s*[=:]\s*['\"][^'\"]{4,}" "$FILE" 2>/dev/null; then
    if ! grep -qiE "(password|secret|token|apikey).*(\\\$|env\.|ENV\[|getenv|KeyVault|vault|prompt|Get-Credential|read -s|example|placeholder|changeme|your-|<|>)" "$FILE" 2>/dev/null; then
      ERRORS+=("HARDCODED SECRET detected in $FILE")
    fi
  fi
fi
```

- Detects patterns like: `password="...", secret_key="..."` with 4+ character values
- Allows placeholders: variables, env.*, example, placeholder, changeme, your-, angle brackets

**2. Shell Script Validation**

```bash
if [[ "$EXT" =~ ^(sh|bash)$ ]] || head -1 "$FILE" 2>/dev/null | grep -q "^#!.*bash\|^#!.*sh"; then
  # Check 1: set -e not present
  grep -q "set -e\|set -euo pipefail" "$FILE" || \
    WARNINGS+=("$FILE: missing 'set -euo pipefail' — script won't exit on errors")

  # Check 2: No dry-run flag in destructive scripts
  if grep -qiE "(rm |mv |chmod |chown |useradd |userdel |groupadd |mkdir |cp )" "$FILE"; then
    grep -qiE "(dry.run|DRY_RUN|\-n |\-\-dry)" "$FILE" || \
      WARNINGS+=("$FILE: contains destructive commands but no dry-run flag detected")
  fi
fi
```

**Checks:**
1. Missing `set -euo pipefail` — warning (error handling required)
2. Destructive operations without `--dry-run` flag — warning (safety concern)

**3. PowerShell Validation**

```bash
if [[ "$EXT" == "ps1" ]]; then
  # Check 1: ErrorActionPreference missing
  grep -qi "ErrorActionPreference\|SupportsShouldProcess\|WhatIf" "$FILE" || \
    WARNINGS+=("$FILE: missing ErrorActionPreference='Stop' or SupportsShouldProcess")

  # Check 2: Hardcoded user paths
  grep -qiE "C:\\\\Users\\\\[a-zA-Z]" "$FILE" && \
    WARNINGS+=("$FILE: hardcoded user path detected — use \$env:USERPROFILE or \$env:HOME")
fi
```

**Checks:**
1. Missing `ErrorActionPreference='Stop'` or `SupportsShouldProcess` — warning
2. Hardcoded paths like `C:\Users\username\...` — warning (should use `$env:USERPROFILE`)

**4. GDScript (Godot) Validation**

```bash
if [[ "$EXT" == "gd" ]]; then
  # Check 1: Absolute node paths
  grep -qE 'get_node\("/[^"]+"\)|\$/' "$FILE" && \
    WARNINGS+=("$FILE: absolute node path detected — use relative paths or @export")

  # Check 2: Godot 3 syntax (yield)
  grep -q "^[[:space:]]*yield(" "$FILE" && \
    ERRORS+=("$FILE: 'yield()' is Godot 3 syntax — use 'await' in Godot 4")

  # Check 3: Game logic in UI scripts
  if [[ "$FILE" =~ (ui|UI|panel|Panel|button|Button|screen|Screen) ]]; then
    grep -qi "health\|damage\|score\|inventory\|player_stats" "$FILE" && \
      WARNINGS+=("$FILE: game logic detected in UI script")
  fi
fi
```

**Checks:**
1. Absolute node paths (e.g., `get_node("/Game/Player")`) — warning
2. `yield()` function (Godot 3 syntax) — error (incompatible with Godot 4)
3. Game logic in UI scripts by heuristic (filename contains "ui"/"button" but body contains game logic) — warning

## Output and Reporting

**Format:**
- Errors and warnings displayed in bordered boxes to stderr
- Timestamp and filename included
- Non-blocking: `exit 0` always (warnings don't halt execution)

```bash
# Example output
┌─ POST-WRITE ERRORS (filename.sh) ─────────────────
│ ❌ HARDCODED SECRET detected in filename.sh
└────────────────────────────────────────────────

┌─ POST-WRITE WARNINGS (filename.sh) ──────────────
│ ⚠️ filename.sh: missing 'set -euo pipefail'
└────────────────────────────────────────────────
```

**Logging:**
- All errors and warnings logged to `$HOME/.claude/logs/post-write-check.log`
- Format: `[YYYY-MM-DD HH:MM:SS] ERROR: message` or `[YYYY-MM-DD HH:MM:SS] WARN: message`

## Stack Version Testing

**weekly-stack-check.sh Pattern:**
- Fetches current npm versions for BMAD and GSD
- Compares against installed versions
- Writes results to `~/.claude/stack-update-cache.json`
- Can be run manually or via cron (Monday 09:00)
- Non-blocking: exits with code 1 on fetch failure, 0 on success

```bash
# Version comparison
BMAD_LATEST=$(npm view bmad-method version 2>/dev/null || echo "FETCH_FAILED")
GSD_LATEST=$(npm view get-shit-done-cc version 2>/dev/null || echo "FETCH_FAILED")

if [ "$BMAD_LATEST" = "FETCH_FAILED" ] || [ "$GSD_LATEST" = "FETCH_FAILED" ]; then
  echo "Fetch failed — check connectivity. Retry manually." && exit 1
fi

# Write cache
jq -n --arg bi "$BMAD_LOCAL" --arg bl "$BMAD_LATEST" \
  '{bmad_installed:$bi, bmad_latest:$bl, ...}' > "$CACHE"
```

## What is Tested

**Heavily Tested (via post-write hooks):**
- Secret hygiene (hardcoded credentials)
- Shell script safety (`set -euo pipefail`, `--dry-run` flags)
- PowerShell error handling
- Godot 4 syntax compliance
- Path hardcoding issues

**Not Tested:**
- Functional correctness of scripts (requires running them)
- Integration between components
- Cross-platform compatibility (validation only checks syntax)

## What is NOT Tested

**Why:**
- No test framework in use (shell scripts are typically validated by running)
- Post-write hooks focus on safety patterns, not functional behavior
- Integration testing happens manually during feature development
- GSD phases include their own acceptance criteria validation

## Testing Philosophy

This codebase prioritizes:
1. **Safety over correctness** — detect dangerous patterns early (secrets, missing error handling)
2. **Non-blocking validation** — hooks warn but never fail the operation
3. **Pattern consistency** — ensure scripts follow established conventions (set -euo pipefail, --dry-run, logging)
4. **Prevention over recovery** — catch issues at write time rather than runtime

## Recommended Testing Approach

**For new scripts:**
1. Write script with `set -euo pipefail` at top
2. Add `--dry-run` flag if making changes
3. Include structured logging: `log() { echo "[$(date ...)] $1"; }`
4. Run `post-write-check.sh` manually or await hook execution
5. Test in protected environment (VM, test account) before production
6. For infra scripts, always add comment: `# Requires: dry-run test before applying`

**For hooks:**
1. Always exit 0 (non-blocking)
2. Log all output to files in `~/.claude/logs/`
3. Use background processes (`&>/dev/null & disown`) for async operations
4. Test with `post-write-check.sh` to ensure format validation passes

---

*Testing analysis: 2026-03-11*
