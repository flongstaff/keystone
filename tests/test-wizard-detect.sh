#!/usr/bin/env bash
# Test suite for skills/wizard-detect.sh
# Tests the 4 automatable requirements: DETECT-01 through DETECT-04
#
# Usage: bash tests/test-wizard-detect.sh
# Returns: exit 0 if all pass, exit 1 if any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMPL_SCRIPT="$(cd "$SCRIPT_DIR/.." && pwd)/skills/wizard-detect.sh"
PASS_COUNT=0
FAIL_COUNT=0
TEST_TMPDIR=""

# ── Helpers ──────────────────────────────────────────────────────────────

cleanup() {
    if [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
}
trap cleanup EXIT

make_project() {
    # Create a fresh temp dir with git init (so git rev-parse works)
    TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/wizard-test.XXXXXX")
    cd "$TEST_TMPDIR"
    git init -q .
    # Copy the detection script
    cp "$IMPL_SCRIPT" ./wizard-detect.sh
}

get_json_field() {
    # Usage: get_json_field <file> <python_expr>
    # e.g. get_json_field state.json "d['scenario']"
    python3 -c "import json; d=json.load(open('$1')); print($2)"
}

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $test_name"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── DETECT-01: 6-scenario classification ─────────────────────────────────

echo ""
echo "=== DETECT-01: Scenario classification ==="

# Test 1a: No markers -> scenario "none"
echo ""
echo "--- Test 1a: No BMAD, no GSD -> none ---"
make_project
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "empty project classifies as 'none'" "none" "$SCENARIO"
cleanup

# Test 1b: BMAD docs present, bridge eligible -> scenario "bmad-ready"
echo ""
echo "--- Test 1b: BMAD docs + bridge eligible -> bmad-ready ---"
make_project
mkdir -p docs/stories
echo "# PRD" > docs/prd-test.md
echo "# Arch" > docs/architecture-test.md
printf "# Story\nStatus: Approved\n" > docs/stories/story-001.md
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "bmad docs with bridge eligible classifies as 'bmad-ready'" "bmad-ready" "$SCENARIO"
cleanup

# Test 1c: BMAD docs present, not bridge eligible -> scenario "bmad-incomplete"
echo ""
echo "--- Test 1c: BMAD docs, not bridge eligible -> bmad-incomplete ---"
make_project
mkdir -p docs
echo "# PRD" > docs/prd-test.md
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "bmad docs without bridge eligible classifies as 'bmad-incomplete'" "bmad-incomplete" "$SCENARIO"
cleanup

# Test 1d: GSD only -> scenario "gsd-only"
echo ""
echo "--- Test 1d: GSD only -> gsd-only ---"
make_project
mkdir -p .planning
printf "# Roadmap\n### Phase 1: Test\n" > .planning/ROADMAP.md
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "gsd roadmap only classifies as 'gsd-only'" "gsd-only" "$SCENARIO"
cleanup

# Test 1e: Both BMAD docs and GSD -> scenario "full-stack"
echo ""
echo "--- Test 1e: BMAD docs + GSD -> full-stack ---"
make_project
mkdir -p docs .planning
echo "# PRD" > docs/prd-test.md
printf "# Roadmap\n### Phase 1: Test\n" > .planning/ROADMAP.md
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "both bmad and gsd classifies as 'full-stack'" "full-stack" "$SCENARIO"
cleanup

# Test 1f: Ambiguous (empty _bmad/ dir) -> scenario "ambiguous"
echo ""
echo "--- Test 1f: Empty _bmad/ dir -> ambiguous ---"
make_project
mkdir -p _bmad
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "empty _bmad dir classifies as 'ambiguous'" "ambiguous" "$SCENARIO"
cleanup

# ── DETECT-02: Dir+content cross-validation ──────────────────────────────

echo ""
echo "=== DETECT-02: Dir+content cross-validation ==="

# Test 2a: _bmad/ dir exists but no doc files -> bmad.present=false
echo ""
echo "--- Test 2a: _bmad/ with no docs -> bmad.present=False ---"
make_project
mkdir -p _bmad
bash wizard-detect.sh > /dev/null 2>&1
BMAD_PRESENT=$(get_json_field ".claude/wizard-state.json" "d['bmad']['present']")
assert_eq "_bmad dir with no docs has bmad.present=False" "False" "$BMAD_PRESENT"
cleanup

# Test 2b: docs/ with prd file -> bmad.present=true
echo ""
echo "--- Test 2b: docs/ with prd -> bmad.present=True ---"
make_project
mkdir -p docs
echo "# PRD" > docs/prd-test.md
bash wizard-detect.sh > /dev/null 2>&1
BMAD_PRESENT=$(get_json_field ".claude/wizard-state.json" "d['bmad']['present']")
assert_eq "docs dir with prd has bmad.present=True" "True" "$BMAD_PRESENT"
cleanup

# Test 2c: _bmad-output/planning-artifacts/ with architecture doc -> bmad.present=true
echo ""
echo "--- Test 2c: _bmad-output/planning-artifacts/ with arch doc -> bmad.present=True ---"
make_project
mkdir -p _bmad-output/planning-artifacts
echo "# Arch" > _bmad-output/planning-artifacts/architecture-test.md
bash wizard-detect.sh > /dev/null 2>&1
BMAD_PRESENT=$(get_json_field ".claude/wizard-state.json" "d['bmad']['present']")
assert_eq "_bmad-output with arch doc has bmad.present=True" "True" "$BMAD_PRESENT"
cleanup

# Test 2d: JSON type check -- bmad.present is boolean, not string
echo ""
echo "--- Test 2d: bmad.present is boolean type ---"
make_project
bash wizard-detect.sh > /dev/null 2>&1
IS_BOOL=$(python3 -c "import json; d=json.load(open('.claude/wizard-state.json')); print(isinstance(d['bmad']['present'], bool))")
assert_eq "bmad.present is boolean type" "True" "$IS_BOOL"
cleanup

# ── DETECT-03: Ambiguous triggers ────────────────────────────────────────

echo ""
echo "=== DETECT-03: Ambiguous triggers ==="

# Test 3a: Empty _bmad/ dir -> ambiguous
echo ""
echo "--- Test 3a: Empty _bmad/ -> ambiguous ---"
make_project
mkdir -p _bmad
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "empty _bmad dir triggers ambiguous" "ambiguous" "$SCENARIO"
cleanup

# Test 3b: STATE.md without ROADMAP.md -> ambiguous
echo ""
echo "--- Test 3b: STATE.md without ROADMAP.md -> ambiguous ---"
make_project
mkdir -p .planning
echo "# State" > .planning/STATE.md
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "state without roadmap triggers ambiguous" "ambiguous" "$SCENARIO"
cleanup

# Test 3c: Both ambiguous triggers at once -> still ambiguous
echo ""
echo "--- Test 3c: Both BMAD and GSD ambiguous -> ambiguous ---"
make_project
mkdir -p _bmad .planning
echo "# State" > .planning/STATE.md
bash wizard-detect.sh > /dev/null 2>&1
SCENARIO=$(get_json_field ".claude/wizard-state.json" "d['scenario']")
assert_eq "both ambiguous triggers produces ambiguous" "ambiguous" "$SCENARIO"
cleanup

# Test 3d: Ambiguous scenarios have next_command="/wizard"
echo ""
echo "--- Test 3d: Ambiguous -> next_command=/wizard ---"
make_project
mkdir -p _bmad
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
assert_eq "ambiguous scenario has next_command=/wizard" "/wizard" "$NEXT_CMD"
cleanup

# ── DETECT-04: File-state ladder next_command computation ────────────────

echo ""
echo "=== DETECT-04: File-state ladder next_command ==="

# Test 4a: ROADMAP.md but no phase dirs -> discuss-phase 1
echo ""
echo "--- Test 4a: Roadmap, no phase dirs -> /gsd:discuss-phase 1 ---"
make_project
mkdir -p .planning
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
assert_eq "no phase dirs -> discuss-phase 1" "/gsd:discuss-phase 1" "$NEXT_CMD"
cleanup

# Test 4b: Phase dir exists but empty (no lifecycle files) -> discuss-phase N
echo ""
echo "--- Test 4b: Empty phase dir -> /gsd:discuss-phase N ---"
make_project
mkdir -p .planning/phases/01-setup
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
assert_eq "empty phase dir -> discuss-phase 1" "/gsd:discuss-phase 1" "$NEXT_CMD"
cleanup

# Test 4c: Phase dir with CONTEXT only -> plan-phase N
echo ""
echo "--- Test 4c: CONTEXT only -> /gsd:plan-phase N ---"
make_project
mkdir -p .planning/phases/01-setup
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
echo "# Context" > .planning/phases/01-setup/01-CONTEXT.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
PHASE_STATUS=$(get_json_field ".claude/wizard-state.json" "d['gsd']['phase_status']")
assert_eq "context only -> plan-phase 1" "/gsd:plan-phase 1" "$NEXT_CMD"
assert_eq "context only -> phase_status context-ready" "context-ready" "$PHASE_STATUS"
cleanup

# Test 4d: Phase dir with PLAN files -> execute-phase N
echo ""
echo "--- Test 4d: PLAN files -> /gsd:execute-phase N ---"
make_project
mkdir -p .planning/phases/02-build
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
echo "# Context" > .planning/phases/02-build/02-CONTEXT.md
echo "# Plan" > .planning/phases/02-build/02-01-PLAN.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
PHASE_STATUS=$(get_json_field ".claude/wizard-state.json" "d['gsd']['phase_status']")
assert_eq "plan files -> execute-phase 2" "/gsd:execute-phase 2" "$NEXT_CMD"
assert_eq "plan files -> phase_status plans-ready" "plans-ready" "$PHASE_STATUS"
cleanup

# Test 4e: Phase dir with UAT containing FAIL -> execute-phase N
echo ""
echo "--- Test 4e: UAT with failures -> /gsd:execute-phase N ---"
make_project
mkdir -p .planning/phases/01-setup
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
echo "# Plan" > .planning/phases/01-setup/01-01-PLAN.md
printf "# UAT\n- PASS: thing works\n- FAIL: thing broken\n" > .planning/phases/01-setup/01-UAT.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
PHASE_STATUS=$(get_json_field ".claude/wizard-state.json" "d['gsd']['phase_status']")
assert_eq "uat with failures -> execute-phase 1" "/gsd:execute-phase 1" "$NEXT_CMD"
assert_eq "uat with failures -> phase_status uat-failing" "uat-failing" "$PHASE_STATUS"
cleanup

# Test 4f: Phase dir with UAT passing, not last phase -> discuss-phase N+1
echo ""
echo "--- Test 4f: UAT passing, not last phase -> /gsd:discuss-phase N+1 ---"
make_project
mkdir -p .planning/phases/01-setup
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
echo "# Plan" > .planning/phases/01-setup/01-01-PLAN.md
printf "# UAT\n- PASS: all good\n" > .planning/phases/01-setup/01-UAT.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
PHASE_STATUS=$(get_json_field ".claude/wizard-state.json" "d['gsd']['phase_status']")
assert_eq "uat passing mid-project -> discuss-phase 2" "/gsd:discuss-phase 2" "$NEXT_CMD"
assert_eq "uat passing -> phase_status uat-passing" "uat-passing" "$PHASE_STATUS"
cleanup

# Test 4g: UAT passing on last phase -> complete-milestone
echo ""
echo "--- Test 4g: UAT passing on last phase -> /gsd:complete-milestone ---"
make_project
mkdir -p .planning/phases/02-build
printf "# Roadmap\n### Phase 1: Setup\n### Phase 2: Build\n" > .planning/ROADMAP.md
echo "# Plan" > .planning/phases/02-build/02-01-PLAN.md
printf "# UAT\n- PASS: all done\n" > .planning/phases/02-build/02-UAT.md
bash wizard-detect.sh > /dev/null 2>&1
NEXT_CMD=$(get_json_field ".claude/wizard-state.json" "d['next_command']")
PHASE_STATUS=$(get_json_field ".claude/wizard-state.json" "d['gsd']['phase_status']")
assert_eq "uat passing on last phase -> complete-milestone" "/gsd:complete-milestone" "$NEXT_CMD"
assert_eq "last phase uat passing -> phase_status complete" "complete" "$PHASE_STATUS"
cleanup

# Test 4h: JSON output is valid JSON with correct types
echo ""
echo "--- Test 4h: JSON output is valid with correct types ---"
make_project
mkdir -p .planning/phases/01-setup
printf "# Roadmap\n### Phase 1: Setup\n" > .planning/ROADMAP.md
echo "# Context" > .planning/phases/01-setup/01-CONTEXT.md
bash wizard-detect.sh > /dev/null 2>&1
TYPE_CHECK=$(python3 -c "
import json, sys
d = json.load(open('.claude/wizard-state.json'))
errors = []
if not isinstance(d['scenario'], str): errors.append('scenario not string')
if not isinstance(d['detected_at'], str): errors.append('detected_at not string')
if not isinstance(d['next_command'], str): errors.append('next_command not string')
if not isinstance(d['bmad']['present'], bool): errors.append('bmad.present not bool')
if not isinstance(d['gsd']['present'], bool): errors.append('gsd.present not bool')
if not isinstance(d['gsd']['roadmap'], bool): errors.append('gsd.roadmap not bool')
if not isinstance(d['bmad']['stories_total'], int): errors.append('stories_total not int')
if d['gsd']['current_phase'] is not None and not isinstance(d['gsd']['current_phase'], int): errors.append('current_phase not int|null')
if d['gsd']['phase_status'] is not None and not isinstance(d['gsd']['phase_status'], str): errors.append('phase_status not str|null')
if d['project_type'] is not None and not isinstance(d['project_type'], str): errors.append('project_type not str|null')
if errors:
    print('ERRORS: ' + ', '.join(errors))
else:
    print('OK')
")
assert_eq "json types are correct" "OK" "$TYPE_CHECK"
cleanup

# ── SUMMARY ──────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
else
    exit 0
fi
