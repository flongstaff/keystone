# Phase 14: Subagent Injection and Confirmation UX - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Inject stage-filtered capability pointers into GSD and BMAD subagent Task() spawns so they can leverage the user's installed toolkit. Add a batched confirmation flow for unknown tools. Keep full registry loading lazy (only on "Discover tools"). Wizard.md, wizard-backing-agent.md, and GSD workflow files (plan-phase.md, execute-phase.md, research-phase.md) are modified. No new scanning logic (Phase 12), no state changes (Phase 13), no catalog display changes (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Injection format
- `<capabilities>` XML section matching existing GSD prompt tag convention (`<objective>`, `<files_to_read>`, etc.)
- Placed after `<files_to_read>` and before `<success_criteria>` in Task() prompts
- Each pointer: `- name — one-liner description` format (~10 tokens per pointer)
- Stage-specific preamble one-liner: research gets "Query these before investigating unknowns:", execution gets "Use these during implementation if relevant:", etc.
- MCP entries suffixed with `(configured)` — conditional language per CONF-03

### Trust classification
- **Auto-inject (no confirmation):** Keystone-authored agents (11 known), GSD subagent types, read-only MCPs (context7, deepwiki)
- **Confirm first:** User-installed agents, write-capable MCPs, unknown hooks
- **Trust list:** Hardcoded allowlist of known-safe tool names in the injection code — matches Phase 12's hardcoded stage tags approach
- **MCP qualifier:** All MCP entries use "configured — availability may vary" language

### Confirmation experience
- **Timing:** Before first Task()/Agent() spawn — after user selects an action that triggers a spawn, but before the spawn fires
- **Options:** "Allow all" / "Skip unknown tools" / "Cancel"
  - Allow all: inject known-safe + unknown tools
  - Skip unknown tools: inject only known-safe tools, proceed with spawn
  - Cancel: don't spawn
- **Skip rule:** If all discovered tools are known-safe (no unknowns), no confirmation prompt appears at all — zero friction
- **Persistence:** Per `/wizard` invocation only — ephemeral, resets next invocation
- **Post-spawn visibility:** Silent — injection does not appear as user-visible output (SC #1)

### Injection scope
- **GSD workflows modified:** plan-phase.md (researcher, planner spawns), execute-phase.md (executor, verifier spawns), research-phase.md (researcher spawn)
- **Wizard files modified:** wizard.md (Agent() spawns for health check), wizard-backing-agent.md (Task() for bridge)
- **Not injected:** Skill() invocations (INJ-04), GSD internal tools (map-codebase, debug, etc.)
- **Build method:** Inline instruction in each workflow — "Read wizard-state.json toolkit.by_stage, filter for current stage, build `<capabilities>` block, append to Task() prompt"
- **Stage-to-subagent mapping:**
  - gsd-phase-researcher → by_stage.research
  - gsd-planner → by_stage.planning
  - gsd-executor → by_stage.execution
  - gsd-verifier → by_stage.review
  - gsd-plan-checker → by_stage.review
  - context-health-monitor → by_stage.review

### Claude's Discretion
- Exact preamble wording per stage (guidelines above, refine for clarity)
- How to handle wizard-state.json missing or toolkit empty (graceful skip)
- Exact AskUserQuestion formatting for the confirmation prompt
- Whether to read wizard-state.json once at workflow start or per-spawn
- How BMAD subagent injection works (INJ-02) — likely similar pattern in wizard-backing-agent.md

</decisions>

<specifics>
## Specific Ideas

- The `<capabilities>` block should feel native — subagents shouldn't notice it's "injected," it should read like a natural part of the prompt
- Confirmation prompt should list only the unknown tools being added, not the known-safe ones — known-safe are always included
- Stage-specific preambles make the injection actionable: a researcher who sees "Query these before investigating unknowns" will actually use context7, vs a generic "Tools available" which gets ignored
- The 5-8 pointer cap from MATCH-02 (Phase 12) already limits injection size — no additional cap needed here

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `wizard-state.json` toolkit section: Already contains `by_stage` arrays with tool names grouped by research/planning/execution/review (Phase 13)
- `toolkit-discovery.sh`: Produces the registry with stage-tagged entries (Phase 12)
- GSD Task() prompt templates: Use consistent XML-style sections that the `<capabilities>` block extends

### Established Patterns
- GSD workflows are markdown instruction files — Claude reads them and follows steps. "Build capabilities block" is a new inline instruction step, not a bash script.
- wizard-state.json is already read by wizard.md at Step 2 — toolkit data is available without additional file reads
- Hardcoded allowlists: Phase 12 uses hardcoded stage tags for known Keystone agents — trust list follows the same pattern

### Integration Points
- `wizard-state.json` → toolkit.by_stage: Source of capability pointers for injection
- `~/.claude/get-shit-done/workflows/plan-phase.md`: Add injection step before Task(gsd-phase-researcher) and Task(gsd-planner) spawns
- `~/.claude/get-shit-done/workflows/execute-phase.md`: Add injection step before Task(gsd-executor) and Task(gsd-verifier) spawns
- `~/.claude/get-shit-done/workflows/research-phase.md`: Add injection step before Task(gsd-phase-researcher) spawn
- `skills/wizard.md`: Add injection step before Agent(context-health-monitor) spawn
- `skills/wizard-backing-agent.md`: Add injection step before Task(bmad-gsd-orchestrator) spawn
- Confirmation prompt: Uses AskUserQuestion in wizard.md (tool already in YAML frontmatter)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-subagent-injection-confirmation-ux*
*Context gathered: 2026-03-13*
