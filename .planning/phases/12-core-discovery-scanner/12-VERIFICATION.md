---
phase: 12-core-discovery-scanner
verified: 2026-03-13T16:45:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 12: Core Discovery Scanner Verification Report

**Phase Goal:** Build toolkit-discovery.sh: scan agents, skills, hooks, MCP servers — stage-tagged JSON registry with TTL caching
**Verified:** 2026-03-13T16:45:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running `bash skills/toolkit-discovery.sh` produces valid JSON to stdout and writes `.claude/toolkit-registry.json` | VERIFIED | `python3 -m json.tool` passes on both; registry exists at `.claude/toolkit-registry.json` |
| 2 | Registry contains all agents, skills, registered hooks, and MCP servers from both sources | VERIFIED | agents=176 (matches `ls ~/.claude/agents/*.md`), skills=28 (matches dirs with SKILL.md), hooks=24 (matches unique commands in settings.json), mcp=0 (mcpServers is empty, installed_plugins.json absent) |
| 3 | Every discovered entry has a non-empty stages[] array; zero-match entries and all MCP entries get all four stages | VERIFIED | Zero entries with empty stages (confirmed programmatically); MCP entries unconditionally assigned all four stages; hook entries get keyword-matched or fallback |
| 4 | Compact summary stdout contains counts per type and stage-grouped tool names capped within 5-8 per stage | VERIFIED | stdout JSON has `version`, `counts`, `by_stage` keys; max 6 names per stage (within 5-8 MATCH-02 range); 654 bytes (under 800B limit) |
| 5 | Re-running within 1 hour returns cached result in under 0.1 seconds | VERIFIED | Cached run completes in 24ms (0.024s total wall time); TTL check uses `stat -f %m` (macOS) with 3600s threshold |
| 6 | Running when `~/.claude/agents/` does not exist produces valid empty-catalog JSON with exit 0 | VERIFIED | Code path at line 252: `if AGENTS_DIR.is_dir():` — agents stays `[]` when dir absent; exit 0 always set at line 469 |
| 7 | toolkit-registry.json is gitignored | VERIFIED | `.gitignore` line 38: `toolkit-registry.json` under `# Toolkit discovery (machine-specific)` section |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/toolkit-discovery.sh` | Full toolkit scanner with TTL caching, min 150 lines | VERIFIED | 469 lines, executable (`-rwxr-xr-x`), substantive implementation |
| `.gitignore` | Contains `toolkit-registry.json` exclusion | VERIFIED | Line 38, under dedicated `# Toolkit discovery (machine-specific)` comment |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `skills/toolkit-discovery.sh` | `~/.claude/agents/*.md` | YAML frontmatter parsing | WIRED | `AGENTS_DIR.glob('*.md')` at line 253; `parse_agent_frontmatter()` function at line 113 |
| `skills/toolkit-discovery.sh` | `~/.claude/settings.json` | mcpServers extraction and hooks registrations | WIRED | `settings.get('mcpServers', {})` at line 379; `settings.get('hooks', {})` at line 325 |
| `skills/toolkit-discovery.sh` | `~/.claude/installed_plugins.json` | marketplace plugin scanning | WIRED | `PLUGINS_FILE.exists()` check at line 386; list/dict both handled; deduplication by name |
| `skills/toolkit-discovery.sh` | `.claude/toolkit-registry.json` | JSON write on scan completion | WIRED | `REGISTRY_PATH.write_text(json.dumps(registry, indent=2))` at line 438; `mkdir -p .claude` at line 71 |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| DISC-01 | Dynamically scans `~/.claude/agents/` parsing YAML frontmatter name and description | SATISFIED | 176 agents scanned; `parse_agent_frontmatter()` handles inline, multi-line `>`, YAML list tools, files without frontmatter |
| DISC-02 | Scans MCP servers from `settings.json` mcpServers and `installed_plugins.json` | SATISFIED | Both sources checked; deduplication by name; mcp=0 is correct (mcpServers empty, plugins file absent) |
| DISC-03 | Scans `~/.claude/skills/` for installed skills with SKILL.md metadata | SATISFIED | 28 skills scanned from subdirs containing SKILL.md; standalone .md files skipped |
| DISC-04 | Scans registered hooks (source of truth: settings.json registrations) | SATISFIED | 24 unique hook commands from settings.json `hooks` config; filesystem scan of `~/.claude/hooks/` NOT used; 6 unregistered scripts correctly excluded |
| DISC-05 | Discovery writes full catalog to `toolkit-registry.json` (machine-specific, gitignored) | SATISFIED | Registry written at `.claude/toolkit-registry.json`; gitignored; `schema_version: 1`; flat `tools` array |
| MATCH-01 | Maps discovered tools to workflow stages via keyword matching on description fields | SATISFIED | `assign_stages()` at line 103; 4 stage keyword patterns; all-stages fallback for zero matches; name field also matched |
| MATCH-02 | Stage filtering caps injected pointers at 5-8 per spawn | SATISFIED | Stage lists capped at 6 per stage (within 5-8 requirement range); 654B summary (under 800B) |
| PERF-01 | Discovery uses TTL-gated caching (skip rescan when registry is fresh) | SATISFIED | Cache check at lines 19-68; mtime via `stat -f %m` (macOS) / `stat -c %Y` (Linux); 3600s TTL; `--force` bypass; cached run: 24ms |

**All 8 requirement IDs from PLAN frontmatter accounted for — all SATISFIED.**

**Orphaned requirements check:** No additional Phase 12 requirements in REQUIREMENTS.md traceability table beyond the 8 listed above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `skills/toolkit-discovery.sh` | 124 | `return {}` | INFO | Intentional: no-frontmatter agent files included with filename as name. Documented decision in SUMMARY.md. Not a stub. |

No TODO/FIXME/PLACEHOLDER patterns. No unimplemented stubs. No empty handlers.

### Human Verification Required

None — all requirements are programmatically verifiable for this phase. Phase 12 produces file artifacts and JSON output, not UI behavior.

### Gaps Summary

No gaps. All 7 observable truths verified, all 8 requirements satisfied, all key links wired.

**Notable observations:**

1. **MCP count of 0 is correct.** The user's `~/.claude/settings.json` has an empty `mcpServers` object and `~/.claude/installed_plugins.json` does not exist. The script handles both cases gracefully.

2. **Stage cap deviation from plan is valid.** The PLAN specified "capped at 8" but MATCH-02 requirement says "5-8". The implementation uses 6, which satisfies the requirement and stays under the 800B summary budget with the real 176-agent toolkit.

3. **Hook deduplication confirmed correct.** 24 filesystem hook files exist in `~/.claude/hooks/`, but 6 are unregistered (gsd-statusline, hook-utils, play-sound, skill-activation-prompt, statusline, sync-pi-after-update). Registry correctly includes only the 24 settings.json-registered commands (some of which reference scripts outside `~/.claude/hooks/` such as openviking-memory hooks and standalone .sh files).

4. **Commits verified.** Both documented commits exist: `ff513e8` (feat: initial script) and `4c8d1c6` (fix: quote-stripping and agent count bugs).

---

_Verified: 2026-03-13T16:45:00Z_
_Verifier: Claude (gsd-verifier)_
