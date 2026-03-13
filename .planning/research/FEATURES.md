# Feature Research

**Domain:** Dynamic toolkit discovery and capability-aware orchestration for an AI agent wizard system
**Researched:** 2026-03-13
**Confidence:** HIGH — based on direct analysis of all existing wizard infrastructure, live agent/skill/hook/MCP inventory in ~/.claude/, and clear scope from PROJECT.md v1.1 requirements

---

## Research Method

No web search was needed. All findings derive from direct code and file analysis:
- `skills/wizard.md` — full wizard UI skill, current "Discover tools" hardcoded catalog
- `skills/wizard-backing-agent.md` — Route B and C implementations
- `skills/wizard-detect.sh` — implied by references in wizard.md Step 1
- `.claude/wizard-state.json` — current detection output schema
- `~/.claude/agents/*.md` — 90+ agents installed globally (gsd-executor, gsd-planner, design-*, sales-*, etc.)
- `~/.claude/skills/` — skill directories: code-standards, fix-issue, gen-test, release-notes, project-scaffolder, create-agent-skills, expertise/*, docker-dev-local, security-check, agent-browser, adapt, animate, bolder, clarify, colorize, delight, distill, extract, wizard, wizard-backing-agent
- `~/.claude/hooks/` — 20 hooks: session-start.sh, post-write-check.sh, stack-update-banner.sh, pre-bash-guard.sh, context-warning.sh, post-failure-guidance.sh, skill-activation-prompt.sh, quality-check.sh, etc.
- `~/.claude/plugins/cache/` — MCP plugin inventory: context7, playwright, serena, greptile, Notion, Figma, Slack, Chrome DevTools, HuggingFace, TypeScript LSP, Swift LSP, claude-code-setup, code-simplifier, superpowers, agent-sdk-dev
- `.planning/PROJECT.md` v1.1 requirements — explicit feature list for this milestone

**What the v1.0 catalog shows (Phase 7 baseline):**
The current "Discover tools" option shows a hardcoded list: 11 Keystone agents (entry/bridge/domain/maintenance), 3 skills (wizard, wizard-backing-agent, wizard-detect), and 3 hooks (session-start, stack-update-banner, post-write-check). This is the catalog that existed at the time of writing and is baked directly into wizard.md as inline text — duplicated across 4 code paths. It does NOT reflect the 90+ global agents, 20+ skills, 20 hooks, or 15 MCP servers the user actually has installed.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features the system must have for "dynamic toolkit discovery" to mean anything. Without these, the feature is just a renamed version of what Phase 7 already built.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Dynamic agent discovery** | The catalog today is hardcoded and only shows Keystone agents. Users expect "Discover tools" to show ALL installed agents — the 90+ global ones plus any project-local ones — not just the 11 Keystone authored ones. | MEDIUM | `ls ~/.claude/agents/*.md` plus a glob for project-local `agents/**/*.md`. Parse YAML frontmatter name + description fields. Already readable: agents have `name:` and `description:` in YAML. |
| **Dynamic skill discovery** | Skills installed in `~/.claude/skills/` (20+ directories) and any project-local `skills/` are invisible to the current catalog. Users assume the wizard knows about tools they've installed. | MEDIUM | Skills use directory/SKILL.md structure. Read the `name:` and `description:` from each SKILL.md. Directory walk with `ls ~/.claude/skills/*/SKILL.md`. |
| **Dynamic hook discovery** | The current catalog lists exactly 3 hooks. There are 20 hooks in `~/.claude/hooks/`. Users who add hooks expect them to appear. | LOW | `ls ~/.claude/hooks/*.sh` plus parse the first comment block for description. Simpler than agents/skills because hooks have no YAML frontmatter — use filename as name and first-comment as description. |
| **MCP server awareness** | The current catalog has no MCP section at all. The user has 15+ MCP plugins (context7, playwright, Notion, Figma, Slack, Chrome DevTools, etc.). Subagents that could use these tools have no way to know they're available unless told. | HIGH | MCP servers are registered via Claude Code plugin cache at `~/.claude/plugins/cache/`. Read each `.mcp.json` or `.claude-plugin/plugin.json` to extract name and tools. Claude Code also has a CLI `claude mcp list` command (verify availability). The scan path is deterministic but the format varies per plugin. |
| **Subagent context injection** | When the wizard routes to a GSD subagent (gsd-executor, gsd-phase-researcher, etc.), that subagent gets no information about what tools are available. It will suggest using its built-in tools and miss context7, playwright, or Notion if they'd help the current phase. | HIGH | Requires: (1) capability-to-stage mapping (which tools help at which GSD phase), (2) lightweight pointer injection into the subagent Task() prompt — "FYI: context7 and playwright are available via MCP." NOT full agent/skill text injection. Pointers only, per the token budget constraint. |
| **Token-efficient injection** | The wizard has a hard < 10% context budget constraint. Injecting full agent or skill docs would blow it immediately. Users expect the wizard to "use their tools" without paying a context tax. | HIGH | Inject capability pointers: "Available MCP: context7 (library docs), playwright (browser testing)" — one line per tool, not the tool's full instructions. The subagent can read the tool docs itself if it needs them. |
| **User confirmation when ambiguous** | If the system discovers a tool that MIGHT be useful but isn't certain, it should ask before using it rather than silently applying it. This is the trust contract: "system uses my tools" means "system tells me it's using my tools and why." | MEDIUM | Ambiguity threshold: anything where the capability match is a heuristic (e.g., "playwright might help with your browser-related UAT") gets a confirmation prompt. Deterministic matches (e.g., "context7 is always useful for research phases") do not. |

### Differentiators (Competitive Advantage)

Features that move from "shows you what tools exist" to "actively uses your tools well."

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Capability-to-stage matching** | Don't just list tools — map them to the workflow stage where they're most useful. A user in a research phase should see "context7 is available for library docs lookups" not a flat list of everything. A user executing a phase should see "playwright is available for browser UAT." | HIGH | Needs a capability taxonomy: research tools (context7, greptile), execution tools (playwright, Chrome DevTools, serena), review tools (code-review plugin, pr-review-toolkit), planning tools (Notion, Figma). Map GSD phase types to capability categories. Store this as a small lookup table in wizard-detect.sh or a separate config. |
| **"Active tool" marking beyond domain agents** | Today wizard marks the domain agent "(active)." The same pattern should extend: mark which MCP servers and skills are currently active (installed and accessible), vs which are in the catalog but not installed. Users with playwright installed vs not installed have different capabilities. | MEDIUM | Scan determines presence. Display format: "playwright (installed)" vs "playwright (not installed — see instructions)." This is the "which tools do you actually have" vs "which tools exist in theory" distinction. |
| **Research phase MCP surfacing** | When the wizard routes to a GSD research phase (gsd-phase-researcher), proactively surface: "context7 and greptile are available if you need library docs or codebase search." This saves the researcher from having to know these tools exist. | MEDIUM | Requires knowing which GSD phase type is active (research, planning, execution, review) from wizard-state.json. Already detected: `gsd.current_phase` is in wizard-state.json. Cross-reference phase number against ROADMAP.md phase name to infer type. Or ask the user one time to tag phases with type. |
| **Deduplication between global and project-local** | The user may have a project-local `agents/` and a global `~/.claude/agents/`. Both should appear in the catalog, deduped by name. If both have an agent named "gsd-executor," show it once but note where it came from. | LOW | Post-scan dedup by name. Prefer project-local when names collide (closer to the project). |
| **Graceful scan failure** | Discovery requires reading the filesystem. On a new machine or in a CI context, some paths may not exist. The wizard must not crash if `~/.claude/agents/` doesn't exist. | LOW | Guard every glob with existence check. Fall back to current hardcoded catalog if scan produces zero results. Log a warning but don't block the wizard. |
| **Persistent capability cache** | Running discovery on every `/wizard` invocation adds a bash scan on startup. For users with 90+ agents, this can add latency. Cache the scan result to `wizard-state.json` under a `toolkit` key and invalidate it when files change (check mtime on the agents directory). | MEDIUM | `wizard-state.json` already exists and is written by wizard-detect.sh. Add a `toolkit_scanned_at` timestamp and rescan only if the timestamp is older than 5 minutes or the agent directory mtime changed. This is the same "cold read from disk" pattern the wizard already uses for project state. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Full agent doc injection into subagent context** | "The subagent should know everything about the tools available to it." | A single agent YAML + body averages 2-4k tokens. 90 agents = 180-360k tokens — exceeds a full context window before any work happens. Violates the < 10% overhead constraint instantly. | Inject capability pointers only: name, one-liner description, activation phrase. The subagent can read the agent file itself if it decides to use that agent. |
| **Auto-invoking tools without confirmation** | "Just use the best tool automatically — don't ask me." | The wizard has no way to know which tool the user wants for a given task. Auto-invoking context7 in a phase where the user is doing UI work wastes turns. Invoking playwright without knowing it's connected to a live browser causes errors. The confirmation UX exists precisely because capability matching is heuristic, not certain. | Deterministic cases (e.g., always show MCP list in research phases) can auto-surface. Heuristic matches (e.g., "playwright might help") require one confirmation question. |
| **Crawling all agent files at startup for semantic matching** | "The system should understand what each agent does and match it to the task semantically." | Semantic matching requires reading all 90+ agent files at startup to extract their capabilities. This is a full LLM pass over 360k+ tokens of agent docs on every `/wizard` invocation. Destroys the context budget. | Use explicit capability tags in agent YAML frontmatter (`capability: [research, web-search]`) and match on tags. This makes the matching deterministic and zero-cost to query. If agents don't have tags, use a small hardcoded mapping file rather than reading every agent. |
| **Plugin marketplace discovery (finding new tools)** | "The wizard should suggest tools I don't have installed yet." | Suggesting uninstalled tools requires knowing the full Claude Code plugin marketplace catalog, which changes externally and requires network access. This is outside Keystone's scope (one project, one session, one user's installed tools) and is already covered by `stack-update-watcher`. | Stay scoped to installed tools only. If a user asks "what tools should I install," point to the Claude Code plugin marketplace docs — don't build a new feature for it. |
| **Per-project tool whitelisting/blacklisting** | "I want to control which tools the wizard surfaces for this project." | Configuration management is overhead. The user has to configure before getting value, which is friction before first use. And the discovery catalog is already filtered by what's installed — there are no wrong tools to surface. | Surface everything installed. Let the user ignore what's irrelevant. The UX cost of one more line in the catalog is lower than the config overhead of maintaining a whitelist. |
| **Tool versioning and compatibility checking** | "Show me which version of each MCP server I have and whether it's compatible with the current phase." | Versions live inside plugin packages, not in easily discoverable locations. Compatibility between tool versions and workflow phases is not a solvable problem without deep MCP protocol knowledge. This is the kind of generalist orchestration feature that belongs in a package manager, not a project wizard. | `stack-update-watcher` already handles checking for BMAD/GSD updates. Let it handle all version monitoring. |
| **Automatic capability injection based on project type** | "Since this is an open-source project, the wizard should automatically inject the open-source-agent into every subagent prompt." | The open-source-agent is already surfaced via the domain agent banner. Injecting it into every subagent prompt means every subagent gets different instructions based on project type — this creates hidden behavior that's hard to debug and violates the "no surprises" principle. | Keep explicit: the banner tells the user the domain agent is available. The user decides to activate it. Subagents don't get automatic injections. |

---

## Feature Dependencies

```
Dynamic agent scan
    └──enables──> Capability-to-stage matching
    └──enables──> "Active tool" marking
    └──enables──> Deduplication (global + project-local)

Dynamic MCP scan
    └──enables──> MCP surfacing in catalog
    └──enables──> Research phase MCP surfacing

Capability-to-stage matching
    └──enables──> Subagent context injection (pointers only)
    └──enables──> Research phase MCP surfacing

Token-efficient injection format
    └──required by──> Subagent context injection
    └──required by──> Hardcoded < 10% context budget

wizard-state.json toolkit cache
    └──requires──> Dynamic agent scan (something to cache)
    └──enables──> Persistent capability cache (skip rescan)

User confirmation flow
    └──requires──> Capability-to-stage matching (need a match to confirm)

Dynamic hook scan
    └──independent of above
    └──enhances──> Discovery catalog completeness

Phase 7 hardcoded catalog (existing)
    └──replaced by──> Dynamic agent scan + Dynamic skill scan + Dynamic hook scan + Dynamic MCP scan
    └──fallback for──> Graceful scan failure (use hardcoded if scan returns nothing)
```

### Dependency Notes

- **Dynamic scan must precede injection:** You cannot inject pointers to tools you haven't discovered yet. Discovery runs at wizard startup (wizard-detect.sh), injection happens at subagent dispatch (wizard.md Task() call).
- **Capability-to-stage matching required before injection is useful:** Injecting an unsorted list of 90 agents into every subagent prompt is noise. The mapping table (research → context7/greptile, execution → playwright/chrome-devtools) is what makes injection valuable vs burdensome.
- **MCP scan is independently scoped:** MCP servers are discovered via plugin cache, not the same path as agents or skills. This can be built and tested independently.
- **Phase 7 catalog is the fallback, not the primary:** The hardcoded catalog should remain as the fallback if dynamic scan produces zero results. It should not be removed — it's the safety net for corrupted or missing `~/.claude/` directories.

---

## MVP Definition

### Launch With (v1.1 — current milestone)

Minimum viable "dynamic toolkit discovery." These are the requirements listed in PROJECT.md v1.1.

- [ ] **Dynamic agent scan** — scan `~/.claude/agents/*.md` and project-local `agents/**/*.md`, extract name + description from YAML frontmatter — this replaces the hardcoded 11-agent catalog with the actual installed count
- [ ] **Dynamic skill scan** — scan `~/.claude/skills/*/SKILL.md` and project-local `skills/**/*.md`, extract name + description — replaces hardcoded 3-skill catalog
- [ ] **Dynamic hook scan** — scan `~/.claude/hooks/*.sh`, extract hook name from filename and description from first comment block — replaces hardcoded 3-hook catalog
- [ ] **MCP server awareness** — scan `~/.claude/plugins/cache/` for installed MCP servers, extract name and capability summary from plugin.json — add a new MCP section to the discovery catalog
- [ ] **Capability-to-stage matching** — a small lookup table (research/planning/execution/review phases mapped to tool categories) stored in wizard-detect.sh or a dedicated config file — drives the surfacing logic
- [ ] **Subagent context injection** — when the wizard routes to a subagent via Task(), append a lightweight capability block to the Task prompt: "Available tools: [name (description), ...]" — one line per tool, not full docs
- [ ] **User confirmation when ambiguous** — for heuristic matches (tools that might help but aren't certain), present a one-question confirmation before injecting into the subagent prompt
- [ ] **Token-efficient injection** — capability pointers only (name + one-liner), not full agent/skill/MCP docs — validated against the < 10% overhead constraint

### Add After Validation (v1.x)

Features to add once the core scan + inject pipeline is proven:

- [ ] **Persistent capability cache in wizard-state.json** — add `toolkit` key to wizard-state.json with scan results and `toolkit_scanned_at` timestamp; invalidate if timestamp is older than 5 minutes — prevents re-scanning on every `/wizard` invocation. Trigger: users with 90+ agents report startup latency.
- [ ] **"Active tool" marking beyond domain agents** — mark installed MCP servers and skills as "(installed)" vs "(not installed)" in the catalog — add after scan pipeline is stable enough to trust presence detection
- [ ] **Research phase MCP surfacing** — when wizard routes to a research-type phase, proactively mention context7 and greptile in the routing message — add after capability-to-stage mapping proves correct

### Future Consideration (v2+)

Features to defer until post-milestone:

- [ ] **Semantic capability matching** — match agents to tasks by reading agent descriptions for semantic relevance — defer until it's proven the heuristic tag-based matching is insufficient. High cost (context); low certainty it adds enough value over tags.
- [ ] **Capability injection for BMAD subagents** — inject tool pointers when routing to BMAD agents (/analyst, /architect, /pm). Defer because BMAD is upstream of GSD and the current milestone is focused on GSD subagent injection. Add when BMAD agent activation is shown to benefit.
- [ ] **Per-phase tool recommendation history** — track which tools were used in which phases and surface them next time — requires persistent state across sessions beyond wizard-state.json. Complex; uncertain payoff.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Dynamic agent scan | HIGH — 90+ agents vs 11 hardcoded is the core user pain | MEDIUM — filesystem glob + YAML parse | P1 |
| Dynamic MCP scan | HIGH — currently zero MCP surfacing | HIGH — plugin cache format varies | P1 |
| Subagent context injection | HIGH — the stated goal of the milestone | HIGH — requires matching logic + token-efficient format | P1 |
| Capability-to-stage matching | HIGH — without this, injection is noise | MEDIUM — small lookup table, no ML | P1 |
| Token-efficient injection format | HIGH — context budget constraint is hard | LOW — format decision, not implementation | P1 |
| User confirmation when ambiguous | MEDIUM — trust contract; prevents surprise tool use | MEDIUM — adds one AskUserQuestion flow | P2 |
| Dynamic skill scan | MEDIUM — fewer skills than agents, less critical | LOW — same pattern as agent scan | P2 |
| Dynamic hook scan | LOW — hooks are less frequently relevant to workflows | LOW — simplest scan (no YAML, just filename) | P2 |
| Persistent capability cache | MEDIUM — needed if 90+ agent scan is slow | MEDIUM — timestamp + mtime check in wizard-detect.sh | P2 |
| Active tool marking | LOW — nice-to-have visual indicator | LOW — presence check already done by scan | P3 |
| Research phase MCP surfacing | MEDIUM — high value for the GSD research phase specifically | LOW — one additional message in wizard routing | P3 |

**Priority key:**
- P1: Required for v1.1 milestone per PROJECT.md requirements
- P2: Should have; add in v1.x when core is stable
- P3: Nice to have; future consideration

---

## What Exists vs What Needs Building

| Feature | Exists? | Where | Needs Building |
|---------|---------|-------|---------------|
| Hardcoded Keystone catalog | YES | wizard.md (duplicated 4x across menus) | Replace with dynamic scan result; keep as fallback |
| Agent YAML frontmatter with name/description | YES | All agents in ~/.claude/agents/*.md | Parse it — don't redocument it |
| Skill SKILL.md with name/description | YES | All skills in ~/.claude/skills/*/SKILL.md | Parse it |
| Hook scripts with filename-based names | YES | ~/.claude/hooks/*.sh | Parse filename + first comment |
| MCP plugin cache with plugin.json | YES | ~/.claude/plugins/cache/ | Scan and parse; format is per-plugin, needs inspection |
| wizard-detect.sh writes wizard-state.json | YES | skills/wizard-detect.sh | Extend to add `toolkit` key with scan results |
| wizard.md routes to subagents via Task() | YES | wizard.md bmad-ready scenario Option 1 | Extend Task() prompt to include capability block |
| Capability-to-stage mapping table | NO | — | New small lookup table; store in wizard-detect.sh or dedicated config |
| User confirmation flow for ambiguous matches | NO | — | New AskUserQuestion path in wizard.md |
| Token budget validation for injection | PARTIAL | wizard.md has < 10% budget check, but no injection yet | Extend validation to include injection overhead measurement |

---

## Scope Boundaries: v1.1 vs Future

**In v1.1:**
- Scan and surface ALL installed tools (agents, skills, hooks, MCP servers) — replace hardcoded catalog
- Capability-to-stage mapping (lookup table, not semantic inference)
- Lightweight pointer injection into GSD subagent Task() prompts
- Confirmation UX for heuristic matches
- Token-efficient injection (pointers only)

**NOT in v1.1 (explicitly deferred):**
- Replacing BMAD or GSD agents (out of scope per PROJECT.md)
- Domain-specific logic beyond what exists in IT infra override
- Multi-project orchestration
- Semantic matching (too expensive, unproven value)
- Tool installation or marketplace discovery
- Version compatibility checking

---

## Sources

- `/Users/flong/Developer/keystone/.planning/PROJECT.md` — v1.1 Active requirements (PRIMARY)
- `/Users/flong/Developer/keystone/skills/wizard.md` — Phase 7 hardcoded catalog (what exists today)
- `/Users/flong/Developer/keystone/skills/wizard-backing-agent.md` — Route B/C, Task() injection pattern
- `/Users/flong/Developer/keystone/.claude/wizard-state.json` — current schema (toolkit key absent)
- `~/.claude/agents/*.md` — inventory of 90+ installed global agents (direct scan, HIGH confidence)
- `~/.claude/skills/*/SKILL.md` — inventory of 20+ installed global skills (direct glob, HIGH confidence)
- `~/.claude/hooks/*.sh` — inventory of 20 installed hooks (direct glob, HIGH confidence)
- `~/.claude/plugins/cache/` — MCP plugin cache inventory showing: context7, playwright, serena, greptile, Notion, Figma, Slack, Chrome DevTools, HuggingFace, TypeScript LSP, Swift LSP, superpowers, agent-sdk-dev, code-simplifier, claude-code-setup (direct glob, HIGH confidence)
- `/Users/flong/Developer/keystone/.planning/ROADMAP.md` — Phase 7 implementation detail, v1.1 not yet phased

All findings HIGH confidence — derived from direct file analysis, not training data or inference.

---
*Feature research for: Dynamic toolkit discovery and capability-aware orchestration (Keystone v1.1)*
*Researched: 2026-03-13*
