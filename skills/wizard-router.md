---
name: wizard-router
description: >
  Silent detection skill. Run when: /wizard is invoked.
  Detects project state (BMAD/GSD/both/neither/ambiguous), classifies scenario,
  writes .claude/wizard-state.json, displays compact status box with next command.
model: sonnet
tools:
  - Read
  - Bash
  - Write
maxTurns: 5
---

# Wizard Router — Silent Detection

You are a silent detection skill. Do not narrate. Do not ask questions. Detect project state, write JSON, display status box. Nothing else.

## Instructions

Run the single bash block below. It performs all detection and writes `.claude/wizard-state.json`. Then display the status box output it produces.

```bash
# -- BMAD MARKERS -------------------------------------------------------
BMAD_DIR=false
BMAD_DOCS=false
BMAD_AMBIGUOUS=false

{ [ -d "_bmad" ] || [ -d ".bmad" ] || [ -d "_bmad-output" ]; } && BMAD_DIR=true

# Check standard docs/ paths AND _bmad-output/ paths (find-based for zsh compat)
BMAD_FILE_COUNT=$(find docs _bmad-output/planning-artifacts -maxdepth 2 \
    \( -name "prd*.md" -o -name "architecture*.md" -o -name "product-brief*.md" -o -name "story-*.md" \) \
    2>/dev/null | head -1 | wc -l | tr -d ' ')
[ "$BMAD_FILE_COUNT" -gt 0 ] && BMAD_DOCS=true

[ "$BMAD_DIR" = "true" ] && [ "$BMAD_DOCS" = "false" ] && BMAD_AMBIGUOUS=true

# -- BMAD DETAIL --------------------------------------------------------
BMAD_PRD=false
BMAD_ARCH=false
BMAD_STORIES_TOTAL=0
BMAD_STORIES_APPROVED=0
BMAD_STORIES_DONE=0

if [ "$BMAD_DOCS" = "true" ]; then
    PRD_COUNT=$(find docs _bmad-output/planning-artifacts -maxdepth 2 -name "prd*.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$PRD_COUNT" -gt 0 ] && BMAD_PRD=true
    ARCH_COUNT=$(find docs _bmad-output/planning-artifacts -maxdepth 2 -name "architecture*.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$ARCH_COUNT" -gt 0 ] && BMAD_ARCH=true
    BMAD_STORIES_TOTAL=$(find docs/stories _bmad-output/stories -maxdepth 1 -name "story-*.md" 2>/dev/null | wc -l | tr -d ' ')
    BMAD_STORIES_APPROVED=$(grep -rl "Status: Approved" docs/stories/ _bmad-output/stories/ 2>/dev/null | wc -l | tr -d ' ')
    BMAD_STORIES_DONE=$(grep -rl "Status: Done\|Status: Complete" docs/stories/ _bmad-output/stories/ 2>/dev/null | wc -l | tr -d ' ')
fi

# -- GSD MARKERS --------------------------------------------------------
GSD_ROADMAP=false
GSD_STATE=false
GSD_AMBIGUOUS=false

[ -f ".planning/ROADMAP.md" ] && GSD_ROADMAP=true
[ -f ".planning/STATE.md" ]   && GSD_STATE=true

[ "$GSD_STATE" = "true" ] && [ "$GSD_ROADMAP" = "false" ] && GSD_AMBIGUOUS=true

# -- GSD DETAIL ---------------------------------------------------------
GSD_CURRENT_PHASE_JSON=null
GSD_TOTAL_PHASES_JSON=null
GSD_PHASE_STATUS_JSON=null
GSD_NEXT_CMD="/gsd:discuss-phase 1"
GSD_PHASE_STATUS=""

if [ "$GSD_ROADMAP" = "true" ]; then
    # Count total phases from ROADMAP.md using ### Phase headings
    TOTAL=$(grep -c "^### Phase" .planning/ROADMAP.md 2>/dev/null || echo 0)
    [ "$TOTAL" -gt 0 ] && GSD_TOTAL_PHASES_JSON=$TOTAL

    # File-state ladder: find latest phase dir
    LATEST_PHASE_DIR=$(find .planning/phases -maxdepth 1 -type d -name "[0-9]*" 2>/dev/null | sort -V | tail -1)

    if [ -n "$LATEST_PHASE_DIR" ]; then
        # Extract phase number (strip leading zeros for arithmetic)
        PHASE_NUM=$(basename "$LATEST_PHASE_DIR" | grep -oE '^[0-9]+' | sed 's/^0*//')
        [ -z "$PHASE_NUM" ] && PHASE_NUM=0

        GSD_CURRENT_PHASE_JSON=$PHASE_NUM

        # Check lifecycle files using find (zsh-safe)
        HAS_CONTEXT=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-CONTEXT.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')
        HAS_PLAN=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-PLAN*.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')
        HAS_UAT=$(find "$LATEST_PHASE_DIR" -maxdepth 1 -name "*-UAT.md" 2>/dev/null | head -1 | wc -l | tr -d ' ')

        if [ "$HAS_UAT" -gt 0 ]; then
            FAIL_COUNT=$(grep -c "FAIL\|fail" "$LATEST_PHASE_DIR"/*-UAT.md 2>/dev/null || echo 0)
            if [ "$FAIL_COUNT" -gt 0 ]; then
                GSD_NEXT_CMD="/gsd:execute-phase $PHASE_NUM"
                GSD_PHASE_STATUS="uat-failing"
            else
                # Check if all phases done
                TOTAL_RAW=$(grep -c "^### Phase" .planning/ROADMAP.md 2>/dev/null || echo 0)
                if [ "$PHASE_NUM" -ge "$TOTAL_RAW" ] && [ "$TOTAL_RAW" -gt 0 ]; then
                    GSD_NEXT_CMD="/gsd:complete-milestone"
                    GSD_PHASE_STATUS="complete"
                else
                    NEXT_NUM=$((PHASE_NUM + 1))
                    GSD_NEXT_CMD="/gsd:discuss-phase $NEXT_NUM"
                    GSD_PHASE_STATUS="uat-passing"
                fi
            fi
        elif [ "$HAS_PLAN" -gt 0 ]; then
            GSD_NEXT_CMD="/gsd:execute-phase $PHASE_NUM"
            GSD_PHASE_STATUS="plans-ready"
        elif [ "$HAS_CONTEXT" -gt 0 ]; then
            GSD_NEXT_CMD="/gsd:plan-phase $PHASE_NUM"
            GSD_PHASE_STATUS="context-ready"
        else
            GSD_NEXT_CMD="/gsd:discuss-phase $PHASE_NUM"
            GSD_PHASE_STATUS="executing"
        fi

        [ -n "$GSD_PHASE_STATUS" ] && GSD_PHASE_STATUS_JSON="\"$GSD_PHASE_STATUS\""
    else
        # Has ROADMAP.md but no phase dirs yet
        GSD_NEXT_CMD="/gsd:discuss-phase 1"
        GSD_PHASE_STATUS_JSON=null
    fi
fi

# -- PROJECT TYPE -------------------------------------------------------
PROJECT_TYPE=""
PROJECT_TYPE_JSON=null

# Check CLAUDE.md for type keywords
CLAUDE_FILE=""
[ -f ".claude/CLAUDE.md" ] && CLAUDE_FILE=".claude/CLAUDE.md"
[ -f "CLAUDE.md" ] && CLAUDE_FILE="CLAUDE.md"

if [ -n "$CLAUDE_FILE" ]; then
    grep -qi "infra\|sysadmin\|devops\|ansible\|terraform\|powershell" "$CLAUDE_FILE" 2>/dev/null && PROJECT_TYPE="infra"
    grep -qi "godot\|gdscript\|game" "$CLAUDE_FILE" 2>/dev/null && PROJECT_TYPE="game"
    grep -qi "next\.js\|react\|typescript\|web app" "$CLAUDE_FILE" 2>/dev/null && PROJECT_TYPE="web"
fi

# Check project name from git or pwd
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
echo "$PROJECT_NAME" | grep -iqE "infra|deploy|ad|gpo|intune|onboard|offboard|entra" && PROJECT_TYPE="infra"
echo "$PROJECT_NAME" | grep -iqE "game|godot" && PROJECT_TYPE="game"

# Check for docs-only pattern
if [ -z "$PROJECT_TYPE" ]; then
    if [ "$BMAD_DOCS" = "false" ] && [ "$GSD_ROADMAP" = "false" ]; then
        DOC_COUNT=$(find . -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        DOCS_DIR_COUNT=$(find docs -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        DOC_COUNT=$((DOC_COUNT + DOCS_DIR_COUNT))
        [ "$DOC_COUNT" -gt 2 ] && PROJECT_TYPE="docs"
    fi
fi

[ -n "$PROJECT_TYPE" ] && PROJECT_TYPE_JSON="\"$PROJECT_TYPE\""

# -- SCENARIO CLASSIFICATION --------------------------------------------
# Ambiguous check FIRST (contradictory markers)
if [ "$BMAD_AMBIGUOUS" = "true" ] || [ "$GSD_AMBIGUOUS" = "true" ]; then
    SCENARIO="ambiguous"
elif [ "$BMAD_DOCS" = "true" ] && [ "$GSD_ROADMAP" = "true" ]; then
    SCENARIO="full-stack"
elif [ "$BMAD_DOCS" = "true" ] && [ "$GSD_ROADMAP" = "false" ]; then
    SCENARIO="bmad-only"
elif [ "$BMAD_DOCS" = "false" ] && [ "$GSD_ROADMAP" = "true" ]; then
    SCENARIO="gsd-only"
else
    SCENARIO="none"
fi

# -- NEXT COMMAND -------------------------------------------------------
case "$SCENARIO" in
    none|bmad-only|ambiguous)
        NEXT_CMD="/wizard"
        ;;
    gsd-only|full-stack)
        NEXT_CMD="$GSD_NEXT_CMD"
        ;;
esac

# -- BOOLEAN JSON HELPERS -----------------------------------------------
# Derive JSON-ready booleans for nested objects
BMAD_PRESENT=$BMAD_DOCS
GSD_PRESENT=$GSD_ROADMAP

# -- JSON WRITE ---------------------------------------------------------
DETECTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p ".claude"

cat > ".claude/wizard-state.json" << EOF
{
  "scenario": "$SCENARIO",
  "detected_at": "$DETECTED_AT",
  "next_command": "$NEXT_CMD",
  "project_type": $PROJECT_TYPE_JSON,
  "bmad": {
    "present": $BMAD_PRESENT,
    "prd": $BMAD_PRD,
    "architecture": $BMAD_ARCH,
    "stories_total": $BMAD_STORIES_TOTAL,
    "stories_approved": $BMAD_STORIES_APPROVED,
    "stories_done": $BMAD_STORIES_DONE
  },
  "gsd": {
    "present": $GSD_PRESENT,
    "roadmap": $GSD_ROADMAP,
    "state": $GSD_STATE,
    "current_phase": $GSD_CURRENT_PHASE_JSON,
    "total_phases": $GSD_TOTAL_PHASES_JSON,
    "phase_status": $GSD_PHASE_STATUS_JSON
  }
}
EOF

# -- STATUS BOX ---------------------------------------------------------
echo ""
printf "┌──────────────────────────────────────────────────────────┐\n"
printf "│  Project: %-46s│\n" "$PROJECT_NAME"
printf "│  Scenario: %-45s│\n" "$SCENARIO"
if [ -n "$PROJECT_TYPE" ]; then
    printf "│  Type: %-49s│\n" "$PROJECT_TYPE"
fi
printf "│                                                          │\n"
printf "│  Next: %-49s│\n" "$NEXT_CMD"
printf "└──────────────────────────────────────────────────────────┘\n"
echo ""
echo "  Run: $NEXT_CMD"
```

After the bash block completes, the status box output above is your complete response. The skill is done — do not add commentary, menus, or follow-up questions.
