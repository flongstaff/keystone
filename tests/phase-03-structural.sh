#!/usr/bin/env bash
# Phase 3 structural checks — new-project-routing
# Verifies all 8 tasks in the Phase 3 Per-Task Verification Map (tasks 03-01-01 through 03-02-03)
# that have automatable commands.
#
# Usage:  bash tests/phase-03-structural.sh
# Returns: exit 0 if all checks pass, exit 1 if any fail

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $1"; echo "    $2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Helper: extract a section from wizard.md by heading pattern (between two ### headings)
extract_section() {
    local file="$1" start_pattern="$2"
    # Extract from start_pattern line to the next ### heading (exclusive), or EOF
    sed -n "/${start_pattern}/,/^### /{/^### /!p; /${start_pattern}/p;}" "$file"
}

echo ""
echo "=== Phase 3 Structural Checks ==="

# ── 03-01-01: wizard-state.json has complexity_signal and recommended_path ──────────
echo ""
echo "--- 03-01-01: wizard-state.json contains complexity_signal and recommended_path ---"
# wizard-state.json is generated at runtime by wizard-detect.sh and is .gitignored.
# Skip this check in CI where the file won't exist.
if [ ! -f "$REPO_ROOT/.claude/wizard-state.json" ]; then
    echo "  SKIP: wizard-state.json not present (generated at runtime, .gitignored)"
else
    RESULT=$(python3 -c "
import json, sys
try:
    d = json.load(open('$REPO_ROOT/.claude/wizard-state.json'))
    missing = [k for k in ('complexity_signal', 'recommended_path') if k not in d]
    if missing:
        print('FAIL: missing fields: ' + ', '.join(missing))
    else:
        print('PASS')
except Exception as e:
    print('FAIL: ' + str(e))
" 2>/dev/null)
    if [ "$RESULT" = "PASS" ]; then
        pass "wizard-state.json contains complexity_signal and recommended_path"
    else
        fail "wizard-state.json missing required fields" "$RESULT"
    fi
fi

# ── 03-01-05: all 3 path options always visible in none-scenario menu ────────────────
echo ""
echo "--- 03-01-05: all 3 path options visible in none-scenario block of wizard.md ---"
# Extract the "Scenario: none" section using pattern matching instead of line numbers
NONE_SECTION=$(extract_section "$REPO_ROOT/skills/wizard.md" "^### Scenario: none")
BMAD_COUNT=$(echo "$NONE_SECTION" | grep -c "Start with BMAD" || true)
GSD_COUNT=$(echo "$NONE_SECTION" | grep -c "Start with GSD" || true)
QT_COUNT=$(echo "$NONE_SECTION" | grep -c "Quick task" || true)
if [ "$BMAD_COUNT" -ge 3 ] && [ "$GSD_COUNT" -ge 3 ] && [ "$QT_COUNT" -ge 3 ]; then
    pass "all 3 path options appear in each recommendation branch of none-scenario"
else
    fail "none-scenario missing option repetitions across recommendation branches" "BMAD:$BMAD_COUNT GSD:$GSD_COUNT QuickTask:$QT_COUNT (each should be >= 3)"
fi

# ── 03-01 general: complexity_signal and recommended_path present in wizard-detect.sh ─
echo ""
echo "--- 03-01 router check: complexity_signal and recommended_path in wizard-detect.sh ---"
if grep -q "complexity_signal" "$REPO_ROOT/skills/wizard-detect.sh" && grep -q "recommended_path" "$REPO_ROOT/skills/wizard-detect.sh"; then
    pass "wizard-detect.sh contains complexity_signal and recommended_path"
else
    fail "wizard-detect.sh missing complexity_signal or recommended_path" "grep returned no match"
fi

# ── 03-01 general: Recommended tag and Domain agent present in wizard.md ────────────
echo ""
echo "--- 03-01 + 03-02 wizard.md: Recommended tags and Domain agent banner present ---"
if grep -q "Recommended" "$REPO_ROOT/skills/wizard.md" && grep -q "Domain agent" "$REPO_ROOT/skills/wizard.md"; then
    pass "wizard.md contains Recommended tags and Domain agent banner"
else
    fail "wizard.md missing Recommended tags or Domain agent banner" "grep returned no match"
fi

# ── 03-02-02: open-source detection code lives in wizard-detect.sh ──────────────────
echo ""
echo "--- 03-02-02: open-source / LICENSE / CONTRIBUTING / .github detection in wizard-detect.sh ---"
if grep -q "open-source\|LICENSE\|CONTRIBUTING\|\.github" "$REPO_ROOT/skills/wizard-detect.sh"; then
    pass "wizard-detect.sh contains open-source detection code"
else
    fail "wizard-detect.sh does not contain open-source detection" "expected: open-source|LICENSE|CONTRIBUTING|.github"
fi

# ── 03-02-03: banner sections in wizard.md do not contain AskUserQuestion ───────────
echo ""
echo "--- 03-02-03: full-stack banner block does not use AskUserQuestion ---"
# Extract the full-stack scenario banner — content between heading and first "Present a menu"
FULLSTACK_BANNER=$(sed -n '/^### Scenario: full-stack/,/Present a menu/{ /Present a menu/!p; }' "$REPO_ROOT/skills/wizard.md")
if echo "$FULLSTACK_BANNER" | grep -q "AskUserQuestion"; then
    fail "full-stack banner block unexpectedly uses AskUserQuestion" "found AskUserQuestion before first menu"
else
    pass "full-stack banner block does not use AskUserQuestion"
fi

echo ""
echo "--- 03-02-03: bmad-ready banner block does not use AskUserQuestion ---"
# Extract bmad-ready section banner — content between heading and first "Present a menu"
BMADREADY_BANNER=$(sed -n '/^### Scenario: bmad-ready/,/Present a menu/{ /Present a menu/!p; }' "$REPO_ROOT/skills/wizard.md")
if echo "$BMADREADY_BANNER" | grep -q "AskUserQuestion"; then
    fail "bmad-ready banner block unexpectedly uses AskUserQuestion" "found AskUserQuestion before first menu"
else
    pass "bmad-ready banner block does not use AskUserQuestion"
fi

# ── summary ─────────────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
else
    exit 0
fi
