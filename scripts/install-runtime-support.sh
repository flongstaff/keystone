#!/usr/bin/env bash
# install-runtime-support.sh
#
# Installs and configures BMAD + GSD across all three runtimes:
#   - Claude Code  (~/.claude/)
#   - OpenCode     (~/.config/opencode/ or $OPENCODE_CONFIG_DIR)
#   - Pi           (~/.pi/)
#
# USAGE:
#   ./install-runtime-support.sh [--claude] [--opencode] [--pi] [--all]
#   ./install-runtime-support.sh --all   # install for all detected runtimes

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────
RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'
CYN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "${GRN}  ✓${NC} $*"; }
warn() { echo -e "${YEL}  ⚠️${NC} $*"; }
err()  { echo -e "${RED}  ✗${NC} $*"; }
step() { echo -e "\n${CYN}▶${NC} $*"; }

# ── Args ──────────────────────────────────────────────────────────────
DO_CLAUDE=false
DO_OPENCODE=false
DO_PI=false
DO_DOMAINS=false

for arg in "$@"; do
  case $arg in
    --claude)       DO_CLAUDE=true ;;
    --opencode)     DO_OPENCODE=true ;;
    --pi)           DO_PI=true ;;
    --all)          DO_CLAUDE=true; DO_OPENCODE=true; DO_PI=true ;;
    --with-domains) DO_DOMAINS=true ;;
    *)              echo "Unknown: $arg"
                    echo "Usage: $0 [--claude] [--opencode] [--pi] [--all] [--with-domains]"
                    echo ""
                    echo "  --with-domains  Also install optional domain agents"
                    echo "                  (Godot, open-source, admin-docs, advisor)"
                    exit 1 ;;
  esac
done

if ! $DO_CLAUDE && ! $DO_OPENCODE && ! $DO_PI; then
  echo "Specify at least one runtime: --claude --opencode --pi --all"
  exit 1
fi

# ── Paths ─────────────────────────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
PI_DIR="$HOME/.pi"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SRC="$SCRIPT_DIR/../agents"

# ── Detect available runtimes ─────────────────────────────────────────
step "Detecting installed runtimes..."

CLAUDE_AVAILABLE=false
OPENCODE_AVAILABLE=false
PI_AVAILABLE=false

command -v claude &>/dev/null && CLAUDE_AVAILABLE=true && ok "Claude Code detected"
command -v opencode &>/dev/null && OPENCODE_AVAILABLE=true && ok "OpenCode detected"
command -v pi &>/dev/null && PI_AVAILABLE=true && ok "Pi detected"

if ! $CLAUDE_AVAILABLE && ! $OPENCODE_AVAILABLE && ! $PI_AVAILABLE; then
  warn "No runtimes detected in PATH. Install commands available at bottom of this script."
fi

# ── Install BMAD ──────────────────────────────────────────────────────
step "Installing BMAD..."

if command -v npx &>/dev/null; then
  npx bmad-method install && ok "BMAD installed"
else
  err "npx not found — install Node.js first"
  exit 1
fi

# ── Install GSD for selected runtimes ─────────────────────────────────
step "Installing GSD..."

if $DO_CLAUDE; then
  npx get-shit-done-cc --claude --global && ok "GSD installed for Claude Code"
fi

if $DO_OPENCODE; then
  npx get-shit-done-cc --opencode --global && ok "GSD installed for OpenCode"
fi

if $DO_PI; then
  # GSD does not have native Pi support yet — install base and create Pi agent wrapper
  warn "GSD does not have a native Pi installer. Installing Claude Code version as base."
  warn "Pi-compatible wrappers will be created in ~/.pi/agent/"
fi

# ── Deploy agents to Claude Code ──────────────────────────────────────
if $DO_CLAUDE; then
  step "Deploying core agents to Claude Code..."
  mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/scripts" "$CLAUDE_DIR/logs"

  # Core agents: everything except agents/optional/
  AGENT_COUNT=0
  while IFS= read -r -d '' agent_src; do
    agent_name=$(basename "$agent_src")
    cp "$agent_src" "$CLAUDE_DIR/agents/"
    ok "Deployed: $agent_name"
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done < <(find "$AGENTS_SRC" -name '*.md' -not -path '*/optional/*' -print0)

  if [[ $AGENT_COUNT -eq 0 ]]; then
    warn "No core agent files found in $AGENTS_SRC"
  else
    ok "Deployed $AGENT_COUNT core agents to $CLAUDE_DIR/agents/"
  fi

  # Optional domain agents (only with --with-domains)
  if $DO_DOMAINS; then
    OPTIONAL_SRC="$AGENTS_SRC/optional"
    if [[ -d "$OPTIONAL_SRC" ]]; then
      step "Deploying optional domain agents..."
      OPT_COUNT=0
      while IFS= read -r -d '' agent_src; do
        agent_name=$(basename "$agent_src")
        cp "$agent_src" "$CLAUDE_DIR/agents/"
        ok "Optional: $agent_name"
        OPT_COUNT=$((OPT_COUNT + 1))
      done < <(find "$OPTIONAL_SRC" -name '*.md' -print0)
      ok "Deployed $OPT_COUNT optional agents"
    else
      warn "No optional agents directory found at $OPTIONAL_SRC"
    fi
  else
    echo ""
    echo "  Skipped optional domain agents (Godot, open-source, admin-docs, advisor)."
    echo "  To include them: $0 --claude --with-domains"
    echo ""
  fi
fi

# ── Deploy agents to Pi ───────────────────────────────────────────────
if $DO_PI; then
  if ! command -v python3 &>/dev/null; then
    err "python3 is required for Pi agent conversion but was not found"
    exit 1
  fi
  step "Deploying agents to Pi..."
  mkdir -p "$PI_DIR/agent"

  # Pi loads AGENTS.md files from ~/.pi/agent/
  # We create Pi-compatible versions (no Claude Code frontmatter, AGENTS.md format)

  FIND_OPTS=(-name '*.md')
  $DO_DOMAINS || FIND_OPTS+=(-not -path '*/optional/*')

  while IFS= read -r -d '' agent_src; do
    agent_name=$(basename "$agent_src" .md)
    pi_target="$PI_DIR/agent/$agent_name.md"

    # Strip Claude Code frontmatter (---..---) and reformat for Pi
    python3 - "$agent_src" "$pi_target" <<'PYEOF'
import sys, re

src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()

# Remove YAML frontmatter block
content = re.sub(r'^---\n.*?---\n', '', content, flags=re.DOTALL)

# Add Pi-compatible header comment
name = src.split('/')[-1].replace('.md', '')
header = f"# {name}\n# Pi Agent — loaded from ~/.pi/agent/\n\n"
content = header + content.lstrip()

with open(dst, 'w') as f:
    f.write(content)
print(f"  → Pi agent: {dst}")
PYEOF

    ok "Pi agent: $agent_name"
  done < <(find "$AGENTS_SRC" "${FIND_OPTS[@]}" -print0)

  ok "Pi agents deployed to $PI_DIR/agent/"
  echo "  Pi loads these automatically at startup from ~/.pi/agent/"
fi

# ── Deploy agents to OpenCode ─────────────────────────────────────────
if $DO_OPENCODE; then
  step "Deploying agents to OpenCode..."

  # OpenCode agent location varies by version
  OC_AGENT_DIR=""
  for candidate in \
    "$OPENCODE_DIR/agents" \
    "$OPENCODE_DIR/.agents" \
    "$HOME/.config/opencode/agents"; do
    if [[ -d "$candidate" ]] || mkdir -p "$candidate" 2>/dev/null; then
      OC_AGENT_DIR="$candidate"
      break
    fi
  done

  if [[ -n "$OC_AGENT_DIR" ]]; then
    OC_FIND_OPTS=(-name '*.md')
    $DO_DOMAINS || OC_FIND_OPTS+=(-not -path '*/optional/*')
    find "$AGENTS_SRC" "${OC_FIND_OPTS[@]}" -exec cp {} "$OC_AGENT_DIR/" \;
    ok "OpenCode agents deployed to $OC_AGENT_DIR"
  else
    warn "Could not determine OpenCode agent directory. Deploy manually."
  fi
fi

# ── Deploy hooks (Claude Code only) ──────────────────────────────────
if $DO_CLAUDE; then
  step "Deploying hooks..."

  HOOKS_SRC="$SCRIPT_DIR/../hooks"
  HOOKS_DST="$CLAUDE_DIR/hooks"
  mkdir -p "$HOOKS_DST"

  for hook in "$HOOKS_SRC"/*.sh; do
    [[ -f "$hook" ]] || continue
    cp "$hook" "$HOOKS_DST/"
    chmod +x "$HOOKS_DST/$(basename "$hook")"
    ok "Hook: $(basename "$hook")"
  done

  # Patch settings.json
  SETTINGS="$CLAUDE_DIR/settings.json"
  [[ -f "$SETTINGS" ]] || echo '{"hooks":{}}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)" 2>/dev/null || true

  python3 - "$SETTINGS" <<'PYEOF'
import json, sys, os

path = sys.argv[1]
with open(path) as f:
    s = json.load(f)

hooks = s.setdefault("hooks", {})
ss = hooks.setdefault("SessionStart", [])

banner = {"type": "command", "command": "bash $HOME/.claude/hooks/stack-update-banner.sh"}
session = {"type": "command", "command": "bash $HOME/.claude/hooks/session-start.sh"}

if not any("stack-update-banner" in str(h) for h in ss):
    ss.insert(0, banner)
if not any("session-start" in str(h) for h in ss):
    ss.append(session)

ptw = hooks.setdefault("PostToolUse", [])
write_hook = {"matcher": "Write", "hooks": [{"type": "command", "command": "bash $HOME/.claude/hooks/post-write-check.sh"}]}
if not any("post-write-check" in str(h) for h in ptw):
    ptw.append(write_hook)

with open(path, 'w') as f:
    json.dump(s, f, indent=2)
print("  → settings.json patched")
PYEOF
fi

# ── Set up weekly update check cron ───────────────────────────────────
step "Setting up weekly update check..."

WEEKLY_SCRIPT="$CLAUDE_DIR/scripts/weekly-stack-check.sh"
if [[ -f "$WEEKLY_SCRIPT" ]] && command -v crontab &>/dev/null; then
  CRON_LINE="0 9 * * 1 /bin/bash $WEEKLY_SCRIPT >> $HOME/.claude/logs/update-checks.log 2>&1"
  if ! crontab -l 2>/dev/null | grep -q "weekly-stack-check"; then
    EXISTING=$(crontab -l 2>/dev/null || true)
    printf '%s\n%s\n' "$EXISTING" "$CRON_LINE" | crontab -
    ok "Weekly update check cron set (Monday 09:00)"
  else
    ok "Weekly cron already configured"
  fi
else
  warn "Weekly cron skipped (script not found or crontab not available)"
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  INSTALL COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
$DO_CLAUDE   && echo "  Claude Code: ~/.claude/agents/ + hooks deployed"
$DO_OPENCODE && echo "  OpenCode:    agents deployed to $OPENCODE_DIR"
$DO_PI       && echo "  Pi:          ~/.pi/agent/ agents deployed"
echo ""
echo "  NEXT STEPS:"
echo "  1. Restart your runtime(s)"
echo "  2. Open a project directory"
echo "  3. Say: 'set up this project' to run project-setup-advisor"
echo ""
echo "  Or to check what's already installed:"
echo "  Say: 'check for updates' → stack-update-watcher agent"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Runtime install hints (if not detected) ───────────────────────────
if ! $CLAUDE_AVAILABLE || ! $OPENCODE_AVAILABLE || ! $PI_AVAILABLE; then
  echo ""
  echo "  RUNTIME INSTALL COMMANDS:"
  ! $CLAUDE_AVAILABLE   && echo "  Claude Code: npm install -g @anthropic-ai/claude-code"
  ! $OPENCODE_AVAILABLE && echo "  OpenCode:    npm install -g opencode-ai  (or see opencode.ai)"
  ! $PI_AVAILABLE       && echo "  Pi:          npm install -g @mariozechner/pi-coding-agent"
  echo ""
fi
