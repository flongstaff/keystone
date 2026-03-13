# Project Research Summary

**Project:** Keystone v1.1 — Dynamic Toolkit Discovery
**Domain:** Claude Code extension system — dynamic agent/skill/hook/MCP discovery and subagent capability injection
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

Keystone v1.1 is a brownfield capability milestone on top of a fully-shipped v1.0 wizard orchestrator. The problem it solves is concrete and measured: the Phase 7 catalog hardcodes 11 agents, 3 skills, and 3 hooks, while the user's actual `~/.claude/` installation contains 160 agents, 33 skills, 24 hooks, and 15+ MCP plugin servers. Every one of those 149+ undiscovered agents is invisible to the wizard and to any subagent the wizard spawns. The milestone's job is to close that gap — discover what is installed, map it to workflow stages, and inject lightweight capability pointers into subagent prompts — without breaking the wizard's hard constraint of less than 10% context budget overhead.

The recommended approach is a two-level discovery architecture. A new shell script (`toolkit-discovery.sh`) runs a TTL-gated scan at wizard startup and writes two outputs: a full catalog (`toolkit-registry.json`, read only on "Discover tools" selection) and a compact stage-tagged summary embedded in the existing `wizard-state.json` (read on every `/wizard` call). This two-level split is the key architectural decision — it is what makes dynamic discovery budget-safe. The wizard reads only the compact summary on every startup (~600 bytes additional); the full registry is only loaded when the user explicitly requests the catalog. Capability pointers injected into GSD subagent Task() prompts are drawn from the compact summary filtered to the current workflow stage — at most 5-8 tool references totaling ~200 tokens, well within budget.

The primary risk is context budget overrun from doing too much in a single injection pass. Research identified eight critical pitfalls, all centering on the same root cause: discovery outputs routed through context rather than through files. The mitigation is strict — all discovery output is written to files, never printed to the terminal or embedded in prose; injection uses name-and-one-liner pointers only, never full agent bodies; confirmation UX is batched to at most one question per `/wizard` invocation; and the hardcoded Phase 7 catalog remains as a fallback until the dynamic catalog passes parity tests. Build order enforces this: `toolkit-discovery.sh` ships and is validated before anything in `wizard-detect.sh` or `wizard.md` is touched.

## Key Findings

### Recommended Stack

The runtime environment is frozen — Claude Code, bash, python3, and the existing `~/.claude/` directory structure are not choices to make. All discovery logic runs in bash (filesystem scanning) and python3 (JSON parsing of `settings.json` and `installed_plugins.json`). Python3 is already used in `wizard-detect.sh` for JSON operations — no new dependency. MCP server discovery reads from two sources: the plugin registry at `~/.claude/plugins/installed_plugins.json` (for Claude Code plugin-installed MCP servers) and `mcpServers` in `~/.claude/settings.json` (for explicitly configured servers). The `mcp__<name>__*` tool naming convention is directly observed and confirmed as the authoritative naming pattern.

**Core technologies:**
- Bash: filesystem scanning and JSON writes — already the pattern in `wizard-detect.sh`; no performance concern at 200 files
- python3: JSON parsing of `settings.json`, `installed_plugins.json`, and `.mcp.json` files — already used, no new dependency
- `wizard-state.json`: extended with a `toolkit{}` compact summary section — additive only, no schema breaking change
- `toolkit-registry.json`: new full catalog cache with 5-minute TTL — prevents re-scanning on every `/wizard` invocation
- `toolkit-discovery.sh`: new shell script encapsulating all scan logic — callable from `wizard-detect.sh` without changing detection logic

### Expected Features

**Must have (v1.1 table stakes — per PROJECT.md):**
- Dynamic agent scan — replace hardcoded 11-agent catalog with live scan of `~/.claude/agents/*.md`; parse YAML frontmatter `name:` and `description:` fields
- Dynamic MCP scan — read plugin registry and `settings.json` for active MCP servers; add MCP section to discovery catalog (currently absent)
- Subagent context injection — append lightweight capability block to Task() spawns for GSD subagents; stage-filtered, 5-8 pointers max
- Capability-to-stage matching — lookup table mapping research/planning/execution/review stages to tool categories; drives injection filtering
- Token-efficient injection format — name + one-liner only, never full agent body; validated against 10% overhead constraint
- User confirmation when ambiguous — batched at most once per invocation; non-confirmation for Keystone/GSD/read-only MCP tools

**Should have (v1.x post-validation):**
- Dynamic skill scan — `~/.claude/skills/*/SKILL.md` (lower priority than agents/MCP; same pattern)
- Dynamic hook scan — `~/.claude/hooks/*.sh` filename + first comment; simplest scan
- Persistent capability cache — TTL invalidation in `wizard-state.json`; needed once 90+ agent scan latency is measured
- Active tool marking — "(installed)" vs "(configured — availability may vary)" visual indicators

**Defer (v2+):**
- Semantic capability matching — LLM-based classification over 160 agent bodies; too expensive, unproven value over keyword matching
- BMAD subagent injection — out of scope for this milestone; add after GSD injection is proven
- Per-phase tool recommendation history — requires persistent cross-session state; uncertain payoff

### Architecture Approach

The architecture is an additive layer on the existing three-component wizard stack (`wizard-detect.sh` → `wizard-state.json` → `wizard.md`). A new `toolkit-discovery.sh` script is inserted between detection and state write, producing two artifacts: a full `toolkit-registry.json` and a compact summary embedded in `wizard-state.json`. `wizard.md` gains Step 2.5 to extract stage-relevant pointers from the compact summary and append them to Task() prompts. The hardcoded catalog in `wizard.md` is replaced by a dynamic read from `toolkit-registry.json` when "Discover tools" is selected. `wizard-backing-agent.md` is untouched — injection happens at the Task() call site in `wizard.md`, not in the backing agent.

**Major components:**
1. `toolkit-discovery.sh` (NEW) — scans all toolkit locations, applies stage tag matching, writes full registry and compact summary; TTL-gated to skip rescan when cache is fresh
2. `toolkit-registry.json` (NEW) — full discovered catalog with all metadata; only loaded when "Discover tools" is explicitly selected
3. `wizard-state.json toolkit{}` (SCHEMA EXTENSION) — compact stage-relevant pointers plus discovery counts; read on every wizard startup but adds only ~600 bytes
4. `wizard-detect.sh` (MODIFIED) — calls `toolkit-discovery.sh` and embeds compact summary; all existing detection logic untouched
5. `wizard.md` (MODIFIED) — reads toolkit summary at Step 2.5, injects into Task() prompts, replaces hardcoded catalog with dynamic read, adds confirmation UX

### Critical Pitfalls

1. **Discovery output becomes context sink** — All scan output must go to files only; nothing printed to terminal; wizard-state.json must not grow beyond ~600 bytes for the toolkit section; measure startup token usage before and after scanner is added and confirm no change

2. **Injecting into every Task() spawn regardless of stage** — Filter to current stage only (research/planning/execution/review); inject at most 5-8 pointers per spawn; test that GSD subagent turn count does not increase with injection enabled

3. **Hardcoded catalog removed before dynamic catalog works** — Keep Phase 7 hardcoded catalog as a fallback until dynamic catalog passes parity tests; never delete hardcoded text in the same commit that wires up dynamic reading; fresh install must work without toolkit-registry.json

4. **MCP discovery returns stale/environment-specific results** — All MCP recommendations must use conditional language ("if available"); toolkit-registry.json must be gitignored (machine-specific MCP configuration must not be committed); distinguish "configured" from "verified available"

5. **Injection breaks GSD Task() prompt contracts** — Read GSD internal prompt templates (`~/.claude/get-shit-done/workflows/`) before specifying injection format; injection must use clearly non-instructional syntax (XML comments or a labeled optional section); verify that removing injection does not change subagent first tool call

6. **Confirmation UX accumulates questions** — Cap AskUserQuestion for capability confirmation at one batched question per invocation; Keystone/GSD agents and read-only MCPs like context7 inject without confirmation

## Implications for Roadmap

The architecture research already proposed a 6-phase build order based on component dependencies. That order is the correct one — follow it. Each phase has a clear pass/fail test, low regression risk to preceding phases, and maps directly to the pitfall prevention requirements.

### Phase 1: toolkit-discovery.sh — Core Scanner

**Rationale:** Everything downstream is blocked on this script producing valid JSON. It can be built and tested in complete isolation before touching any existing component. This is the foundation that all injection and display logic depends on.

**Delivers:** `skills/toolkit-discovery.sh` — scans agents, skills, hooks, MCP servers; applies stage tagging via keyword matching on description fields; writes `toolkit-registry.json` (full) and emits compact summary JSON; TTL-gated to skip rescan when cache is fresh.

**Addresses:** Dynamic agent scan, dynamic MCP scan, capability-to-stage matching, persistent capability cache, token-efficient format (the compact summary format is frozen here)

**Avoids:** Pitfall 1 (context sink) — all output to files; Pitfall 6 (name-based matching) — description-field keyword matching specified here; Pitfall 5 (startup latency) — TTL gate implemented here

**Test:** `bash skills/toolkit-discovery.sh | python3 -m json.tool` produces valid JSON with non-empty counts matching `ls ~/.claude/agents/ | wc -l`

**Research flag:** SKIP phase research — patterns are fully documented in STACK.md and ARCHITECTURE.md. Build from those specs.

### Phase 2: wizard-detect.sh Integration

**Rationale:** Depends on Phase 1 existing. This is a small additive change — one new section calling `toolkit-discovery.sh` and one new `toolkit{}` field in the JSON write. All existing detection logic is untouched. Regression risk is LOW.

**Delivers:** Modified `skills/wizard-detect.sh` — invokes `toolkit-discovery.sh` and embeds compact summary in `wizard-state.json`

**Addresses:** wizard-state.json schema extension (additive only)

**Avoids:** Pitfall 2 (schema bloat) — compact summary only in wizard-state.json; full registry stays in toolkit-registry.json

**Test:** `bash skills/wizard-detect.sh` → inspect `.claude/wizard-state.json` for `toolkit{}` section with correct counts and stage_relevant pointers

**Research flag:** SKIP phase research — integration is mechanical; ARCHITECTURE.md has exact insertion points.

### Phase 3: wizard.md — Task() Injection and MCP Recommendations

**Rationale:** Depends on Phase 2 (wizard-state.json must contain toolkit data before wizard.md can read it). This is the highest-risk change because wizard.md is the user-facing UI. Build injection in sub-steps: add Step 2.5 read-only first, then wire to backing-agent spawns, then to drift-check/validate-phase Agent() calls, then MCP recommendation moments, then confirmation UX.

**Delivers:** Modified `skills/wizard.md` with Step 2.5 toolkit hint extraction, stage-filtered capability suffix appended to Task() prompts, MCP surfacing at relevant workflow moments, batched confirmation UX for ambiguous tools

**Addresses:** Subagent context injection, user confirmation when ambiguous, token-efficient injection format

**Avoids:** Pitfall 2 (injection to wrong stage) — stage-filtered from compact summary; Pitfall 7 (confirmation friction) — one batched question max; Pitfall 8 (breaking GSD prompt contracts) — read GSD templates first; Anti-pattern 3 (inject into Skill() calls) — Task()/Agent() only

**Test:** Run `/wizard` mid-execution, select "Check drift" — verify context-health-monitor receives injected suffix; verify suffix does not appear as user-visible output; verify GSD subagent first tool call is NOT a Read of an injected agent file

**Research flag:** NEEDS attention before implementation — read `~/.claude/get-shit-done/workflows/` templates to confirm injection format is safe for GSD prompt contracts before writing any injection code.

### Phase 4: Dynamic "Discover tools" Display

**Rationale:** Depends on Phase 1 (toolkit-registry.json must exist). Isolated change — only the catalog rendering logic in wizard.md changes. Hardcoded catalog text is replaced by dynamic read from toolkit-registry.json WITH the hardcoded catalog as fallback when the registry is absent or malformed.

**Delivers:** "Discover tools" option reads toolkit-registry.json and displays grouped results (by stage relevance, then by category); hardcoded Phase 7 catalog remains as fallback

**Addresses:** Dynamic skill scan, dynamic hook scan, active tool marking

**Avoids:** Pitfall 4 (catalog removed too early) — hardcoded fallback is explicit and tested; parity test required before fallback can be removed

**Test:** Run `/wizard`, select "Discover tools" — count shown matches `ls ~/.claude/agents/ | wc -l`; every Phase 7 hardcoded entry appears in dynamic output; fresh install (no toolkit-registry.json) shows hardcoded fallback without errors

**Research flag:** SKIP phase research — patterns are standard; FEATURES.md has the grouping and display spec.

### Phase 5: Global Deployment Sync

**Rationale:** All previous phases develop and test in the Keystone project-local `skills/` directory. This phase syncs verified files to `~/.claude/skills/` following the established v1.0 Phases 9 and 11 deployment pattern.

**Delivers:** `~/.claude/skills/` updated with new `toolkit-discovery.sh`, modified `wizard-detect.sh`, and modified `wizard.md`; `toolkit-registry.json` confirmed gitignored

**Avoids:** Pitfall — MCP state committed to git — gitignore confirmation is a pass/fail criterion here

**Test:** Run `/wizard` in a different project — verify discovery runs against global `~/.claude/agents/` correctly; verify no toolkit-registry.json appears in `git status`

**Research flag:** SKIP — deployment pattern is identical to v1.0.

### Phase Ordering Rationale

- **Scanner before integration:** toolkit-discovery.sh must be independently testable before anything in the wizard depends on it. This prevents debugging two components simultaneously.
- **Detection integration before UI injection:** wizard-state.json must carry the toolkit data before wizard.md's Step 2.5 can read it. The read depends on the write.
- **Injection before catalog display:** Both use toolkit data, but injection is the core value proposition of v1.1. Catalog display is the user-visible surface but injection is what powers subagent awareness. Get injection right first.
- **Keep hardcoded catalog until Phase 4 parity is proven:** This is an explicit constraint from the pitfalls research. The fallback is the safety net for the transition.
- **Gitignore before global deployment:** toolkit-registry.json contains machine-specific MCP state. If committed accidentally, it will be wrong on every other machine.

### Research Flags

Phases needing deeper attention before implementation:

- **Phase 3 (wizard.md injection):** Read GSD internal prompt templates in `~/.claude/get-shit-done/workflows/` before writing a single line of injection code. The GSD Task() prompt structure is a contract that injection must not break. The format choice (XML comment, labeled optional section, or description-field-only) depends on what GSD subagents treat as instructions vs. hints.

Phases with standard patterns (no research needed):

- **Phase 1 (toolkit-discovery.sh):** Fully specified in STACK.md and ARCHITECTURE.md with exact bash and python3 code patterns. Build from specs.
- **Phase 2 (wizard-detect.sh integration):** Mechanical additive change; exact insertion point documented in ARCHITECTURE.md.
- **Phase 4 (Discover tools display):** Grouping and display format specified in FEATURES.md; fallback pattern is standard.
- **Phase 5 (global deployment):** Identical to established v1.0 pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All components directly observed in the running installation; no inference required. python3 + bash is not a choice — it is what exists. |
| Features | HIGH | Derived from PROJECT.md v1.1 requirements plus direct inventory of `~/.claude/` contents. Feature list is not hypothetical — it closes the gap between the hardcoded catalog (11 agents) and the installed reality (160 agents). |
| Architecture | HIGH | All components are readable first-party source files. The two-level (registry + compact summary) design is derived directly from the 10% budget constraint and the measured agent count (160). No external architecture references needed. |
| Pitfalls | HIGH | Eight critical pitfalls all derived from first-principles analysis of the existing wizard architecture and the budget constraint math. Token cost estimates are calculated from measured agent file sizes. |

**Overall confidence:** HIGH

### Gaps to Address

- **GSD internal Task() prompt format:** ARCHITECTURE.md and PITFALLS.md both flag that the injection format must be validated against GSD's internal prompt templates before implementation. These templates live in `~/.claude/get-shit-done/workflows/`. Resolution: read those files at the start of Phase 3 before writing injection code.

- **MCP availability vs. configuration distinction:** The data model for what to record in `toolkit-registry.json` for MCP servers must distinguish "configured in settings.json" from "verified available in current session." The research recommends conditional language in all MCP recommendations, but the exact field schema for this distinction is not specified. Resolution: settle the schema in Phase 1 when designing the compact summary format.

- **Keyword matching false positive rate:** Capability-to-stage matching uses keyword matching on description fields. Description field quality varies across 160 agents. Resolution: test the classifier against all 160 agents in Phase 1 and measure the false positive rate before committing to the algorithm.

## Sources

### Primary (HIGH confidence — direct first-party analysis)

- `/Users/flong/Developer/keystone/skills/wizard.md` — Phase 7 hardcoded catalog, menu structure, all spawn patterns
- `/Users/flong/Developer/keystone/skills/wizard-detect.sh` — established scan pattern, JSON write format, python3 usage
- `/Users/flong/Developer/keystone/skills/wizard-backing-agent.md` — Task() invocation pattern, Route B/C routing
- `/Users/flong/Developer/keystone/.claude/wizard-state.json` — live schema as written by wizard-detect.sh
- `/Users/flong/Developer/keystone/.planning/PROJECT.md` — v1.1 active requirements and constraints
- `~/.claude/agents/` — 160 installed global agents with YAML frontmatter (direct observation)
- `~/.claude/skills/` — 33 installed global skills with SKILL.md structure (direct observation)
- `~/.claude/hooks/` — 24 hook scripts and registered events (direct observation)
- `~/.claude/settings.json` — hook schema, enabledPlugins, mcpServers (direct observation)
- `~/.claude/plugins/installed_plugins.json` — 27 installed plugins, 6 with MCP servers (direct observation)
- `~/.claude/plugins/cache/` — MCP plugin cache with `.mcp.json` naming convention confirmed (direct observation)
- `~/.claude/get-shit-done/workflows/plan-phase.md` — `<additional_context>` injection point in researcher spawn (direct observation)

### Secondary (MEDIUM confidence)

- Token cost calculation for capability pointer injection — estimated from avg agent file size (9,417 chars over 6 sampled agents); pointer estimate (80 chars each); sample size limited but directionally correct
- Keyword matching false positive rate — not measured against all 160 agents; estimated from description field patterns in the subset inspected

---
*Research completed: 2026-03-13*
*Ready for roadmap: yes*
