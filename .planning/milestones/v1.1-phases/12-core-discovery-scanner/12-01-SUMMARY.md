---
phase: 12-core-discovery-scanner
plan: 01
subsystem: infra
tags: [bash, python3, toolkit-discovery, registry, caching, stage-tagging, yaml-parsing]

# Dependency graph
requires: []
provides:
  - "skills/toolkit-discovery.sh — bash script scanning agents, skills, hooks, MCP servers"
  - ".claude/toolkit-registry.json — full registry with schema_version:1 and flat tools array"
  - "Compact summary JSON on stdout (counts + per-stage name lists, <800B)"
  - "TTL caching (1h) — cached run returns in <100ms"
affects:
  - "13-wizard-integration — wizard-detect.sh will call this script and capture stdout"
  - "15-dynamic-catalog — wizard.md reads .claude/toolkit-registry.json for display"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "python3 inline (-c) for JSON construction and YAML frontmatter parsing"
    - "bash TTL cache check via stat -f %m (macOS) / stat -c %Y (Linux) mtime comparison"
    - "keyword regex stage tagging with all-stages zero-match fallback"

key-files:
  created:
    - "skills/toolkit-discovery.sh"
    - ".planning/phases/12-core-discovery-scanner/12-01-SUMMARY.md"
  modified:
    - ".gitignore"

key-decisions:
  - "Files without YAML frontmatter (e.g., nexus-strategy.md doc-style files) are included using filename as name — ensures agent count matches filesystem"
  - "Stage list cap reduced to 6 per stage to stay under 800-byte summary limit with real-world 176-agent toolkit (was 8 in plan; 8 entries exceeded 800B with long gsd-* agent names)"
  - "Hook names derived from unique commands (deduped by command string), not registration entry count — 24 unique commands = 24 hook entries"
  - "bash quoting: strip(chr(39)).strip(chr(34)) avoids double-quote collision inside python3 -c string for node-invoked scripts with quoted paths"

patterns-established:
  - "Toolkit scanner pattern: bash wrapper for arg parsing + TTL check, python3 inline block for all data manipulation"
  - "Stage tagging: keyword regex per stage, all-stages fallback for zero matches, MCP unconditionally all-stages"

requirements-completed: [DISC-01, DISC-02, DISC-03, DISC-04, DISC-05, MATCH-01, MATCH-02, PERF-01]

# Metrics
duration: 30min
completed: 2026-03-13
---

# Phase 12 Plan 01: Core Discovery Scanner Summary

**Bash toolkit scanner (agents/skills/hooks/MCP) with YAML frontmatter parsing, keyword stage-tagging, TTL-cached registry at .claude/toolkit-registry.json, and <800B compact summary stdout**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-03-13T15:00:00Z
- **Completed:** 2026-03-13T15:30:40Z
- **Tasks:** 2
- **Files modified:** 2 (skills/toolkit-discovery.sh created, .gitignore updated)

## Accomplishments
- Scans all 176 agents in ~/.claude/agents/*.md with YAML frontmatter parsing (handles > multi-line descriptions, inline tool lists, YAML list format)
- Scans 28 skill subdirectories in ~/.claude/skills/*/SKILL.md
- Scans 24 unique registered hooks from ~/.claude/settings.json (nested {hooks:[{command}]} structure) — not filesystem scan
- Merges MCP servers from settings.json mcpServers and installed_plugins.json (deduplicated)
- Stage tagging via keyword regex (research/planning/execution/review) with all-stages fallback for zero matches
- Writes .claude/toolkit-registry.json with schema_version:1, scanned_at ISO timestamp, counts, and flat tools array
- Compact summary stdout <800B (654B in practice) with per-stage name lists sorted by priority (Keystone → GSD → alphabetical)
- TTL cache (1h): cached run completes in ~23ms

## Task Commits

Each task was committed atomically:

1. **Task 1: Create toolkit-discovery.sh** - `ff513e8` (feat)
2. **Task 2: Validate and fix issues** - `4c8d1c6` (fix)

**Plan metadata:** (created after this summary)

## Files Created/Modified
- `skills/toolkit-discovery.sh` - Full toolkit scanner with TTL caching, 470 lines
- `.gitignore` - Added toolkit-registry.json under "Toolkit discovery (machine-specific)" section

## Decisions Made
- Files without YAML frontmatter (e.g., nexus-strategy.md, which is a doc-style file with no --- markers) are included using filename as name — ensures agent count matches `ls ~/.claude/agents/*.md | wc -l`
- Stage list cap reduced to 6 per stage (from 8 in plan spec) to satisfy the < 800-byte verification gate with real-world toolkit; 8 entries × 4 stages with names like "gsd-research-synthesizer" exceeded 800B
- Hook deduplication by unique command string: settings.json has 23 registration entries but 24 unique commands (one registration covers multiple event types sharing a command). Registry shows 24 unique hook names
- bash quoting issue: `strip('\'"')` inside `python3 -c "..."` causes bash to interpret the `"` as closing the outer string — resolved with `strip(chr(39)).strip(chr(34))`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Agent without YAML frontmatter excluded from count**
- **Found during:** Task 2 (Validation 1)
- **Issue:** nexus-strategy.md has no --- frontmatter block (it's a doc-style agent file). parse_agent_frontmatter returned None, causing it to be skipped, making registry count 175 vs expected 176
- **Fix:** Changed parse_agent_frontmatter to return `{}` (empty dict) instead of `None` when no frontmatter found — file is included with filename as name and empty description (gets all-stages fallback)
- **Files modified:** skills/toolkit-discovery.sh
- **Verification:** Agent count 176 = `ls ~/.claude/agents/*.md | wc -l`
- **Committed in:** 4c8d1c6

**2. [Rule 1 - Bug] bash quoting breaks python3 -c string for quoted script paths**
- **Found during:** Task 2 (initial test run)
- **Issue:** Hook commands like `node "/path/to/gsd-context-monitor.js"` have double-quoted paths. Using `strip('\'"')` inside `python3 -c "..."` bash string caused the `"` to terminate the bash string (syntax error at line 350)
- **Fix:** Replaced with `strip(chr(39)).strip(chr(34))` — avoids any literal quote characters in the Python code
- **Files modified:** skills/toolkit-discovery.sh
- **Verification:** Script produces valid JSON with clean hook names (gsd-context-monitor, not gsd-context-monitor.js")
- **Committed in:** 4c8d1c6

**3. [Rule 1 - Bug] Stage list cap needed reduction for byte budget**
- **Found during:** Task 2 (Validation 6)
- **Issue:** With 176 agents (many getting all-stages from zero-match fallback), 8 entries per stage × long gsd-* names = 817 bytes, exceeding the 800-byte verification gate
- **Fix:** Reduced stage list cap from 8 to 6 (still within the MATCH-02 "cap at 8" maximum bound). Result: 654 bytes
- **Files modified:** skills/toolkit-discovery.sh (both full-scan path and cache-hit path)
- **Verification:** Summary size 654B < 800B PASS
- **Committed in:** 4c8d1c6

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bugs)
**Impact on plan:** All fixes necessary for correctness. No scope creep. Core design unchanged.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- toolkit-discovery.sh is ready for Phase 13 (wizard integration) — wizard-detect.sh can call this script and capture compact summary stdout
- .claude/toolkit-registry.json schema (schema_version:1, flat tools array) is ready for Phase 15 catalog display
- --force flag available for manual refresh from wizard UX

---
*Phase: 12-core-discovery-scanner*
*Completed: 2026-03-13*
