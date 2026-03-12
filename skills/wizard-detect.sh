#!/usr/bin/env bash
# Wizard detection script — shared by wizard.md and wizard-detect.sh
# Detects project state, writes .claude/wizard-state.json, prints status box.

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

# Open-source detection (fallback for untyped projects)
if [ -z "$PROJECT_TYPE" ]; then
    if [ -f "LICENSE" ] || [ -f "CONTRIBUTING.md" ] || [ -d ".github" ]; then
        PROJECT_TYPE="open-source"
    fi
fi

[ -n "$PROJECT_TYPE" ] && PROJECT_TYPE_JSON="\"$PROJECT_TYPE\""

# -- INFRA SAFETY INJECTION ---------------------------------------------
PLANNING_CONFIG=".planning/config.json"
if [ "$PROJECT_TYPE" = "infra" ] && [ -f "$PLANNING_CONFIG" ]; then
    python3 -c "
import json
with open('$PLANNING_CONFIG', 'r') as f:
    config = json.load(f)
config['auto_advance'] = False
config['dry_run_required'] = True
with open('$PLANNING_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null
fi

# -- COMPLEXITY DETECTION -----------------------------------------------
HAS_PRD=false
HAS_ARCH=false
HAS_MULTI_REQS=false
HAS_LONG_README=false
HAS_DEP_MANAGER=false
CODE_FILE_COUNT=0
RECOMMENDED_PATH="gsd-only"

# PRD docs
PRD_SIGNAL=$(find . -maxdepth 3 \( -name "prd*.md" -o -name "product-brief*.md" \) 2>/dev/null | grep -v ".planning" | head -1 | wc -l | tr -d ' ')
[ "$PRD_SIGNAL" -gt 0 ] && HAS_PRD=true

# Architecture docs
ARCH_SIGNAL=$(find . -maxdepth 3 \( -name "architecture*.md" -o -name "design*.md" \) 2>/dev/null | grep -v ".planning" | head -1 | wc -l | tr -d ' ')
[ "$ARCH_SIGNAL" -gt 0 ] && HAS_ARCH=true

# Multiple requirement files
MULTI_REQS_COUNT=$(find docs specs -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$MULTI_REQS_COUNT" -gt 2 ] && HAS_MULTI_REQS=true

# Long README
if [ -f "README.md" ]; then
    README_LINES=$(wc -l < README.md | tr -d ' ')
    README_HEADINGS=$(grep -c "^##" README.md 2>/dev/null || echo 0)
    [ "$README_LINES" -gt 100 ] && [ "$README_HEADINGS" -gt 3 ] && HAS_LONG_README=true
fi

# Dependency manager
{ [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "Cargo.toml" ] || [ -f "go.mod" ] || [ -f "pyproject.toml" ] || [ -f "Gemfile" ]; } && HAS_DEP_MANAGER=true

# Code file count
CODE_FILE_COUNT=$(find . -maxdepth 3 -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.sh" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" -o -name "*.swift" -o -name "*.kt" \) 2>/dev/null | grep -v "node_modules\|.planning\|_bmad" | wc -l | tr -d ' ')

# Priority-ordered path determination (doc signals ALWAYS win over file count)
if [ "$HAS_PRD" = "true" ] || [ "$HAS_ARCH" = "true" ] || \
   [ "$HAS_MULTI_REQS" = "true" ] || [ "$HAS_LONG_README" = "true" ]; then
    RECOMMENDED_PATH="bmad-gsd"
elif [ "$CODE_FILE_COUNT" -lt 5 ] && [ "$HAS_DEP_MANAGER" = "false" ]; then
    RECOMMENDED_PATH="quick-task"
fi
# else RECOMMENDED_PATH stays "gsd-only" (the default)

COMPLEXITY_JSON="{\"has_prd\":$HAS_PRD,\"has_architecture\":$HAS_ARCH,\"has_multi_reqs\":$HAS_MULTI_REQS,\"has_long_readme\":$HAS_LONG_README,\"code_file_count\":$CODE_FILE_COUNT,\"has_dependency_manager\":$HAS_DEP_MANAGER}"

# -- BRIDGE ELIGIBILITY -------------------------------------------------
BRIDGE_ELIGIBLE=false
if [ "$BMAD_PRD" = "true" ] && [ "$BMAD_ARCH" = "true" ] && \
   [ "$BMAD_STORIES_TOTAL" -gt 0 ] 2>/dev/null && \
   [ "$BMAD_STORIES_APPROVED" -eq "$BMAD_STORIES_TOTAL" ] 2>/dev/null; then
    BRIDGE_ELIGIBLE=true
fi

# -- SCENARIO CLASSIFICATION --------------------------------------------
# Ambiguous check FIRST (contradictory markers)
if [ "$BMAD_AMBIGUOUS" = "true" ] || [ "$GSD_AMBIGUOUS" = "true" ]; then
    SCENARIO="ambiguous"
elif [ "$BMAD_DOCS" = "true" ] && [ "$GSD_ROADMAP" = "true" ]; then
    SCENARIO="full-stack"
elif [ "$BMAD_DOCS" = "true" ] && [ "$GSD_ROADMAP" = "false" ] && [ "$BRIDGE_ELIGIBLE" = "true" ]; then
    SCENARIO="bmad-ready"
elif [ "$BMAD_DOCS" = "true" ] && [ "$GSD_ROADMAP" = "false" ]; then
    SCENARIO="bmad-incomplete"
elif [ "$BMAD_DOCS" = "false" ] && [ "$GSD_ROADMAP" = "true" ]; then
    SCENARIO="gsd-only"
else
    SCENARIO="none"
fi

# -- NEXT COMMAND -------------------------------------------------------
case "$SCENARIO" in
    none|bmad-ready|bmad-incomplete|ambiguous)
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

# -- IS_RESET DETECTION -------------------------------------------------
# Must run BEFORE JSON write — reads previous wizard-state.json
IS_RESET=false
PREV_STATE=".claude/wizard-state.json"
if [ -f "$PREV_STATE" ]; then
    PREV_DETECTED=$(python3 -c "
import json, sys
try:
    with open('$PREV_STATE') as f:
        d = json.load(f)
    print(d.get('detected_at', ''))
except Exception:
    print('')
" 2>/dev/null)
    if [ -n "$PREV_DETECTED" ]; then
        # macOS: date -j -f; Linux: date -d; fallback: 0
        PREV_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$PREV_DETECTED" "+%s" 2>/dev/null || \
                     date -d "$PREV_DETECTED" "+%s" 2>/dev/null || echo 0)
        NOW_EPOCH=$(date -u +%s)
        ELAPSED=$((NOW_EPOCH - PREV_EPOCH))
        [ "$ELAPSED" -gt 30 ] && IS_RESET=true
    fi
fi

# -- JSON WRITE ---------------------------------------------------------
DETECTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p ".claude"

cat > ".claude/wizard-state.json" << EOF
{
  "scenario": "$SCENARIO",
  "detected_at": "$DETECTED_AT",
  "next_command": "$NEXT_CMD",
  "project_type": $PROJECT_TYPE_JSON,
  "complexity_signal": $COMPLEXITY_JSON,
  "recommended_path": "$RECOMMENDED_PATH",
  "bridge_eligible": $BRIDGE_ELIGIBLE,
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

# -- ORIENTATION CONTEXT (GSD scenarios) ---------------------------------
STOPPED_AT=""
LAST_ACTIVITY=""
PHASE_NAME=""

if [ "$GSD_STATE" = "true" ] && [ -f ".planning/STATE.md" ]; then
    STOPPED_AT=$(grep "^stopped_at:" .planning/STATE.md 2>/dev/null | head -1 | sed 's/^stopped_at: *//')
    LAST_ACTIVITY=$(grep "^last_activity:" .planning/STATE.md 2>/dev/null | head -1 | sed 's/^last_activity: *//')
fi

if [ "$GSD_ROADMAP" = "true" ] && [ -n "$GSD_CURRENT_PHASE_JSON" ] && [ "$GSD_CURRENT_PHASE_JSON" != "null" ]; then
    # Extract phase name from ### Phase N: Name heading
    PHASE_NAME=$(grep "^### Phase $GSD_CURRENT_PHASE_JSON" .planning/ROADMAP.md 2>/dev/null | head -1 | sed "s/^### Phase $GSD_CURRENT_PHASE_JSON[: ]*//" | sed 's/ *$//')
fi

# -- RECOMMENDED PATH LABEL ---------------------------------------------
REC_LABEL=""
case "$RECOMMENDED_PATH" in
    bmad-gsd)   REC_LABEL="BMAD+GSD (planning docs detected)" ;;
    gsd-only)   REC_LABEL="GSD direct (code project)" ;;
    quick-task) REC_LABEL="Quick task (minimal project)" ;;
esac

# -- STATUS BOX ---------------------------------------------------------
echo ""
printf "┌──────────────────────────────────────────────────────────┐\n"
if [ "$IS_RESET" = "true" ]; then
    printf "│  Welcome back.                                           │\n"
fi
printf "│  Project: %-46s│\n" "$PROJECT_NAME"
printf "│  Scenario: %-45s│\n" "$SCENARIO"
if [ -n "$PROJECT_TYPE" ]; then
    printf "│  Type: %-49s│\n" "$PROJECT_TYPE"
fi
if [ "$PROJECT_TYPE" = "infra" ]; then
    printf "│  IT Safety: active                                       │\n"
fi
if [ -n "$PHASE_NAME" ]; then
    PHASE_LABEL="Phase $GSD_CURRENT_PHASE_JSON: $PHASE_NAME"
    printf "│  %-55s│\n" "$PHASE_LABEL"
fi
if [ -n "$STOPPED_AT" ]; then
    printf "│  Last: %-49s│\n" "$STOPPED_AT"
fi
if [ -n "$REC_LABEL" ]; then
    printf "│  Recommended: %-42s│\n" "$REC_LABEL"
fi
if [ "$SCENARIO" = "bmad-ready" ] || [ "$SCENARIO" = "bmad-incomplete" ]; then
    if [ "$BRIDGE_ELIGIBLE" = "true" ]; then
        printf "│  Bridge: READY (all planning complete)                   │\n"
    else
        MISSING=""
        [ "$BMAD_PRD" = "false" ] && MISSING="${MISSING}PRD "
        [ "$BMAD_ARCH" = "false" ] && MISSING="${MISSING}Architecture "
        if [ "$BMAD_STORIES_TOTAL" -eq 0 ] 2>/dev/null; then
            MISSING="${MISSING}Stories "
        elif [ "$BMAD_STORIES_APPROVED" -lt "$BMAD_STORIES_TOTAL" ] 2>/dev/null; then
            MISSING="${MISSING}${BMAD_STORIES_APPROVED}/${BMAD_STORIES_TOTAL}-approved "
        fi
        printf "│  Bridge: BLOCKED (missing: %s)%*s│\n" "$MISSING" $((27 - ${#MISSING})) ""
    fi
fi
printf "│                                                          │\n"
printf "│  Next: %-49s│\n" "$NEXT_CMD"
printf "└──────────────────────────────────────────────────────────┘\n"
echo ""
