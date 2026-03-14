# Phase 15: Dynamic Catalog Display — Research

**Researched:** 2026-03-13
**Domain:** wizard.md instruction authoring; toolkit-registry.json consumption; Markdown-as-code display logic
**Confidence:** HIGH — all findings from direct analysis of live project files; no web search required

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Display grouping:**
- Primary axis: stage-first (Research / Planning / Execution / Review), not type-first
- Within each stage: Keystone tools shown first (flat sub-section), then Installed tools sub-grouped by type (Agents / Skills / MCP)
- Tools appearing in multiple stages show up in each relevant stage group
- Per-stage entry cap: Claude's discretion based on actual registry size at runtime
- Summary header at top with counts: `**N** agents · **N** skills · **N** hooks · **N** MCP servers`

**Entry format:**
- Uniform format for all tools: `- name — one-liner description` (no activation commands)
- Activation commands dropped from dynamic entries — registry doesn't carry them, and they add noise at scale
- MCP entries suffixed with `(configured)` — consistent with CONF-03 injection language
- Active domain agent marking preserved: domain agent matching `project_type` gets `(active)` appended

**Fallback behavior:**
- Show hardcoded Phase 7 catalog when `toolkit-registry.json` is missing OR fails JSON parse (covers fresh installs and corruption)
- Fallback uses Phase 7's original type-first format as-is — no re-grouping by stage
- Subtle footer note indicates data source:
  - Dynamic: `Source: toolkit-registry.json (scanned [timestamp])`
  - Fallback: `Showing built-in catalog. Run toolkit-discovery.sh for full scan.`
- Selecting "Discover tools" triggers `bash skills/toolkit-discovery.sh` if registry is stale (past TTL), refreshing before display

**Parity check:**
- Verification step in the execution plan (not runtime assertion): read hardcoded entries, read registry, assert all 18 Keystone tools (11 agents + 4 skills + 3 hooks) appear in dynamic output
- Hardcoded catalog text kept in wizard.md as the fallback — never removed (SC #3 requires it)
- Deduplicate: consolidate 4 duplicate catalog blocks into one shared "Display Catalog" instruction block
- All 4 Option 4 handlers reference the shared block instead of inlining catalog text

**Wizard.md structure:**
- New shared "Display Catalog" instruction block near bottom of wizard.md
- Logic sequence: run toolkit-discovery.sh (refreshes if stale) → read registry → if valid: render stage-first → if invalid: show hardcoded fallback → re-present calling menu
- All 4 menu variants' Option 4 handlers point to the shared block
- Hardcoded fallback lives inside the shared block (single copy)

### Claude's Discretion

- Per-stage entry cap threshold and "... and N more" wording
- Exact markdown formatting (spacing, separator lines, indentation depth)
- Ordering of tools within each sub-section (alphabetical vs registry order)
- How to handle stages with zero tools (skip the section vs show empty)
- Python3 vs bash for JSON parsing of toolkit-registry.json

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CAT-01 | "Discover tools" reads `toolkit-registry.json` for dynamic display | Registry schema fully documented below; Bash call pattern from wizard-detect.sh precedent |
| CAT-02 | Catalog displays tools grouped by stage relevance and category | Stage fields in registry entries (`stages: [...]`); grouping logic designed below |
| CAT-03 | Hardcoded Phase 7 catalog remains as fallback when registry is absent or malformed | Fallback text already in wizard.md (4 copies); consolidation into one block documented below |
</phase_requirements>

---

## Summary

Phase 15 is a wizard.md instruction authoring task. The output is modified Markdown-as-code in `skills/wizard.md` — not a software implementation. The work consists of three coordinated edits: (1) consolidate 4 duplicate catalog blocks into one shared "Display Catalog" instruction block, (2) write dynamic rendering logic inside that block that reads `toolkit-registry.json` via Bash + Python3, and (3) update the Context Budget Discipline section to explicitly permit the Bash + registry read for Option 4.

All upstream infrastructure is complete. The `toolkit-registry.json` schema (Phase 12) is stable, well-structured, and suitable for direct consumption. The registry exists on disk at `.claude/toolkit-registry.json` with 228 tools (176 agents, 28 skills, 24 hooks, 0 MCP on this machine). Each tool entry carries `name`, `type`, `description`, and `stages[]` fields — exactly what the display needs.

The primary technical tension to resolve: wizard.md's current Context Budget Discipline section explicitly prohibits running bash and reading toolkit-registry.json. This constraint will need a targeted exception carved out for Option 4 ("Discover tools" is the PERF-03 designated lazy-load moment). All other wizard.md behavior remains unchanged.

**Primary recommendation:** Write the shared "Display Catalog" block as an instruction section at the bottom of wizard.md. Inside it: Bash call to run toolkit-discovery.sh, Python3 inline script to read and render the registry, hardcoded fallback block, and re-present-menu instruction. Point all 4 Option 4 handlers to this section with a single-line redirect.

---

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `skills/wizard.md` | in-repo | The skill file being modified | Single authoritative source for wizard behavior |
| `toolkit-registry.json` | schema_version 1 | Source of truth for installed tools | Written by Phase 12 toolkit-discovery.sh; stable schema |
| Python3 | system (3.x) | JSON parsing and rendering in Bash-embedded scripts | Used throughout wizard-detect.sh and toolkit-discovery.sh — established precedent |
| Bash | system | Run toolkit-discovery.sh from Option 4 | wizard.md has Bash in tools list; already used for spawning |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `skills/toolkit-discovery.sh` | in-repo | Refresh toolkit-registry.json if stale (TTL check built-in) | Called at start of "Display Catalog" block before reading registry |
| `wizard-state.json` | in-repo | Source of `project_type` and `scanned_at` | Already in context from Step 2; used for active agent marking |

### Toolkit-registry.json Schema (HIGH confidence — live file analysis)

```json
{
  "schema_version": 1,
  "scanned_at": "2026-03-13T16:44:17Z",
  "counts": {
    "agents": 176,
    "skills": 28,
    "hooks": 24,
    "mcp": 0
  },
  "tools": [
    {
      "name": "some-agent",
      "type": "agent",
      "description": "One-liner from YAML frontmatter",
      "stages": ["execution", "planning"],
      "source": "~/.claude/agents/some-agent.md",
      "model": "sonnet",
      "tools": ["Read", "Bash"]
    }
  ]
}
```

Types in registry: `"agent"`, `"skill"`, `"hook"`, `"mcp"`

Stages values: `"research"`, `"planning"`, `"execution"`, `"review"` — a tool can appear in multiple stages (multi-value array).

---

## Architecture Patterns

### Wizard.md Instruction Block Pattern

wizard.md is not executable code — it's natural language instructions that Claude executes as an LLM. "Code" in this context means structured instruction sections that Claude reads and follows. The established pattern for shared logic is: write an instruction section with a heading (e.g., `## Display Catalog`) and redirect from call sites using prose like "Go to ## Display Catalog below."

### Current Option 4 Handler Pattern (identical x4)

```markdown
- **Option 4 (Discover tools):** Read `project_type` from wizard-state.json (already loaded in Step 2). Display the catalog below, marking the domain agent whose `project_type` matches with " (active)" appended to its entry. If `project_type` is null or "web", no domain agent is marked active.

  Display:

---

### Agents
...
[~78 lines of hardcoded catalog]
...
---

  After displaying the catalog, re-present this SAME [scenario] menu.
```

This pattern appears 4 times (lines ~176, ~253, ~335, ~403) with identical content — ~78 lines per occurrence, ~312 lines of duplicate text in a 664-line file.

### Target Pattern: Shared Block Reference

After Phase 15, each Option 4 handler becomes a single redirect:

```markdown
- **Option 4 (Discover tools):** Go to ## Display Catalog below.
```

And a new section at the bottom of wizard.md:

```markdown
## Display Catalog

This section is invoked by all "Discover tools" Option 4 handlers.

**Step 1: Refresh registry if stale**
Run: `bash skills/toolkit-discovery.sh` (if local path exists) or `bash ~/.claude/skills/toolkit-discovery.sh`. The script handles TTL internally — it exits fast if registry is fresh. Suppress stderr.

**Step 2: Read registry**
Read `.claude/toolkit-registry.json`. Attempt JSON parse. If file does not exist or JSON parse fails: go to Fallback Display below.

**Step 3: Dynamic Display**
...render stage-first grouped output using Python3...

**Step 4: Fallback Display**
Display:
---
[hardcoded Phase 7 catalog — single copy]
---
`Showing built-in catalog. Run toolkit-discovery.sh for full scan.`

**Step 5: Re-present menu**
Return to the menu that triggered this option and re-present it.
```

### Dynamic Rendering Logic

The dynamic section should use an embedded Python3 call to avoid shell string-handling bugs with JSON special characters (established precedent from Phase 13 STATE decision):

```bash
python3 -c "
import json, sys

try:
    with open('.claude/toolkit-registry.json') as f:
        registry = json.load(f)
except Exception:
    # Fallback path
    sys.exit(1)

counts = registry.get('counts', {})
tools = registry.get('tools', [])
scanned_at = registry.get('scanned_at', 'unknown')

# Summary header
...

# Stage-first grouping
KEYSTONE_NAMES = { ... }  # hardcoded set
STAGES = ['research', 'planning', 'execution', 'review']

for stage in STAGES:
    stage_tools = [t for t in tools if stage in t.get('stages', [])]
    keystone = [t for t in stage_tools if t['name'] in KEYSTONE_NAMES]
    user_agents = [t for t in stage_tools if t['type'] == 'agent' and t['name'] not in KEYSTONE_NAMES]
    user_skills = [t for t in stage_tools if t['type'] == 'skill' and t['name'] not in KEYSTONE_NAMES]
    user_mcp    = [t for t in stage_tools if t['type'] == 'mcp']
    ...
"
```

### Stage-First Output Structure (with entry cap)

```
**N** agents · **N** skills · **N** hooks · **N** MCP servers

---
## Research

**Keystone tools:**
- context-health-monitor — Detects drift between what was planned and what was built
- gsd-phase-researcher — ...

**Installed tools:**
*Agents (N)*
- some-agent — one-liner description
- ... and N more

*Skills (N)*
- some-skill — one-liner

*MCP (N)*
- context7 (configured) — MCP server for context7

---
## Planning
...
```

### Anti-Patterns to Avoid

- **Reading toolkit-registry.json at startup:** wizard.md must NOT change its Step 2 behavior. The registry is lazy-loaded ONLY in Option 4. The Context Budget Discipline exception is scoped to Option 4 only.
- **Removing the hardcoded catalog before parity check passes:** The hardcoded fallback must remain. SC #4 requires parity verification before any removal (which is out of scope for this phase anyway).
- **Showing all tools per stage without a cap:** With 98-155 tools per stage on a 176-agent install, uncapped output would overwhelm any context window and destroy the "quick reference card" UX intent.
- **Using bash string interpolation for JSON:** Special characters in agent descriptions break heredoc/echo approaches. Use Python3 with `json.load()` to avoid corruption (Phase 13 precedent).
- **Inlining the display logic in each of the 4 handlers:** The entire point of consolidation is one-copy maintenance. Don't split the logic.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | String grep/sed/awk on registry JSON | Python3 `json.load()` | Special characters in descriptions corrupt string parsing; established precedent in all existing wizard scripts |
| Registry freshness check | Duplicate TTL logic in wizard.md | Call `toolkit-discovery.sh` (TTL built in) | Phase 12 already implements TTL + `--force` rescan; duplicating creates drift |
| Stage grouping algorithm | New bash loop | Python3 inline script (same pattern as toolkit-discovery.sh) | Bash array handling for multi-value filtering is fragile cross-platform |
| Tool type sorting | Multi-pass scan | Single Python3 pass with list comprehensions by type | Already proven in toolkit-discovery.sh compact summary section |

**Key insight:** All JSON manipulation in this codebase uses Python3 inline scripts called from Bash. Do not introduce new approaches for Phase 15.

---

## Common Pitfalls

### Pitfall 1: The "No Bash" Constraint Applies to Step 1 Only

**What goes wrong:** Developer reads "Do NOT run bash yourself" in wizard.md Context Budget Discipline and concludes that Option 4 cannot call `bash skills/toolkit-discovery.sh`.

**Why it happens:** The constraint was written for Step 1 (detection phase) to prevent the wizard from running arbitrary bash during state detection. Option 4 is explicitly the PERF-03 lazy-load exception.

**How to avoid:** The Phase 15 plan must update Context Budget Discipline to add: "Exception: `## Display Catalog` may run `toolkit-discovery.sh` and read `toolkit-registry.json` — this is the PERF-03 lazy-load point."

**Warning signs:** Plan that omits the Context Budget Discipline update is incomplete.

### Pitfall 2: Keystone Tools Not in Registry

**What goes wrong:** Parity check fails because 4 of the 11 Keystone agents and all 4 Keystone skills are NOT present in `toolkit-registry.json`.

**Why it happens:** `toolkit-discovery.sh` only scans `~/.claude/agents/*.md` (global flat directory). Keystone-local agents in `agents/bridge/`, `agents/domain/`, `agents/entry/`, `agents/maintenance/` are not scanned. Keystone skills (`wizard.md`, `wizard-backing-agent.md`, `wizard-detect.sh`, `toolkit-discovery.sh`) live in the project's `skills/` directory, not in `~/.claude/skills/*/SKILL.md` format.

**Live evidence (2026-03-13 registry):**
- Missing from registry: `admin-docs-agent`, `godot-dev-agent`, `it-infra-agent`, `project-setup-advisor`
- All 4 Keystone skills missing: `wizard`, `wizard-backing-agent`, `wizard-detect`, `toolkit-discovery`
- All 3 hooks present: `session-start`, `stack-update-banner`, `post-write-check`

**How to avoid:** The "Keystone tools" sub-section in the dynamic display must be hardcoded (not registry-sourced). The shared "Display Catalog" block maintains the Keystone section from the hardcoded list directly, then appends registry-sourced user tools. This satisfies parity (Keystone tools always appear) while enabling dynamic user tool display.

**Warning signs:** Any plan that assumes all 18 Keystone tools are in the registry is wrong.

### Pitfall 3: Uncapped Stage Output

**What goes wrong:** The dynamic display shows all 98-155 tools per stage with no cap, making "Discover tools" unusable.

**Why it happens:** The registry contains every installed tool in every matching stage. With 176 agents, most appear in 2-3 stages.

**How to avoid:** Implement a per-stage cap (Claude's discretion: recommend 10-15 user tools per type per stage) with `... and N more` suffix. The counts header at the top gives the full picture; the per-stage display is a curated sample.

**Warning signs:** Any implementation that outputs more than ~40 lines per stage section will overwhelm the user.

### Pitfall 4: Forgetting to Re-present the Calling Menu

**What goes wrong:** After displaying the catalog, the wizard stops without offering the next action.

**Why it happens:** The shared block consolidation moves the "re-present menu" instruction out of the individual handlers. The shared block must include the instruction to return to the calling menu — but it doesn't know WHICH menu called it.

**How to avoid:** The shared block should end with: "Return to the menu that triggered this section and re-present it." Each calling Option 4 handler retains the specific "re-present [this specific] menu" instruction as a suffix after the redirect.

**Alternative:** The redirect can be: "Go to ## Display Catalog, then re-present [this menu]." This keeps the re-present instruction at the call site.

### Pitfall 5: Hardcoded Catalog Entry Count Discrepancy

**What goes wrong:** The parity check reveals the "18 Keystone tools" count in CONTEXT.md doesn't match the current wizard.md catalog (which shows 11 agents + 3 skills + 3 hooks = 17 entries).

**Why it happens:** `toolkit-discovery.sh` was added as the 4th Keystone skill in Phase 12, but the wizard.md catalog was never updated to include it.

**How to avoid:** When writing the hardcoded fallback, include `toolkit-discovery` as the 4th skill entry. The parity check in the verification plan must count from the shared block's fallback, not the old 4-copy catalog.

---

## Code Examples

### Pattern: Python3 JSON Parse with Fallback (wizard-detect.sh precedent)

```bash
# Source: skills/wizard-detect.sh lines 290-303
TOOLKIT_LINE=$(echo "$TOOLKIT_JSON" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    c = d.get('counts', {})
    ...
except Exception:
    pass
" 2>/dev/null)
```

For Phase 15, the registry is read from file rather than stdin:

```bash
python3 -c "
import json, sys
try:
    with open('.claude/toolkit-registry.json') as f:
        registry = json.load(f)
except Exception:
    print('FALLBACK')
    sys.exit(1)
..." 2>/dev/null
```

If the Python3 script exits with code 1 (or "FALLBACK" marker), the wizard instruction block falls through to the hardcoded catalog.

### Pattern: Stage-First Tool Grouping (adapted from toolkit-discovery.sh)

```python
# Source: skills/toolkit-discovery.sh compact summary section
STAGES = ['research', 'planning', 'execution', 'review']
KEYSTONE_NAMES = {
    'wizard', 'bmad-gsd-orchestrator', 'context-health-monitor',
    'phase-gate-validator', 'doc-shard-bridge', 'project-setup-wizard',
    'project-setup-advisor', 'it-infra-agent', 'godot-dev-agent',
    'open-source-agent', 'admin-docs-agent', 'stack-update-watcher',
    'wizard-backing-agent', 'wizard-detect', 'toolkit-discovery'
}

for stage in STAGES:
    stage_tools = [t for t in tools if stage in t.get('stages', [])]
    user_agents = [t for t in stage_tools
                   if t['type'] == 'agent' and t['name'] not in KEYSTONE_NAMES]
    user_skills = [t for t in stage_tools
                   if t['type'] == 'skill' and t['name'] not in KEYSTONE_NAMES]
    user_mcp    = [t for t in stage_tools if t['type'] == 'mcp']
```

### Pattern: Active Domain Agent Marking (from current wizard.md)

```markdown
Active-marking logic for domain agents:
- project_type == "docs"        -> append " (active)" to admin-docs-agent entry
- project_type == "game"        -> append " (active)" to godot-dev-agent entry
- project_type == "infra"       -> append " (active)" to it-infra-agent entry
- project_type == "open-source" -> append " (active)" to open-source-agent entry
- project_type == "web" or null -> no (active) marking
```

This existing logic is preserved in the shared block. `project_type` is already available from wizard-state.json (loaded in Step 2).

### Pattern: Source Footer Notes

```markdown
# Dynamic:
*Source: toolkit-registry.json (scanned 2026-03-13T16:44:17Z)*

# Fallback:
*Showing built-in catalog. Run toolkit-discovery.sh for full scan.*
```

The `scanned_at` timestamp is a top-level field in `toolkit-registry.json` (verified: `"scanned_at": "2026-03-13T16:44:17Z"`).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded 11-agent catalog (Phase 7) | Dynamic registry-backed display (Phase 15) | Phase 15 | Count reflects actual install; scales to 160+ agents |
| 4 duplicate catalog blocks in wizard.md | 1 shared "Display Catalog" block + 4 single-line references | Phase 15 | -234 lines from wizard.md; one-copy maintenance |
| Type-first grouping (Agents/Skills/Hooks) | Stage-first grouping (Research/Planning/Execution/Review) | Phase 15 | Answers "what helps me right now" vs "what kind of thing is it" |
| No Bash in wizard.md Option 4 | Bash + Python3 for Option 4 only (PERF-03 lazy-load) | Phase 15 | Registry never loaded at startup; only when user explicitly asks |

**Not deprecated:**
- Hardcoded catalog text: Retained as the fallback (required by SC #3). Not removed by Phase 15.
- wizard-state.json as startup data source: Unchanged. No toolkit data loaded at startup.

---

## Key Structural Findings

### wizard.md: 4 Option 4 Handler Locations

| Scenario | Handler Line | Menu Context |
|----------|-------------|-------------|
| full-stack, uat-passing | ~176 | health-check-first menu |
| full-stack, non-uat-passing | ~253 | standard continuation menu |
| gsd-only, uat-passing | ~335 | health-check-first menu |
| gsd-only, non-uat-passing | ~403 | standard continuation menu |

Each handler currently inlines ~78 lines of catalog (183 lines of wizard-detect-sourced catalog). Total duplicate text: ~312 lines out of 664 total.

### Parity Check Analysis (from live registry, 2026-03-13)

**18 Keystone tools per CONTEXT.md:** 11 agents + 4 skills + 3 hooks

**In registry (7/11 agents):** bmad-gsd-orchestrator, context-health-monitor, doc-shard-bridge, open-source-agent, phase-gate-validator, project-setup-wizard, stack-update-watcher

**NOT in registry (4/11 agents):** admin-docs-agent, godot-dev-agent, it-infra-agent, project-setup-advisor — these live in project-local `agents/domain/` and `agents/entry/`, not scanned by toolkit-discovery.sh

**NOT in registry (4/4 skills):** wizard, wizard-backing-agent, wizard-detect, toolkit-discovery — these live in project-local `skills/` directory as .md and .sh files, not in `~/.claude/skills/*/SKILL.md` format

**In registry (3/3 hooks):** session-start, stack-update-banner, post-write-check

**Conclusion:** Parity check requires Keystone tools to be displayed from hardcoded knowledge, not from registry lookup. The shared "Display Catalog" block must hardcode the Keystone section.

### Context Budget Discipline Update Required

Current constraint (line 664): `"The only toolkit data source is wizard-state.json toolkit.by_stage (already loaded in Step 2). Never read toolkit-registry.json from wizard.md."`

This constraint conflicts with Phase 15's intent. The update must:
1. Retain the constraint for all wizard.md behavior EXCEPT Option 4
2. Add explicit exception: "Exception for `## Display Catalog`: may run `bash skills/toolkit-discovery.sh` and read `.claude/toolkit-registry.json` — this is the PERF-03 designated lazy-load point"

---

## Open Questions

1. **Current hardcoded catalog shows 3 skills; CONTEXT.md says 18 tools (11+4+3 = 18)**
   - What we know: wizard.md currently has wizard, wizard-backing-agent, wizard-detect = 3 skills
   - What's unclear: Does "4 skills" include toolkit-discovery (added Phase 12)?
   - Recommendation: Yes — toolkit-discovery was the Phase 12 addition. Add it as 4th skill in the shared block's Keystone section. The parity check must be defined against the updated hardcoded catalog, not the pre-Phase-12 one.

2. **Per-stage entry cap threshold**
   - What we know: Research stage has 98 tools; planning 153; execution 155; review 123
   - What's unclear: What cap produces a "quick reference card" UX?
   - Recommendation: Cap at 10 user tools per type per stage (10 agents + 10 skills + all MCP). With a "... and N more" footer. This shows enough to orient without overwhelming. Total per stage: ~20-30 user entries + Keystone entries.

3. **Stages with zero user tools**
   - What we know: All stages have user tools (even research has 62 agents in registry)
   - What's unclear: What if a user has a minimal install with 0 user tools in a stage?
   - Recommendation: Skip stages that have 0 user tools (not 0 total — Keystone always shows). Skip the user subsection if empty, but always show the Keystone subsection.

---

## Validation Architecture

`nyquist_validation` is enabled in `.planning/config.json` (absent = enabled).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual verification (no automated test suite in this project) |
| Config file | none |
| Quick run command | Read wizard.md and confirm Option 4 handlers redirect to shared block |
| Full suite command | Per success criteria in phase: count match, grouping, fallback, parity |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAT-01 | "Discover tools" reads `toolkit-registry.json` | manual-verify | Verify Display Catalog block calls `bash skills/toolkit-discovery.sh` and reads `.claude/toolkit-registry.json` | ❌ Wave 0 instruction review |
| CAT-02 | Tools grouped by stage then category | manual-verify | Run `/wizard` → select "Discover tools" → inspect output grouping | ❌ runtime test |
| CAT-03 | Fresh install shows hardcoded fallback | manual-verify | Rename `.claude/toolkit-registry.json` → invoke Option 4 → confirm fallback displays without error | ❌ runtime test |

### Sampling Rate

- **Per task commit:** Review the modified wizard.md section for instruction correctness
- **Per wave merge:** Execute success criteria 1-4 from CONTEXT.md against live wizard invocation
- **Phase gate:** All 4 success criteria pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] Manual verification script for parity check: read hardcoded entries from shared block, read registry, assert all 18 Keystone tools present in dynamic output. Can be a one-off `python3 -c "..."` command in the verification plan.

*(No automated test framework exists — all validation is manual wizard invocation or script-based spot checks)*

---

## Sources

### Primary (HIGH confidence)

- `skills/wizard.md` (full file) — current 4-copy catalog structure, Option 4 handler locations, Context Budget Discipline constraints, tool list (Bash confirmed in frontmatter)
- `skills/toolkit-discovery.sh` (full file) — scan scope (only `~/.claude/agents/*.md`), registry schema, Python3 parsing pattern, TTL cache behavior
- `.claude/toolkit-registry.json` (live file, 2026-03-13) — confirmed schema, counts (176 agents / 28 skills / 24 hooks / 0 MCP), stage distribution, Keystone tool presence
- `.claude/wizard-state.json` (live file) — confirmed `project_type` field, `toolkit: {}` (empty — local agents not installed globally)
- `.planning/phases/15-dynamic-catalog-display/15-CONTEXT.md` — all locked decisions and implementation specifics

### Secondary (MEDIUM confidence)

- `.planning/research/FEATURES.md` — feature landscape and rationale for phase 15 design choices
- `.planning/STATE.md` — accumulated decisions, especially Phase 12-14 decisions affecting Phase 15
- `.planning/REQUIREMENTS.md` — CAT-01/02/03 formal definition

### Tertiary (LOW confidence)

None — all findings from direct file analysis.

---

## Metadata

**Confidence breakdown:**
- Registry schema and contents: HIGH — read from live file
- Option 4 handler locations and current structure: HIGH — read from live wizard.md
- Parity check analysis: HIGH — ran against live registry, confirmed specific missing tools
- Rendering logic design: HIGH — follows direct precedent from toolkit-discovery.sh
- Context Budget Discipline update requirement: HIGH — explicitly quoted from wizard.md line 664

**Research date:** 2026-03-13
**Valid until:** 30 days (stable project; no external dependencies)
