#!/usr/bin/env bash
# session-start.sh — Claude Code SessionStart hook
#
# Runs at every Claude Code session start.
# Shows project state, active GSD phase, BMAD status, update banner.
# Non-blocking: all network calls are async or cached.

LOG="$HOME/.claude/logs/session-start.log"
mkdir -p "$HOME/.claude/logs" 2>/dev/null || true

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
{ echo "[$TIMESTAMP] Session start: $(pwd)" >> "$LOG"; } 2>/dev/null || true

# ── 1. Detect project state ───────────────────────────────────────────
HAS_BMAD=false
HAS_GSD=false
HAS_CLAUDE_MD=false
HAS_AGENTS_MD=false
CURRENT_PHASE=""
PROJECT_NAME=""

# shellcheck disable=SC2312
{ [[ -d "_bmad" ]] || [[ -d ".bmad" ]] || compgen -G "docs/prd*.md" > /dev/null 2>&1; } && HAS_BMAD=true
[[ -f ".planning/config.json" ]] && HAS_GSD=true
[[ -f ".claude/CLAUDE.md" || -f "CLAUDE.md" ]] && HAS_CLAUDE_MD=true
[[ -f "AGENTS.md" ]] && HAS_AGENTS_MD=true

# Get project name and current phase if GSD present
if $HAS_GSD; then
  PROJECT_NAME=$(python3 -c "
import json, sys
try:
    d = json.load(open('.planning/config.json'))
    print(d.get('project_name',''))
except:
    pass
" 2>/dev/null || true)

  # Read current phase from STATE.md
  if [[ -f ".planning/STATE.md" ]]; then
    CURRENT_PHASE=$(grep -i "current phase\|active phase" .planning/STATE.md 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1 || true)
  fi
fi

# ── 2. Detect project type from context ──────────────────────────────
PROJECT_TYPE=""
if [[ -f ".claude/CLAUDE.md" ]]; then
  grep -qi "infra\|sysadmin\|devops\|script\|ansible\|terraform\|powershell" .claude/CLAUDE.md 2>/dev/null && PROJECT_TYPE="infra"
  grep -qi "godot\|gdscript\|game" .claude/CLAUDE.md 2>/dev/null && PROJECT_TYPE="game"
  grep -qi "next.js\|react\|typescript\|web app" .claude/CLAUDE.md 2>/dev/null && PROJECT_TYPE="web"
fi

# ── 3. Show project status banner ────────────────────────────────────
# Only show if we're in a project (has some known file)
if $HAS_GSD || $HAS_BMAD || $HAS_CLAUDE_MD || $HAS_AGENTS_MD; then
  echo "" >&2
  echo "┌──────────────────────────────────────────────┐" >&2
  [[ -n "$PROJECT_NAME" ]] && \
  printf "│  Project: %-34s│\n" "$PROJECT_NAME" >&2 || \
  printf "│  Project: %-34s│\n" "$(basename "$(pwd)")" >&2

  # BMAD status
  if $HAS_BMAD; then
    printf "│  BMAD:    %-34s│\n" "✓ present" >&2
  else
    printf "│  BMAD:    %-34s│\n" "○ not initialised" >&2
  fi

  # GSD status
  if $HAS_GSD; then
    if [[ -n "$CURRENT_PHASE" ]]; then
      printf "│  GSD:     %-34s│\n" "✓ Phase $CURRENT_PHASE active" >&2
    else
      printf "│  GSD:     %-34s│\n" "✓ present" >&2
    fi
  else
    printf "│  GSD:     %-34s│\n" "○ not initialised" >&2
  fi

  # Missing CLAUDE.md / AGENTS.md warning
  if ! $HAS_CLAUDE_MD && ! $HAS_AGENTS_MD; then
    printf "│  %-44s│\n" "⚠️ No CLAUDE.md or AGENTS.md found" >&2
  fi

  # Infra safety reminder
  if [[ "$PROJECT_TYPE" == "infra" ]]; then
    printf "│  %-44s│\n" "⚠️ INFRA: use dry-run mode first" >&2
  fi

  # Suggestion if no framework
  if ! $HAS_BMAD && ! $HAS_GSD; then
    printf "│  %-44s│\n" "→ Say: 'set up this project' to begin" >&2
  fi

  echo "└──────────────────────────────────────────────┘" >&2
  echo "" >&2
fi

# ── 4. GSD phase reminder ─────────────────────────────────────────────
if $HAS_GSD && [[ -n "$CURRENT_PHASE" ]]; then
  echo "  Current phase: $CURRENT_PHASE — resume with /gsd:discuss-phase $CURRENT_PHASE" >&2
  echo "" >&2
fi

# ── 5. Log session context ────────────────────────────────────────────
{ echo "[$TIMESTAMP] BMAD=$HAS_BMAD GSD=$HAS_GSD Phase=$CURRENT_PHASE Type=$PROJECT_TYPE" >> "$LOG"; } 2>/dev/null || true
