# Coding Conventions

**Analysis Date:** 2026-03-11

## Naming Patterns

**Files:**
- Lowercase with hyphens: `post-write-check.sh`, `session-start.sh`, `install-runtime-support.sh`
- Markdown agents: `project-setup-advisor.md`, `bmad-gsd-orchestrator.md`
- Descriptive names reflecting function or purpose

**Functions:**
- Bash: lowercase with underscores: `ok()`, `warn()`, `err()`, `step()`, `log()`, `validate_source()`
- Single responsibility per function
- Helper functions defined early (e.g., color output and logging functions at top)

**Variables:**
- CONSTANTS in UPPERCASE for configuration: `HOME`, `CLAUDE_DIR`, `OPENCODE_DIR`, `PI_DIR`, `BACKUP_DIR`, `CACHE`, `LOG`
- FLAGS in UPPERCASE_WITH_UNDERSCORE: `DO_CLAUDE=false`, `DRY_RUN=false`, `HAS_BMAD=true`, `CLAUDE_AVAILABLE=true`
- Local variables in lowercase: `arg`, `target`, `hook`, `agent_name`
- Boolean flags use descriptive names: `HAS_BMAD`, `HAS_GSD`, `HAS_CLAUDE_MD`, `BMAD_OUTDATED`

**Types/Classes:**
- Not applicable (shell/bash project)

## Code Style

**Formatting:**
- Shell scripts use `bash` shebang: `#!/usr/bin/env bash`
- PowerShell scripts use: `#!/usr/bin/env pwsh` or direct `.ps1`
- Two spaces for indentation in shell scripts
- Four spaces for indentation in Python inline scripts (within heredocs)
- Comments use `#` with space before content: `# This is a comment`
- Section separators for logical grouping: `# ── Section Name ──────────────────────────────────────`

**Linting:**
- Shell scripts validated with `set -euo pipefail` (error on undefined vars, unpiped failures, subshell errors)
- No formal linter configured; conventions enforced via code review and post-write hooks
- Post-write hook checks for missing `set -euo pipefail` in all shell scripts

## Import Organization

**Not Applicable**
- Bash has no imports; external dependencies are via `command -v` checks or direct command invocation
- Python inline scripts within heredocs use inline imports: `import json, sys`, `import re`

## Error Handling

**Patterns:**
- Bash scripts use `set -euo pipefail` at the top to fail on errors
- Functions return explicit status codes (0 = success, 1 = error)
- Error messages are prefixed with context: `"ERROR: $message"` or `"WARNING: $message"`
- Errors always sent to stderr via `>&2` redirection
- Examples:
  ```bash
  # From restore.sh
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
    return 0
  }
  ```

**Error Classification:**
- ERRORS: Fatal conditions that prevent completion (e.g., missing required dependencies, invalid arguments)
- WARNINGS: Non-fatal issues that should be visible (e.g., missing optional files, fallback behavior triggered)
- INFO/SUCCESS: Status messages prefixed with ✓ (via `ok()` function) or context indicators

## Logging

**Framework:** `echo` with redirection to stderr (`>&2`)

**Patterns:**
- Status messages go to stderr (fd 2) so stdout can be captured for piping
- Timestamps added when logging to files: `[$(date '+%Y-%m-%d %H:%M:%S')]`
- Log files created in `$HOME/.claude/logs/` with names like `session-start.log`, `update-checks.log`, `post-write-check.log`
- Async background operations log to their own files (e.g., `weekly-stack-check.sh` logs to `update-checks.log`)
- Example:
  ```bash
  LOG="$HOME/.claude/logs/session-start.log"
  mkdir -p "$HOME/.claude/logs" 2>/dev/null || true
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  { echo "[$TIMESTAMP] Session start: $(pwd)" >> "$LOG"; } 2>/dev/null || true
  ```

## Comments

**When to Comment:**
- Section headers for major logical blocks: `# ── Section Name ─────────────`
- Non-obvious conditional logic or regex patterns
- External API calls and their expected outputs
- Instructions for manual operation (e.g., "Cron: 0 9 * * 1")
- Warnings about side effects or non-obvious behaviors

**Style:**
- Comments are concise and technical
- Example:
  ```bash
  # Async background refresh if cache stale
  NOW_EPOCH=$(date +%s)
  if [ -n "$NEXT_CHECK" ] && [ "$NEXT_CHECK" != "null" ]; then
    NEXT_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${NEXT_CHECK%%+*}" +%s 2>/dev/null || ...)
  ```

**JSDoc/TSDoc:**
- Not applicable (shell project)

## Function Design

**Size:**
- Most functions stay under 30 lines
- Larger orchestration functions (e.g., installation scripts) split into logical sections with clear comments
- Example: `install-runtime-support.sh` has ~270 lines total but organized in labeled sections with distinct responsibilities

**Parameters:**
- Bash functions accept positional arguments
- Functions that need defaults use local variables set at function top:
  ```bash
  validate_source() {
    local dir="$1" label="$2"
    if [[ ! -d "$dir" ]]; then
      return 1
    fi
    return 0
  }
  ```
- Command-line argument parsing uses case/esac patterns with explicit help:
  ```bash
  for arg in "$@"; do
    case $arg in
      --claude)   DO_CLAUDE=true ;;
      --opencode) DO_OPENCODE=true ;;
      --pi)       DO_PI=true ;;
      --all)      DO_CLAUDE=true; DO_OPENCODE=true; DO_PI=true ;;
      *)          echo "Unknown: $arg"; echo "Usage: $0 [...]"; exit 1 ;;
    esac
  done
  ```

**Return Values:**
- Exit code 0 = success, non-zero = failure
- Functions that output text send to stdout, errors to stderr
- Boolean functions return 0 (true) or 1 (false) via exit code
- Functions that compute values use `echo` to stdout: `echo "result"` then captured with `$(function)`

## Module Design

**Exports:**
- Bash scripts are self-contained; no explicit exports
- All functions used internally or by subprocess calls

**Barrel Files:**
- Not applicable (no module system in bash)

## Color Output

**Pattern:**
- Used sparingly for status messages and warnings
- Color codes defined at script top:
  ```bash
  RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'
  CYN='\033[0;36m'; NC='\033[0m'
  ```
- Helper functions for consistent styling:
  ```bash
  ok()   { echo -e "${GRN}  ✓${NC} $*"; }
  warn() { echo -e "${YEL}  ⚠️${NC} $*"; }
  err()  { echo -e "${RED}  ✗${NC} $*"; }
  step() { echo -e "\n${CYN}▶${NC} $*"; }
  ```
- Banners use box drawing characters: `┌──┐`, `│`, `└──┘` for visual separation

## Safety and Defensive Coding

**Patterns:**
- Always quote variables: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals instead of `[ ]` (bash-specific but safer)
- Check command existence before use: `command -v jq &>/dev/null` or `! command -v npm &>/dev/null`
- Suppress unwanted output with redirects: `2>/dev/null || true`
- Backup critical files before modification: `cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)" 2>/dev/null || true`
- Use `--dry-run` flags in scripts that make destructive changes (rm, mv, chmod, etc.)
- Example from `post-write-check.sh`:
  ```bash
  # Check for missing set -euo pipefail
  if [[ "$EXT" =~ ^(sh|bash)$ ]] || head -1 "$FILE" 2>/dev/null | grep -q "^#!.*bash\|^#!.*sh"; then
    grep -q "set -e\|set -euo pipefail" "$FILE" || \
      WARNINGS+=("$FILE: missing 'set -euo pipefail' — script won't exit on errors")
  fi
  ```

## Non-Blocking Pattern

**Used in hooks and background tasks:**
- Scripts that run as hooks never exit with error status (always `exit 0`)
- Warnings are logged but don't block the operation
- Background async tasks are disowned: `command &>/dev/null & disown`
- Example from `stack-update-banner.sh`:
  ```bash
  # Async background refresh
  (
    # fetch and update logic here
  ) &>/dev/null &
  disown
  ```

## Python Inline Scripts

**Pattern:**
- Python code embedded in heredocs within bash scripts for complex data transformation
- Use triple-quoted strings and standard imports
- Example from `install-runtime-support.sh`:
  ```bash
  python3 - "$agent_src" "$pi_target" <<'PYEOF'
  import sys, re
  src, dst = sys.argv[1], sys.argv[2]
  with open(src) as f:
    content = f.read()
  # ... processing ...
  PYEOF
  ```

---

*Convention analysis: 2026-03-11*
