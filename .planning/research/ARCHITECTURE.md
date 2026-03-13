# Architecture Research

**Domain:** Dynamic toolkit discovery and subagent capability injection for wizard orchestrator
**Researched:** 2026-03-13
**Confidence:** HIGH (derived entirely from first-party codebase analysis — all components are readable)

## Standard Architecture

### System Overview

Current v1.0 architecture (what exists today):

```
/wizard
  └── wizard-detect.sh          [Detection — bash, writes wizard-state.json]
        └── wizard.md           [UI — reads state, presents menu, delegates]
              └── wizard-backing-agent.md  [Work — bridge/traceability routes]
```

The v1.1 milestone adds a new layer — a **toolkit registry** — that sits between detection and the UI, and also feeds into subagent spawns:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         User Entry Point                             │
│                       /wizard (slash command)                        │
└──────────────────────────┬───────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       wizard-detect.sh  [MODIFIED]                   │
│                                                                      │
│  Existing: BMAD markers, GSD markers, project type, scenario         │
│  NEW: invoke toolkit-discovery.sh, embed toolkit summary in JSON     │
│                                                                      │
│  Writes: .claude/wizard-state.json (schema extended)                 │
└──────────┬────────────────────────────────┬─────────────────────────┘
           │                                │
           ▼                                ▼
┌──────────────────────┐       ┌────────────────────────────────────┐
│  toolkit-discovery.sh│       │  .claude/toolkit-registry.json     │
│  [NEW component]     │  ───> │  [NEW persistent cache]            │
│                      │       │  agents[], skills[], hooks[],       │
│  Scans:              │       │  mcp_servers[]                     │
│  - ~/.claude/agents/ │       │  Each entry: name, description,    │
│  - ~/.claude/skills/ │       │  category, stage_tags[]            │
│  - ~/.claude/hooks/  │       │  ttl: 5 min                        │
│  - settings.json MCP │       └──────────────┬─────────────────────┘
│  - ./agents/         │                      │
│  - ./skills/         │                      │
└──────────────────────┘                      │
                                              │
                            ┌─────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         wizard.md  [MODIFIED]                        │
│                                                                      │
│  Existing: scenario menus, health-check, validate, discover-tools    │
│  NEW: reads toolkit summary from wizard-state.json                   │
│       injects capability hints into Task() prompts for subagents     │
│       surfaces MCP recommendations at relevant workflow moments       │
│       asks for confirmation when tool usage is ambiguous             │
└──────────────────────────┬───────────────────────────────────────────┘
                            │
              Task() with injected capability context
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                  wizard-backing-agent.md  [UNCHANGED]                │
│                                                                      │
│  Receives injected capability pointers in its prompt                 │
│  Routes to bridge / traceability as before                           │
│  GSD subagents spawned via Task() also receive injected context      │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Status | Responsibility | Lives At |
|-----------|--------|----------------|----------|
| wizard-detect.sh | MODIFIED | State detection + toolkit scan invocation + JSON write | `skills/wizard-detect.sh` |
| toolkit-discovery.sh | NEW | Scans all toolkit locations, emits structured JSON | `skills/toolkit-discovery.sh` |
| toolkit-registry.json | NEW | Cached discovered toolkit, TTL-gated | `.claude/toolkit-registry.json` |
| capability-matcher | NEW (inline in discovery) | Maps each tool to workflow stage tags | Inside toolkit-discovery.sh |
| wizard.md | MODIFIED | Reads toolkit summary, injects into subagent prompts, surfaces MCP hints, confirmation UX | `skills/wizard.md` |
| wizard-backing-agent.md | UNCHANGED | Bridge and traceability routes — receives injected context | `skills/wizard-backing-agent.md` |
| wizard-state.json | SCHEMA EXTENDED | Existing state + `toolkit` summary section | `.claude/wizard-state.json` |

## Recommended Project Structure

```
skills/
├── wizard.md                  # MODIFIED — injects capability hints into Task() prompts
├── wizard-detect.sh           # MODIFIED — invokes toolkit-discovery.sh, embeds toolkit summary
├── wizard-backing-agent.md    # UNCHANGED
└── toolkit-discovery.sh       # NEW — scans toolkit locations, emits JSON, caches registry

.claude/
├── wizard-state.json          # SCHEMA EXTENDED — gains toolkit{} section
└── toolkit-registry.json      # NEW — cached discovered toolkit (TTL 5 min)
```

No new agent files needed. No new skill invocation points. All new logic lives in shell (toolkit-discovery.sh) and the wizard skill's injection layer.

### Structure Rationale

- **toolkit-discovery.sh as shell script, not skill:** Discovery runs synchronously during wizard-detect.sh. Skills are invoked by Claude — shell scripts can be called from shell scripts. wizard-detect.sh already owns the JSON write contract; toolkit-discovery.sh extends that naturally.
- **toolkit-registry.json separate from wizard-state.json:** The full discovered toolkit is large (160+ agents in the global install). wizard-state.json embeds only a compact `toolkit` summary (stage-tagged pointers). The full registry lives separately and is only read when "Discover tools" is explicitly invoked.
- **wizard-backing-agent.md unchanged:** Injection happens at the Task() call site in wizard.md — the backing agent receives a richer prompt but its internal routing logic is unaffected. Keeps the "wrap, don't replace" constraint intact.

## Architectural Patterns

### Pattern 1: Two-Level Toolkit Representation

**What:** Maintain two representations of the discovered toolkit — a full registry and a compact summary. The full registry (toolkit-registry.json) contains every discovered tool with all metadata. The compact summary (embedded in wizard-state.json toolkit{} section) contains only stage-tagged pointers needed for the current workflow moment.

**When to use:** Always. The full registry is used for "Discover tools" display. The compact summary is what gets injected into subagent prompts. Injecting the full registry would violate the 10% context budget constraint.

**Trade-offs:** Two writes per wizard invocation (toolkit-registry.json + wizard-state.json). Negligible overhead. The alternative — embedding the full registry in wizard-state.json — would bloat every wizard invocation.

**Example compact summary in wizard-state.json:**
```json
{
  "toolkit": {
    "discovered_at": "2026-03-13T12:00:00Z",
    "counts": { "agents": 160, "skills": 33, "hooks": 24, "mcp_servers": 4 },
    "stage_relevant": {
      "research": ["agent:context7-researcher", "mcp:context7"],
      "planning": ["agent:engineering-software-architect", "skill:audit"],
      "execution": ["agent:engineering-senior-developer", "skill:fix-issue"],
      "review": ["agent:code-reviewer", "skill:critique", "mcp:github"]
    }
  }
}
```

### Pattern 2: TTL-Gated Discovery

**What:** toolkit-discovery.sh checks whether toolkit-registry.json exists and was written within the last 5 minutes. If fresh, re-uses the cache. If stale or absent, re-scans.

**When to use:** Every wizard invocation. Discovery scans 160+ files — without caching this adds ~1s latency and repeated I/O on every `/wizard` call.

**Trade-offs:** 5-minute TTL means new tools installed mid-session won't appear immediately. This is acceptable — the user can force a rescan by deleting toolkit-registry.json.

**Example gate logic in toolkit-discovery.sh:**
```bash
REGISTRY=".claude/toolkit-registry.json"
MAX_AGE=300  # 5 minutes in seconds

if [ -f "$REGISTRY" ]; then
    MTIME=$(stat -f%m "$REGISTRY" 2>/dev/null || stat -c%Y "$REGISTRY" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE=$((NOW - MTIME))
    [ "$AGE" -lt "$MAX_AGE" ] && cat "$REGISTRY" && exit 0
fi
# Cache miss — run full scan
```

### Pattern 3: Stage Tag Capability Matching

**What:** Each discovered tool gets a `stage_tags[]` field assigned by category matching rules. Tags map to workflow stages: `research`, `planning`, `execution`, `review`. The matching rules run inside toolkit-discovery.sh at scan time, not at injection time.

**When to use:** Scan time. Matching is cheap (string matching on filenames and YAML descriptions). Pre-computing tags keeps injection fast — wizard.md just filters the compact summary by current stage.

**Stage-to-category mapping (medium confidence — apply in order, first match wins):**
```
"research"  ← agents with description containing: research, discover, analyze, audit, explore
             ← skills: audit, distill, extract, memory-recall
             ← MCP servers: context7, brave (search capability)

"planning"  ← agents with description containing: architect, design, plan, strategy, roadmap
             ← skills: onboard, project-scaffolder
             ← BMAD agents: analyst, pm, architect, po, sm

"execution" ← agents with description containing: build, implement, develop, engineer, fix, debug
             ← skills: fix-issue, gen-test, harden, optimize, docker-dev-local
             ← GSD subagents: researcher, planner, executor

"review"    ← agents with description containing: review, validate, test, audit, quality, check
             ← skills: critique, code-standards, security-check
             ← MCP servers: github (PR review capability)
```

**Trade-offs:** Category matching by string heuristics will have false positives. Accept this — the goal is useful hints, not perfect classification. The user confirmation flow (Pattern 4) handles ambiguous cases.

### Pattern 4: Token-Efficient Injection via Pointers, Not Prompts

**What:** When wizard.md spawns a Task() for a subagent, it appends a compact "available tools" section to the prompt — tool names and one-liner descriptions only, not full agent prompts. The subagent receives pointers it can act on, not a knowledge dump.

**When to use:** Every Task() spawn where the workflow stage is known. Do not inject for all stages at once — inject only the tools relevant to the current stage.

**Example injected suffix (adds ~200 tokens, not 2000):**
```
---
Available tools for this stage (research):
- Agent: context7-researcher — Query library documentation
- Agent: engineering-senior-developer — Code implementation
- MCP: context7 — Access current library docs (use mcp__context7__resolve-library-id)
- Skill: audit — Audit existing code patterns
If any of these would help, use them. Ask first if intent is unclear.
---
```

**Trade-offs:** Short pointers mean subagents must know how to invoke the tools from name alone. This is acceptable — GSD subagents already have instructions for using Agent() and Skill() tools.

### Pattern 5: Confirmation UX for Ambiguous Tool Use

**What:** When wizard.md detects that a discovered tool *could* help but the workflow stage makes it non-obvious, it uses AskUserQuestion before injecting the tool reference into the subagent prompt.

**When to use:** MCP servers with significant side effects (e.g., GitHub MCP that could create PRs). Tools not obviously matched to the current stage. Tools with ambiguous purpose based on their description alone.

**Confirmation triggers:**
- MCP server with `write` capability + current stage is `execution` or `review`
- Discovered tool with description that matches multiple stages
- Any tool not in the known Keystone catalog (i.e., discovered from the user's broader global install)

**Non-confirmation triggers:**
- Keystone-authored agents and skills (user already knows about these from Phase 7 catalog)
- Read-only MCP servers (context7, brave search)
- Tools clearly matched to a single stage

## Data Flow

### Discovery → Registry → State Flow

```
/wizard invoked
    ↓
wizard-detect.sh runs (existing detection — unchanged)
    ↓
wizard-detect.sh calls: bash skills/toolkit-discovery.sh > /tmp/toolkit.json
    ↓
toolkit-discovery.sh:
    Check TTL of .claude/toolkit-registry.json
    IF fresh: cat registry, exit
    IF stale:
        Scan ~/.claude/agents/ (global)    → 160 agents
        Scan ~/.claude/skills/ (global)    → 33 skills
        Scan ~/.claude/hooks/ (global)     → 24 hooks
        Scan ./agents/ (local)             → 11 Keystone agents
        Scan ./skills/ (local)             → 3 Keystone skills
        Parse settings.json mcpServers     → N MCP servers
        Apply stage tag matching rules
        Write full results → .claude/toolkit-registry.json
        Emit compact summary (stage_relevant pointers only)
    ↓
wizard-detect.sh embeds compact summary into wizard-state.json toolkit{} section
    ↓
wizard.md reads wizard-state.json (existing behavior)
    ↓
wizard.md reads toolkit.stage_relevant for current phase
    ↓
wizard.md builds injected suffix for Task() prompt
    ↓ (if ambiguous tool detected)
wizard.md calls AskUserQuestion for confirmation
    ↓
wizard.md spawns Task(backing-agent or GSD subagent, prompt + injected suffix)
```

### MCP Discovery Specifics

Claude Code stores MCP server configuration in `~/.claude/settings.json` under the `mcpServers` key. Each entry has a `command`, `args`, and optional `env` fields. The server name is the key.

toolkit-discovery.sh reads MCP configuration as:
```bash
# macOS/zsh safe — no jq required
MCP_NAMES=$(python3 -c "
import json
try:
    with open('$HOME/.claude/settings.json') as f:
        d = json.load(f)
    servers = d.get('mcpServers', {})
    for name in servers:
        print(name)
except Exception:
    pass
" 2>/dev/null)
```

Each discovered MCP server gets stage tags based on its name:
- `context7` → `research`
- `brave*` → `research`
- `github*` → `review`, `execution`
- `filesystem*` → `execution`
- Unknown names → `all` (inject a confirmation prompt)

### wizard-state.json Schema Extension

Existing schema gains a new top-level `toolkit` section. All existing fields are unchanged — this is additive only.

```json
{
  "scenario": "full-stack",
  "detected_at": "...",
  "next_command": "...",
  "project_type": "...",
  "...": "... (all existing fields unchanged) ...",
  "toolkit": {
    "discovered_at": "2026-03-13T12:00:00Z",
    "counts": {
      "agents_global": 160,
      "agents_local": 11,
      "skills_global": 30,
      "skills_local": 3,
      "hooks": 24,
      "mcp_servers": 4
    },
    "mcp_servers": ["context7", "github", "brave", "filesystem"],
    "stage_relevant": {
      "research": ["agent:context7-researcher", "mcp:context7", "skill:audit"],
      "planning": ["agent:engineering-software-architect", "skill:onboard"],
      "execution": ["agent:engineering-senior-developer", "skill:fix-issue", "mcp:filesystem"],
      "review": ["agent:code-reviewer", "skill:critique", "mcp:github"]
    },
    "discovery_errors": []
  }
}
```

**Size budget:** The toolkit section adds ~600 bytes to wizard-state.json — well within budget. The full registry (toolkit-registry.json) may be 100-200KB but is never loaded into context wholesale.

## Component Integration Points

### wizard-detect.sh Modification Points

wizard-detect.sh currently has these major sections:
1. BMAD markers
2. GSD markers
3. Project type detection
4. Complexity detection
5. Bridge eligibility
6. Scenario classification
7. JSON write
8. Status box display

The toolkit invocation goes between sections 6 and 7:

```bash
# -- TOOLKIT DISCOVERY --------------------------------------------------
TOOLKIT_SUMMARY="{}"
if command -v bash >/dev/null 2>&1; then
    TOOLKIT_JSON=$(bash skills/toolkit-discovery.sh 2>/dev/null \
                   || bash ~/.claude/skills/toolkit-discovery.sh 2>/dev/null \
                   || echo "{}")
    TOOLKIT_SUMMARY="$TOOLKIT_JSON"
fi
```

Then the JSON write (section 7) gains the toolkit field:
```bash
cat > ".claude/wizard-state.json" << EOF
{
  ... (all existing fields) ...
  "toolkit": $TOOLKIT_SUMMARY
}
EOF
```

This is a minimal, additive change. wizard-detect.sh's existing logic is entirely untouched.

### wizard.md Modification Points

wizard.md currently dispatches subagents in two places:
1. Option 2 (Check drift): `Agent tool with context-health-monitor prompt`
2. Option 3 (Validate phase): `Agent tool with phase-gate-validator prompt`
3. Bridge: `Task(wizard-backing-agent, "Route B")`
4. Option 1 (Continue): `Skill(next_command)`

Injection applies to items 2 and 3 (Task/Agent spawns where workflow stage is known). Item 4 (Continue — Skill invocation) does NOT get injection because Skill() shares the caller's context window, and injection into a Skill prompt would pollute the shared context.

**Injection implementation in wizard.md:**

After reading wizard-state.json (Step 2 of existing flow), wizard.md will:

```
NEW Step 2.5: Extract toolkit hints
- Read `toolkit.stage_relevant` from wizard-state.json
- Determine current stage from gsd.phase_status and scenario:
    - scenario == "none" → stage = "planning"
    - scenario == "bmad-ready" → stage = "planning"
    - gsd.phase_status == "context-ready" → stage = "planning"
    - gsd.phase_status == "plans-ready" → stage = "execution"
    - gsd.phase_status == "uat-passing" → stage = "review"
    - default → stage = "execution"
- Build injection suffix from toolkit.stage_relevant[stage]
- Check for ambiguous MCP servers (name unknown or write-capable) → flag for confirmation
```

Injection is appended to existing Task() prompts, not as a replacement. Example:

```
Existing: "Read agents/bridge/context-health-monitor.md and run a full context health check for phase {N}."
Modified: "Read agents/bridge/context-health-monitor.md and run a full context health check for phase {N}.\n\n---\nAvailable tools for this stage:\n- MCP: context7 — Query library docs\n- Skill: audit — Audit code patterns\n---"
```

### "Discover tools" Option — Replace Hardcoded Catalog

The current "Discover tools" option in wizard.md displays a hardcoded catalog (the 11 agents, 4 skills, 3 hooks listed inline in wizard.md). This is the catalog from Phase 7.

**v1.1 replacement:** When user selects "Discover tools", wizard.md reads toolkit-registry.json (the full discovered catalog) instead of displaying the hardcoded catalog. This is the primary user-visible change — "Discover tools" now shows what's actually installed, not a static list.

Display format is extended to include:
- All discovered global agents (grouped by category prefix if available)
- All discovered global skills
- All discovered hooks
- All MCP servers (with capability description from settings.json)
- Keystone-local agents and skills (already shown in Phase 7 catalog — now sourced dynamically)

The hardcoded catalog text in wizard.md is deleted and replaced with dynamic rendering from toolkit-registry.json.

## Build Order and Phase Dependencies

### Phase 1: toolkit-discovery.sh — New Component (Build First)

**Deliverable:** `skills/toolkit-discovery.sh` that scans toolkit locations, applies stage tagging, emits compact JSON summary, caches full registry.

**Why first:** Everything downstream depends on this script producing valid JSON. wizard-detect.sh integration is blocked on this existing. Can be built and tested independently — run it in any Claude Code project and inspect the output.

**Test:** `bash skills/toolkit-discovery.sh | python3 -m json.tool` — should emit valid JSON, non-empty counts.

**Blocking for:** wizard-detect.sh integration, wizard.md injection.

### Phase 2: wizard-detect.sh Integration — Modify Existing (Build Second)

**Deliverable:** Modified `wizard-detect.sh` that invokes toolkit-discovery.sh and embeds the compact summary in wizard-state.json.

**Why second:** Depends on toolkit-discovery.sh existing. This is a small, additive change — one new section and one new field in the JSON write. Low regression risk because the existing sections are untouched.

**Test:** Run `bash skills/wizard-detect.sh` and inspect `.claude/wizard-state.json` — should contain `toolkit{}` section with non-empty counts and stage_relevant pointers.

**Blocking for:** wizard.md injection (wizard.md reads toolkit from wizard-state.json).

### Phase 3: wizard-state.json Schema Extension — No Code Change Required

**Deliverable:** Updated schema documentation. wizard-detect.sh from Phase 2 already writes the extended schema.

**Why third:** This is documentation/contract, not code. Formalizes the new fields so wizard.md can safely read them.

### Phase 4: wizard.md Injection and MCP Recommendations — Modify Existing (Build Fourth)

**Deliverable:** Modified `wizard.md` with Step 2.5 (extract toolkit hints), injected Task() prompts, MCP recommendation moments, confirmation UX.

**Why fourth:** Depends on wizard-state.json containing toolkit data (Phase 2). This is the highest-risk change because wizard.md is the UI — mistakes affect every wizard interaction.

**Build sub-tasks in order:**
1. Add Step 2.5 (extract toolkit hints) — read only, no behavior change
2. Build injection suffix generator — generates text, not yet wired to Task()
3. Wire injection to Task() for backing-agent spawns — test with Route B
4. Wire injection to Agent() for drift-check and validate-phase — test each
5. Add MCP recommendation moments (surface MCP hint at relevant scenario + stage)
6. Add confirmation UX for ambiguous tools

**Test:** Run `/wizard` in a project mid-execution, select "Check drift" — verify the context-health-monitor agent receives an injected suffix with stage-appropriate tools.

### Phase 5: Dynamic "Discover tools" Display — Modify wizard.md (Build Fifth)

**Deliverable:** "Discover tools" option reads toolkit-registry.json instead of hardcoded catalog.

**Why fifth:** Depends on toolkit-registry.json being generated (Phase 1 produces this as a side effect). Isolated change — only the catalog rendering logic in wizard.md changes. Hardcoded catalog text is deleted, dynamic read added.

**Test:** Run `/wizard`, select "Discover tools" — verify output includes global agents, global skills, hooks, and MCP servers. Verify the count matches `ls ~/.claude/agents/ | wc -l`.

### Phase 6: Global Deployment Sync

**Deliverable:** `~/.claude/skills/` updated with new wizard-detect.sh, toolkit-discovery.sh, and modified wizard.md.

**Why last:** Follows the established pattern from v1.0 Phases 9 and 11 — project-local development first, then global deployment.

## Anti-Patterns

### Anti-Pattern 1: Embedding Full Registry in wizard-state.json

**What:** Writing all 160+ agents with full metadata into wizard-state.json at detection time.

**Why bad:** wizard-state.json is read by wizard.md on every `/wizard` invocation. A 100KB state file would immediately violate the 10% context budget constraint. The wizard would spend significant context just reading its own state.

**Do this instead:** wizard-state.json gets only the compact summary (stage_relevant pointers, counts). toolkit-registry.json holds the full catalog and is only read when "Discover tools" is explicitly selected.

### Anti-Pattern 2: Discovery Running on Every Bash Block

**What:** Running toolkit-discovery.sh every time wizard-detect.sh runs, without TTL gating.

**Why bad:** Scanning 200+ files across ~/.claude/agents/, ~/.claude/skills/, ~/.claude/hooks/, and settings.json adds latency to every `/wizard` invocation. The existing wizard-detect.sh completes in under 1 second — this should stay true.

**Do this instead:** TTL-gate the full scan to 5 minutes. wizard-detect.sh reads the cache on warm invocations (adds ~5ms for file stat + cache read). Only the first invocation per 5-minute window does the full scan.

### Anti-Pattern 3: Injecting Capability Lists into Skill() Invocations

**What:** Appending the capability injection suffix to Skill() invocations (e.g., the Continue option that runs `/gsd:discuss-phase N`).

**Why bad:** Skills share the caller's context window. Injecting 200 tokens of tool hints into every GSD skill invocation would accumulate rapidly — each subsequent skill invocation adds more context overhead, compounding the budget problem.

**Do this instead:** Only inject into Task() and Agent() spawns. These run in fresh context windows where the injection overhead is bounded per-spawn, not cumulative.

### Anti-Pattern 4: Confirming Every Tool Use

**What:** Presenting AskUserQuestion for every discovered tool before every subagent spawn.

**Why bad:** The wizard's 2-turn interaction budget is a core design constraint. Confirmation dialogs for each of 5 tools at each of 3 subagent spawns would turn a 2-turn wizard into a 17-turn wizard.

**Do this instead:** Confirm only ambiguous cases: unknown MCP servers, write-capable MCP servers in execution context, tools that match multiple stages. Known tools (Keystone catalog + common read-only MCPs like context7) inject without confirmation.

### Anti-Pattern 5: Hard-Coding MCP Server Names

**What:** Building a fixed allowlist of "safe" MCP server names (context7, github, brave) into wizard.md.

**Why bad:** The user may rename or reconfigure their MCP servers. Hard-coded names become false negatives — a safe server renamed from `context7` to `context7-v2` would trigger unnecessary confirmation prompts.

**Do this instead:** toolkit-discovery.sh reads the MCP name AND checks for known patterns (context7 contains "context7", github contains "github"). Unknown patterns get tagged `requires_confirmation`. The pattern matching lives in toolkit-discovery.sh, not wizard.md.

## Integration Points with Existing Architecture

### wizard-detect.sh (Existing — Modified)

| What changes | What stays the same |
|-------------|---------------------|
| New section: toolkit discovery invocation | All BMAD/GSD/project-type detection logic |
| New field in wizard-state.json: `toolkit{}` | wizard-state.json write contract (additive only) |
| New fallback: local then global path for toolkit-discovery.sh | Status box display |

**Regression risk:** LOW. The new section is additive. If toolkit-discovery.sh fails or isn't installed, the fallback `echo "{}"` produces an empty toolkit section — wizard.md reads an empty toolkit and proceeds without injection.

### wizard.md (Existing — Modified)

| What changes | What stays the same |
|-------------|---------------------|
| New Step 2.5: extract toolkit hints | Steps 1-2 detection and state read |
| Task() prompts gain injected suffix | Scenario branching, menu logic |
| "Discover tools" renders from registry | All 5 scenarios, all menu options |
| MCP recommendation moments | Context budget discipline |

**Regression risk:** MEDIUM. wizard.md is the UI — changes affect every user interaction. Mitigation: build injection additive to existing Task() prompts, not replacing them. Test each modified spawn point individually.

### wizard-backing-agent.md (Existing — Unchanged)

Zero changes. The backing agent receives a richer Task() prompt from wizard.md but its internal routing logic is unaffected. Routes B and C are completely unchanged.

**Why unmodified:** The injection design places capability hints in the prompt, not in the agent's own routing logic. If the backing agent wants to use a tool from the injected list, it already knows how — it has `Agent` and `Task` tools in its YAML frontmatter.

### GSD Subagents (Existing — Unchanged)

GSD subagents (researcher, planner, executor) are invoked via Skill() by the Continue option in wizard.md. They are NOT modified because:
1. Continue uses Skill() not Task() — injection into Skill() is Anti-Pattern 3
2. GSD subagents already receive their context from GSD phase files, not wizard prompts
3. Modifying GSD internals is explicitly out of scope per PROJECT.md

MCP awareness for GSD subagents is surfaced by wizard.md BEFORE invoking Continue — e.g., "Your research phase has context7 available for documentation lookups" — not by modifying the subagents themselves.

## Scalability Considerations

| Concern | Now | With v1.1 | Risk |
|---------|-----|-----------|------|
| Context budget | 3 components loaded per /wizard | +200 tokens per Task() spawn for injection suffix | LOW — well within 10% budget |
| Detection latency | <1s | +5ms (cache hit) or +500ms (cache miss, first invocation) | LOW — TTL gating handles this |
| Catalog size | 11 agents hardcoded | 160+ agents in registry, compact summary in state | LOW — two-level design prevents bloat |
| Maintenance burden | Catalog updated manually | Catalog self-discovered, no manual updates | IMPROVEMENT — eliminates Phase 7's stale-catalog problem |
| MCP config changes | Not tracked | Read from settings.json on discovery | LOW — TTL means changes appear within 5 min |

## Sources

All findings derived from first-party source code analysis:
- `skills/wizard.md` — complete UI logic, all scenarios, all spawn patterns
- `skills/wizard-detect.sh` — complete detection logic, JSON write format
- `skills/wizard-backing-agent.md` — complete backing agent routing
- `.claude/wizard-state.json` — live schema as written by wizard-detect.sh
- `.claude/settings.local.json` — permissions and local configuration
- `.planning/PROJECT.md` — requirements, constraints, out-of-scope items
- `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/hooks/` — actual user toolkit (160 agents, 33 skills, 24 hooks discovered via ls)
- `~/.claude/hooks-config.json` — hook configuration format observed

No external sources required. Architecture design answers "how do new components integrate with existing ones" — this is a composition question answerable entirely from the codebase.

---
*Architecture research for: Keystone v1.1 Dynamic Toolkit Discovery*
*Researched: 2026-03-13*
