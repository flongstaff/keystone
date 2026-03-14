# Phase 14: Subagent Injection and Confirmation UX - Research

**Researched:** 2026-03-13
**Domain:** Markdown instruction file modification; GSD Task() prompt protocol; wizard.md conditional logic
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Injection format:**
- `<capabilities>` XML section matching existing GSD prompt tag convention (`<objective>`, `<files_to_read>`, etc.)
- Placed after `<files_to_read>` and before `<success_criteria>` in Task() prompts
- Each pointer: `- name — one-liner description` format (~10 tokens per pointer)
- Stage-specific preamble one-liner: research gets "Query these before investigating unknowns:", execution gets "Use these during implementation if relevant:", etc.
- MCP entries suffixed with `(configured)` — conditional language per CONF-03

**Trust classification:**
- Auto-inject (no confirmation): Keystone-authored agents (11 known), GSD subagent types, read-only MCPs (context7, deepwiki)
- Confirm first: User-installed agents, write-capable MCPs, unknown hooks
- Trust list: Hardcoded allowlist of known-safe tool names in the injection code — matches Phase 12's hardcoded stage tags approach
- MCP qualifier: All MCP entries use "configured — availability may vary" language

**Confirmation experience:**
- Timing: Before first Task()/Agent() spawn — after user selects an action that triggers a spawn, but before the spawn fires
- Options: "Allow all" / "Skip unknown tools" / "Cancel"
  - Allow all: inject known-safe + unknown tools
  - Skip unknown tools: inject only known-safe tools, proceed with spawn
  - Cancel: don't spawn
- Skip rule: If all discovered tools are known-safe (no unknowns), no confirmation prompt appears at all — zero friction
- Persistence: Per `/wizard` invocation only — ephemeral, resets next invocation
- Post-spawn visibility: Silent — injection does not appear as user-visible output (SC #1)

**Injection scope:**
- GSD workflows modified: plan-phase.md (researcher, planner spawns), execute-phase.md (executor, verifier spawns), research-phase.md (researcher spawn)
- Wizard files modified: wizard.md (Agent() spawns for health check), wizard-backing-agent.md (Task() for bridge)
- Not injected: Skill() invocations (INJ-04), GSD internal tools (map-codebase, debug, etc.)
- Build method: Inline instruction in each workflow — "Read wizard-state.json toolkit.by_stage, filter for current stage, build `<capabilities>` block, append to Task() prompt"
- Stage-to-subagent mapping:
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INJ-01 | GSD subagent Task() prompts receive stage-filtered capability pointers (name + one-liner format) | GSD workflows (plan-phase.md, execute-phase.md, research-phase.md) are markdown instruction files — injection is an inline instruction step. Stage arrays from `toolkit.by_stage` in wizard-state.json provide the data source. |
| INJ-02 | BMAD subagent prompts receive stage-filtered capability pointers at appropriate lifecycle points | wizard-backing-agent.md uses Task() to spawn bmad-gsd-orchestrator — injection step added before the Task() spawn using the same pattern as GSD workflows. |
| INJ-03 | Injection uses token-efficient format (~40 tokens per pointer, ~200 total per spawn) | `<capabilities>` block with 5-8 pointers at ~10 tokens each = ~50-80 tokens for content + ~20 for wrapper = ~70-100 tokens total per spawn. CONTEXT.md specifies ~10 tokens per pointer. |
| INJ-04 | Injection targets Task()/Agent() spawns only, never Skill() invocations | Skill() calls are clearly distinguishable from Task()/Agent() in workflow markdown. The instruction "append to Task() prompt" is scoped. Verified by text search after implementation. |
| CONF-01 | Known-safe tools (Keystone/GSD agents, read-only MCPs) auto-inject without confirmation | Hardcoded allowlist in wizard.md identifies the 11 Keystone agents + GSD types + read-only MCPs. If by_stage arrays contain only allowlisted names, confirmation is skipped entirely. |
| CONF-02 | Unknown user-installed tools get one batched confirmation per `/wizard` invocation | wizard.md uses AskUserQuestion (already in tools: list). Per-invocation flag (`unknown_tools_confirmed`) prevents repeat prompts. |
| CONF-03 | MCP recommendations use conditional language ("configured — availability may vary") | Applies when building the `<capabilities>` block — MCP tool names are suffixed. The wizard-state.json currently shows `mcp: 0` on this machine; pattern must be robust to future MCP discovery. |
| PERF-03 | Full registry loaded only when "Discover tools" is explicitly selected | Injection reads only `wizard-state.json` toolkit.by_stage (compact summary) — never reads toolkit-registry.json. This is guaranteed by the build method. |
</phase_requirements>

## Summary

Phase 14 is a pure markdown/instruction edit phase. There is no new code to write — only modifications to six existing markdown instruction files. The "injection" is not a runtime code function; it is a prose instruction that tells a Claude agent "read toolkit.by_stage from wizard-state.json, build a `<capabilities>` block, and append it to the Task() prompt." The instruction sits inline within each workflow file, just before the Task() spawn step it modifies.

The core data already exists: wizard-state.json has been shipping a `toolkit` object with `counts` and `by_stage` arrays since Phase 13. The by_stage format is confirmed from live output: four keys (research, planning, execution, review), each an array of up to 6 tool names. On the current machine this produces arrays like `["gsd-phase-researcher", "project-setup-wizard", "gsd-codebase-mapper", "gsd-context-monitor", "gsd-debugger", "gsd-nyquist-auditor"]` for the research stage.

The highest-risk area is the confirmation UX in wizard.md. AskUserQuestion is already the tool used for all wizard prompts. The confirmation logic must be ephemeral (per `/wizard` invocation), must fire only once before the first spawn, and must not block known-safe tool injection. The allowlist of known-safe tool names must be hardcoded in wizard.md, exactly as Phase 12 hardcoded stage tags for known Keystone agents.

**Primary recommendation:** Edit six files with inline injection instructions + one confirmation block in wizard.md. Test each injection point by verifying text search shows no Skill() injection, and by measuring wizard startup context window before and after.

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| wizard-state.json | Phase 13 output | Data source for capability pointers | Already populated by toolkit-discovery.sh integration; no new data collection needed |
| GSD workflow markdown files | Existing | Instruction files hosting injection steps | GSD workflows are prose instructions; new steps are added as prose, not code |
| AskUserQuestion | Claude Code built-in | Confirmation prompt mechanism | Already in wizard.md's tools: frontmatter list; used for all existing wizard menus |
| XML section tags | GSD convention | `<capabilities>` block wrapper | `<objective>`, `<files_to_read>`, `<success_criteria>`, etc. already use this convention in every Task() prompt |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Python3 inline | System | Parse by_stage arrays from wizard-state.json | Same pattern used in wizard-detect.sh for JSON extraction; only needed if bash variable substitution is insufficient |
| Bash jq-less JSON access | System | Extract toolkit.by_stage from wizard-state.json | wizard-detect.sh uses python3 one-liners for JSON; same approach applies here if direct variable interpolation is insufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline prose instruction in each workflow | A new helper script | Inline prose is native to GSD workflows — no new file, no import, consistent with how the phase works |
| Per-spawn `wizard-state.json` read | Read once at workflow start | Read-once reduces redundancy; but wizards already read wizard-state.json in Step 2 and have the data in context |
| Per-invocation ephemeral flag in memory | Persistent flag in wizard-state.json | wizard-state.json is overwritten on every wizard run — it cannot store ephemeral session flags across turns |

**Installation:** No new dependencies. All components are already installed.

## Architecture Patterns

### Recommended Project Structure

The injection adds inline steps to existing files:

```
skills/
├── wizard.md                    # ADD: confirmation logic (Step 2.5), trust classification
├── wizard-backing-agent.md      # ADD: injection step before Task(bmad-gsd-orchestrator)
└── wizard-detect.sh             # UNCHANGED (Phase 13 already complete)

~/.claude/get-shit-done/workflows/
├── plan-phase.md                # ADD: injection step before Task(gsd-phase-researcher) and Task(gsd-planner)
├── execute-phase.md             # ADD: injection step before Task(gsd-executor) and Task(gsd-verifier)
└── research-phase.md            # ADD: injection step before Task(gsd-phase-researcher)
```

### Pattern 1: Injection Step in GSD Workflow

**What:** An inline instruction block inserted before each Task() spawn in a GSD workflow file. Instructs Claude to read `wizard-state.json` toolkit.by_stage, filter for the relevant stage, build a `<capabilities>` XML block, and append it to the Task() prompt.

**When to use:** Before every Task()/Agent() spawn that targets a stage-mapped subagent.

**Example (plan-phase.md, before gsd-phase-researcher spawn):**
```markdown
### Build Capability Pointers (before spawning researcher)

If `.claude/wizard-state.json` exists and `toolkit.by_stage` is non-empty:

1. Read `toolkit.by_stage.research` from wizard-state.json
2. For each tool name in the array, use the one-liner from the agent/skill name
   (use the `description` field if you have it; otherwise use the tool name as-is)
3. Build the following block:

```
<capabilities>
Query these before investigating unknowns:
- {tool-name} — {one-liner description}
- {tool-name} (configured — availability may vary) — {one-liner for MCP}
</capabilities>
```

4. Append this block to the research_prompt, after `<files_to_read>` and
   before `<output>` (or `<success_criteria>` if present)
5. If wizard-state.json is missing or toolkit is empty (`{}`), skip — no block appended
```

### Pattern 2: Confirmation Step in wizard.md (Step 2.5)

**What:** A new decision block inserted in wizard.md immediately after Step 2 (Read wizard-state.json), before any branch executes. Classifies all tools in the relevant stage's by_stage array as known-safe or unknown, and either proceeds silently or presents a batched AskUserQuestion.

**When to use:** Once per wizard invocation, the first time a spawn-triggering action is about to execute.

**Example:**
```markdown
## Step 2.5: Classify Toolkit for Confirmation

After Step 2, when the user selects an action that will trigger a Task()/Agent() spawn:

1. Read `toolkit.by_stage` from wizard-state.json (already in context from Step 2)
2. For the relevant stage, split tool names into two buckets:
   - KNOWN_SAFE: any name in the allowlist (see below)
   - UNKNOWN: everything else
3. If UNKNOWN is empty: proceed without confirmation
4. If UNKNOWN is non-empty AND user has not already confirmed in this invocation:
   Present AskUserQuestion:
   - header: "Unknown tools discovered"
   - question: "These tools were discovered in your toolkit but are not part of the
     Keystone/GSD standard set. Include them in the capability hints sent to subagents?"
   - options:
     - "Allow all" — inject known-safe + unknown tools, remember choice this invocation
     - "Skip unknown tools" — inject only known-safe tools, remember choice this invocation
     - "Cancel" — do not execute the selected action
5. Store the user's choice as a local variable (`TOOLS_CONFIRMED = true|skip|cancel`)
   so repeat spawns within the same invocation use the same answer

**KNOWN_SAFE allowlist:**
gsd-executor, gsd-phase-researcher, gsd-planner, gsd-plan-checker, gsd-verifier,
gsd-roadmapper, gsd-codebase-mapper, gsd-debugger, gsd-nyquist-auditor,
gsd-project-researcher, gsd-research-synthesizer,
bmad-gsd-orchestrator, context-health-monitor, doc-shard-bridge,
phase-gate-validator, project-setup-wizard, stack-update-watcher,
context7, deepwiki, open-source-agent, it-infra-agent, godot-dev-agent,
admin-docs-agent
```

### Pattern 3: Capability Block Format

**What:** The exact `<capabilities>` XML block appended to Task() prompts.

**Format per stage:**

```xml
<capabilities>
Query these before investigating unknowns:
- context7 (configured — availability may vary) — Library docs, API references, current versions
- gsd-phase-researcher — Researches phase implementation; produces RESEARCH.md
- gsd-codebase-mapper — Maps project structure for targeted investigation
</capabilities>
```

**Stage preambles (locked to stage):**
- `research`: "Query these before investigating unknowns:"
- `planning`: "Reference these during planning if relevant:"
- `execution`: "Use these during implementation if relevant:"
- `review`: "Use these for validation and checking:"

### Anti-Patterns to Avoid

- **Injecting into Skill() calls:** `Skill(skill="gsd:execute-phase")` shares the caller's context window — there is no prompt to append to. Only Task()/Agent() calls receive injected blocks.
- **Loading toolkit-registry.json:** PERF-03 requires the full registry loads only on "Discover tools". Injection reads `wizard-state.json` ONLY — never toolkit-registry.json.
- **Writing to wizard-state.json from wizard.md:** wizard-detect.sh is the sole owner of wizard-state.json writes. The confirmation choice is ephemeral, held in a local variable only.
- **Showing the `<capabilities>` block to the user:** The block is appended to the Task() prompt, not displayed in the wizard's output turn. Success criterion SC #1 verifies zero user-visible leakage.
- **Prompting for confirmation on every spawn:** The confirmation fires once per invocation (tracked by local variable `TOOLS_CONFIRMED`). Re-use the stored answer for any subsequent spawns within the same wizard session.
- **Injecting tool names not in the by_stage array:** The injection reads only the by_stage array for the relevant stage — it does not enumerate all toolkit entries. Stage filtering is already done by Phase 12's toolkit-discovery.sh.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tool description lookup | Script that reads agent YAML frontmatter at spawn time | Use the tool name as-is; description is optional enrichment | toolkit-discovery.sh already extracted descriptions to toolkit-registry.json; but injection only needs the name for the compact block. Adding a live description lookup at spawn time creates latency and breaks PERF-03. |
| Persistent confirmation state | New field in wizard-state.json | Local variable in wizard.md session | wizard-state.json is overwritten on next wizard run — it can't store session-ephemeral flags. The variable lives only in the current wizard.md execution context. |
| Token counting | Custom tokenizer script | Estimate: `<capabilities>` with 6 pointers at 10 tokens each = ~80 tokens. Verify with `wc -w` as proxy. | Exact token counting is not feasible in bash; word count is a good-enough proxy for the ~200 token budget check (SC #2). |
| Stage detection | Re-computing which stage a subagent belongs to | Hardcoded mapping table in each workflow | The mapping is stable (6 entries defined in CONTEXT.md). Hardcoding is consistent with Phase 12's approach for Keystone agents. |

**Key insight:** The entire phase is markdown editing. No new scripts, no new data structures, no new APIs. All infrastructure was built in Phases 12 and 13.

## Common Pitfalls

### Pitfall 1: Agent() vs Task() in wizard.md
**What goes wrong:** wizard.md uses the `Agent` tool for context-health-monitor and phase-gate-validator spawns (not Task). The injection step must account for this — Agent() prompts also need the capabilities block.
**Why it happens:** Agent() and Task() are different tools in wizard.md's YAML frontmatter. The prompt structure for Agent() is a simple inline string, not a structured prompt object like Task(). The `<capabilities>` block can still be appended to the Agent() prompt string.
**How to avoid:** In wizard.md, the injection instruction must explicitly say "append to both Task() and Agent() prompts." Agent() calls appear at lines 83-85 and 163-165 of the current wizard.md (health check and validate phase options).
**Warning signs:** SC #1 failing — if capabilities block appears in wizard output, the Agent() prompt was rendered instead of consumed.

### Pitfall 2: wizard.md reads wizard-state.json ONCE in Step 2
**What goes wrong:** The by_stage data is already in context after Step 2. There is no need to re-read wizard-state.json before each spawn. Re-reading wastes tokens and adds a tool call.
**Why it happens:** Each spawn step in a GSD workflow re-reads wizard-state.json as a matter of habit.
**How to avoid:** In wizard.md, the injection step reads `toolkit.by_stage` from already-loaded JSON (Step 2 data). In GSD workflows (plan-phase.md, execute-phase.md), wizard-state.json is NOT already loaded — a single read at the start of injection is needed, but it should be done once per workflow, not per spawn.
**Warning signs:** Multiple `Read .claude/wizard-state.json` tool calls within a single workflow execution.

### Pitfall 3: Empty toolkit or missing by_stage key
**What goes wrong:** On a system with no discovered tools (first install, or toolkit-discovery.sh absent), `toolkit` is `{}` and `by_stage` does not exist. Attempting to access `toolkit.by_stage.research` throws a key error.
**Why it happens:** The graceful-skip path was not implemented; the injection step assumes by_stage always exists.
**How to avoid:** Every injection step must check `toolkit != {}` and `toolkit.by_stage` exists before building the block. If either is absent, skip silently — no capabilities block is appended.
**Warning signs:** Errors in wizard output, or spawned agent receiving malformed prompt with `undefined` in the capabilities section.

### Pitfall 4: GSD workflow files are at ~/.claude/get-shit-done/workflows/
**What goes wrong:** Editing the wrong copy. The GSD workflow files live globally at `~/.claude/get-shit-done/workflows/`. The wizard skill files live locally at `skills/` (plus a global copy at `~/.claude/skills/`). Since the local and global copies are in sync (verified: diff returns empty), editing the local `skills/` copy is canonical — Phase 16 syncs to global.
**Why it happens:** Confusion about the two-copy structure for skills vs the single-copy structure for GSD workflows.
**How to avoid:** GSD workflows (`plan-phase.md`, `execute-phase.md`, `research-phase.md`) are at `~/.claude/get-shit-done/workflows/` — edit there. Wizard skills (`wizard.md`, `wizard-backing-agent.md`) are in `skills/` (project local) — edit there. Phase 16 handles global sync.
**Warning signs:** Edits to `skills/` not appearing when GSD workflows run, or vice versa.

### Pitfall 5: Confirmation loop in auto-advance mode
**What goes wrong:** In auto-advance (`--auto` flag or `AUTO_CFG=true`), plan-phase.md and execute-phase.md chain without user interaction. The confirmation prompt would block the chain if unknown tools are present.
**Why it happens:** The confirmation is defined in wizard.md, but GSD workflows also spawn subagents independently (not through wizard.md). The confirmation logic in GSD workflows has no wizard context.
**How to avoid:** Confirmation UX lives ONLY in wizard.md. GSD workflows (plan-phase.md, execute-phase.md, research-phase.md) always inject without confirmation — they are already trusted orchestration layers, not user-facing wizards. The confirmation step is a wizard.md-only concern. CONTEXT.md confirms: "Timing: Before first Task()/Agent() spawn" — this refers to wizard spawns specifically.
**Warning signs:** GSD workflows blocking mid-chain waiting for user input.

### Pitfall 6: SC #2 token budget verification
**What goes wrong:** Planner adds per-pointer descriptive text, pushes token count past ~200.
**Why it happens:** Over-engineering the `<capabilities>` block to add full descriptions instead of just names.
**How to avoid:** The format is `- name — one-liner` where one-liner is the agent's description field (typically 10-15 words). Word count: 6 pointers × ~12 words = ~72 words ≈ 90 tokens. Total with wrapper tags: ~100-120 tokens — well within the ~200 token budget. Verify with `wc -w` on the generated block.
**Warning signs:** Any pointer line exceeding 15 words; any capability block with more than 8 entries.

### Pitfall 7: context-health-monitor stage mapping
**What goes wrong:** context-health-monitor is mapped to `by_stage.review` in CONTEXT.md. But when wizard spawns it via Agent() for "Check drift", it receives `by_stage.review` pointers — not `by_stage.research`. This is correct per the mapping table, but counter-intuitive since "drift check" is diagnostic.
**Why it happens:** Confusion between the agent's role (review/verification) and when it's invoked (mid-execution).
**How to avoid:** Trust the mapping table from CONTEXT.md. context-health-monitor is a review-stage tool. Its injection block should contain review-stage pointers from `by_stage.review`.

## Code Examples

### Example: Capability Block for Research Stage

Based on actual `by_stage.research` from this machine (verified via `bash skills/toolkit-discovery.sh`):

```
<capabilities>
Query these before investigating unknowns:
- gsd-phase-researcher — Researches how to implement a phase; produces RESEARCH.md
- project-setup-wizard — Detects setup state and outputs the exact workflow to follow
- gsd-codebase-mapper — Maps project structure for targeted investigation
- gsd-context-monitor — Monitors context health during execution
- gsd-debugger — Debugs GSD execution issues
- gsd-nyquist-auditor — Audits for Nyquist validation gaps
</capabilities>
```

Token estimate: ~6 pointers × ~12 tokens = ~72 tokens + ~20 for wrapper = ~92 tokens total. Under 200 token budget.

### Example: Injection Instruction in plan-phase.md (before gsd-phase-researcher)

This is the EXACT prose instruction to add before the Task(gsd-phase-researcher) spawn in plan-phase.md:

```markdown
### Build Researcher Capability Block

If `.claude/wizard-state.json` is accessible and contains non-empty `toolkit.by_stage.research`:

Read toolkit.by_stage.research (an array of tool names). For each name, build a pointer line:
- For known GSD/Keystone agents: use `- {name} — {description from YAML frontmatter if known, else omit description}`
- For MCP tools: suffix with `(configured — availability may vary)`

Build the capabilities block:
```
<capabilities>
Query these before investigating unknowns:
- {name} — {one-liner}
...
</capabilities>
```

Append this block to `research_prompt` after `<files_to_read>` and before `<output>`.
If wizard-state.json is absent, toolkit is `{}`, or by_stage.research is empty: skip — do not append.
```

### Example: Confirmation AskUserQuestion Format in wizard.md

```
AskUserQuestion:
  header: "New tools in toolkit"
  question: "Your toolkit includes tools outside the Keystone/GSD standard set.
             Include them in capability hints sent to subagents?
             Unknown tools: {comma-separated list of unknown names}"
  options:
    - "Allow all — include {N} unknown tool(s) this session"
    - "Skip unknown tools — Keystone/GSD tools only"
    - "Cancel — don't proceed"
```

### Example: BMAD Injection in wizard-backing-agent.md (Step 3)

The bmad-gsd-orchestrator Task() in Route B Step 3 gets planning-stage pointers:

```markdown
### Step 2.5 — Build Bridge Capability Block

If `toolkit.by_stage.planning` is non-empty (from wizard-state.json):
Build:
```
<capabilities>
Reference these during planning if relevant:
- {tool-name} — {one-liner}
</capabilities>
```
Append to the Task() prompt in Step 3.
If toolkit is empty or absent: skip — do not append.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded catalog in wizard.md | Dynamic by_stage injection from wizard-state.json | Phase 14 (this phase) | Subagents receive only stage-relevant tools instead of the full 176-agent catalog |
| No capability awareness in subagents | `<capabilities>` block in every Task() prompt | Phase 14 (this phase) | Subagents can leverage user's toolkit without manual tool invocation |
| "Discover tools" as only toolkit exposure point | Implicit injection on every spawn | Phase 14 (this phase) | Zero-friction toolkit awareness; no user action required |

**Note on current state:** As of Phase 13, `wizard-state.json` shows `"toolkit": {}` for the current machine. This is because `toolkit-discovery.sh` runs at detection time — but the cached output from `bash skills/toolkit-discovery.sh` shows actual data (176 agents, 28 skills, etc.). The empty `{}` in wizard-state.json means the by_stage arrays are not yet populated at runtime. **This is a Phase 13 integration issue to verify**: if the production wizard-state.json has `"toolkit": {}`, the injection step will always skip gracefully — which is correct fallback behavior, but means injection will be a no-op until Phase 16 global deployment runs fresh detection.

Verification: Run `bash skills/wizard-detect.sh` from the project root and read the resulting `.claude/wizard-state.json` to confirm `toolkit.by_stage` is populated.

## Open Questions

1. **wizard-state.json toolkit currently empty on this machine**
   - What we know: The live wizard-state.json has `"toolkit": {}` even though toolkit-discovery.sh produces populated output
   - What's unclear: Is this because wizard-detect.sh's toolkit discovery path is using the global `~/.claude/skills/wizard-detect.sh` (which may predate Phase 13) or the local `skills/wizard-detect.sh`?
   - Recommendation: Before any injection work, run `bash skills/wizard-detect.sh` and verify `.claude/wizard-state.json` has populated `by_stage` arrays. If not, the Phase 13 integration needs investigation (not Phase 14 scope, but impacts test validation).

2. **MCP tool descriptions at injection time**
   - What we know: toolkit-registry.json stores MCP tool names; by_stage arrays contain names only. The wizard-state.json compact summary has no MCP description field beyond the count.
   - What's unclear: When building a capabilities block for an MCP tool, what one-liner description is used? The agent only has the name.
   - Recommendation: For MCPs, use a fixed description template: `{name} (configured — availability may vary) — MCP server for {name}`. If the full description is needed, toolkit-registry.json can be consulted, but this risks PERF-03 violation. Use the template.

3. **Workflow files are at the global GSD path**
   - What we know: `~/.claude/get-shit-done/workflows/` contains plan-phase.md, execute-phase.md, research-phase.md. These are NOT in the keystone project repo — they are global GSD installation files.
   - What's unclear: Whether edits to global GSD workflow files are in scope for this project's git commits, and how testing/verification works for those edits.
   - Recommendation: Edits to `~/.claude/get-shit-done/workflows/` are global and not committed to this repo. The planner should note these as out-of-repo edits. Verification is done by running `/gsd:plan-phase` and checking the spawned researcher's prompt content (via a test fixture or by inspection).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bash test suite (existing pattern in tests/) |
| Config file | `tests/test-wizard-detect.sh` (existing example to follow) |
| Quick run command | `bash tests/test-injection.sh` |
| Full suite command | `bash tests/test-wizard-detect.sh && bash tests/test-injection.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INJ-01 | GSD Task() prompts contain `<capabilities>` block | smoke | `grep -q '<capabilities>' test output` | Wave 0 |
| INJ-02 | BMAD Task() prompt in wizard-backing-agent has `<capabilities>` | smoke | text search in wizard-backing-agent.md | Wave 0 |
| INJ-03 | Capability block ≤ ~200 tokens | manual | `wc -w sample-block.txt` (proxy) | Wave 0 |
| INJ-04 | No Skill() calls contain `<capabilities>` | automated | `grep -n 'capabilities' skills/wizard.md \| grep -v Task\|Agent` | Wave 0 |
| CONF-01 | Known-safe tools inject without prompt | manual | Invoke wizard, select "Check drift", confirm no AskUserQuestion fires for known agents | Wave 0 |
| CONF-02 | Unknown tools get one batched prompt | manual | Add a fake unknown tool name to by_stage, run wizard, verify single prompt | Wave 0 |
| CONF-03 | MCP entries use conditional language | automated | `grep 'configured — availability may vary' skills/wizard.md` | Wave 0 |
| PERF-03 | toolkit-registry.json not loaded during injection | automated | text search: `grep 'toolkit-registry' skills/wizard.md skills/wizard-backing-agent.md` (expect 0 results) | Wave 0 |

### Sampling Rate
- **Per task commit:** `grep -rn '<capabilities>' skills/ ~/.claude/get-shit-done/workflows/ 2>/dev/null | grep -c .`
- **Per wave merge:** Full text search + PERF-03 check + SC #2 word count
- **Phase gate:** All automated checks pass + manual SC #1 verification (no capability block in wizard output) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test-injection.sh` — covers INJ-01 through INJ-04 and PERF-03 via text search assertions
- [ ] Sample capability block text file for wc -w INJ-03 estimation — can be inline in test

*(Existing test infrastructure in `tests/test-wizard-detect.sh` covers wizard-detect.sh but not injection behavior.)*

## Sources

### Primary (HIGH confidence)
- Direct file reads: `skills/wizard.md`, `skills/wizard-backing-agent.md`, `~/.claude/get-shit-done/workflows/plan-phase.md`, `~/.claude/get-shit-done/workflows/execute-phase.md`, `~/.claude/get-shit-done/workflows/research-phase.md` — read in full, injection points identified
- `skills/wizard-detect.sh` lines 282-337 — toolkit discovery and JSON write pattern confirmed from Phase 13
- Live output of `bash skills/toolkit-discovery.sh` — actual by_stage format confirmed with real data
- `.planning/phases/13-state-integration/13-VERIFICATION.md` — Phase 13 completion confirmed, by_stage arrays verified

### Secondary (MEDIUM confidence)
- `.planning/phases/12-core-discovery-scanner/12-CONTEXT.md` — stage keyword arrays and trust classification approach for Keystone agents
- `.planning/phases/14-subagent-injection-confirmation-ux/14-CONTEXT.md` — all implementation decisions already locked

### Tertiary (LOW confidence)
- None — all critical claims verified from source files

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files read directly, no inference
- Architecture: HIGH — injection pattern derived from existing GSD prompt conventions (confirmed in plan-phase.md, execute-phase.md)
- Pitfalls: HIGH — all pitfalls derived from direct inspection of source files and cross-checking against CONTEXT.md constraints

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable — files change only when phases execute)
