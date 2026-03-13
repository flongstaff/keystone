# Pitfalls Research

**Domain:** Dynamic toolkit discovery and capability injection for an AI agent orchestration layer
**Researched:** 2026-03-13
**Confidence:** HIGH — derived from direct analysis of the existing codebase (wizard.md, wizard-detect.sh, wizard-backing-agent.md, 160 global agents, PROJECT.md constraints), established patterns in the Claude Code agent system, and first-principles reasoning about token-budget-constrained orchestrators

---

## Context: What This Milestone Is Adding

The v1.0 wizard (Phases 1–11) shipped with a **hardcoded catalog** in `wizard.md` (Phase 7). The catalog lists exactly 11 Keystone-authored agents, 3 skills, and 3 hooks — all statically embedded as Markdown text, duplicated across 4 menu branches in the same file. The catalog is purely display: no discovery, no capability matching, no injection into subagents.

The v1.1 milestone adds:
1. **Dynamic scanning** — discover all user-installed agents, skills, hooks, MCP servers at runtime
2. **Capability matching** — map discovered tools to workflow stages
3. **Subagent context injection** — GSD/BMAD subagents receive relevant tool references in their prompts
4. **MCP-aware recommendations** — surface configured MCP servers at appropriate workflow moments
5. **Confirmation UX** — ask before using discovered tools when intent is ambiguous
6. **Token-efficient injection** — lightweight capability pointers, not full agent prompts in context

The environment has 160 installed agents and 33 installed skills globally — numbers that make naive discovery catastrophic for the 10% context budget.

---

## Critical Pitfalls

### Pitfall 1: Discovery Output Becomes the Context Sink

**What goes wrong:** The dynamic scanner reads all 160 agents from `~/.claude/agents/`, parses their YAML frontmatter and description fields, builds a structured catalog, and passes the entire result into the wizard's context — or worse, into every subagent's Task() prompt. A conservative estimate of 100 tokens per agent description means 16,000 tokens of discovery output before any user work happens. The 10% budget (20,000 tokens in a 200k window) is already consumed.

**Why it happens:** Discovery feels like a one-time cost. Developers reason: "We run the scan once at startup, then everything benefits." This ignores that every byte of scan output that is printed to the terminal or written to a context-visible variable counts against the budget of the current context window. Discovery results must go to a file, not to context.

**How to avoid:**
- Discovery output MUST be written to a structured file (`.claude/toolkit-state.json` or similar) and NOT printed to the terminal or included in any prose response
- The wizard.md catalog display reads this file only when "Discover tools" is explicitly selected — not on every `/wizard` invocation
- Subagent injection reads ONLY the capability-matched slice for that specific subagent's stage (e.g., a research subagent gets 3-5 relevant tool references, not all 160)
- The discovery scan runs as a background bash block in wizard-detect.sh, not as an agent invocation or LLM call

**Warning signs:**
- Discovery scan output appears in the terminal status box
- wizard-state.json size grows from ~700 bytes to >5KB
- wizard-detect.sh execution time increases noticeably (>2 seconds)
- The wizard starts printing "Scanning your toolkit..." before the status box
- Any LLM turn is used to summarize or process discovery output (this means discovery output is in context)

**Phase to address:** Discovery scanning design (first phase). The file format for toolkit-state.json must be frozen before any discovery logic is written. The budget constraint — zero context tokens for discovery output that isn't explicitly requested — must be a pass/fail criterion from day one.

---

### Pitfall 2: Injecting Capability Pointers Into Every Subagent Task() Prompt

**What goes wrong:** The wizard identifies 5 relevant tools for a "research" stage and injects them into every GSD subagent's Task() prompt — the researcher, the planner, and the executor all receive the same capability block. The researcher benefits; the executor did not need it and the injection bloats its prompt. More critically, GSD subagents (gsd-researcher, gsd-planner, gsd-executor) have their own established prompt formats with `<objective>`, `<files_to_read>`, and `<context>` blocks. Appending capability injection after these blocks may cause the subagent to interpret the injection as additional context files to read rather than capability hints.

**Why it happens:** "If tool awareness is good, more is better" reasoning. Also, the wizard cannot easily know whether a subagent actually used the injected capabilities, so developers inject broadly to ensure coverage.

**How to avoid:**
- Inject only at stage transitions where capability use is most likely: research subagents get search/fetch tools, execution subagents get code-generation agents, review subagents get validation tools
- Capability injection must use a fixed-format, minimal syntax: `<!-- available tools: context7, brave-search -->` as an HTML comment block is not processed as instructions; a labeled section `## Available MCP Tools\n- context7: ...` adds ~100 tokens maximum
- Test each injection site: does the subagent's behavior change when injection is removed? If not, remove the injection — it is noise
- Never inject capability pointers for tools the subagent cannot use (e.g., injecting MCP server references into an agent whose YAML `tools:` list does not include the corresponding MCP tool)

**Warning signs:**
- Task() prompt length for GSD subagents increases by more than 20% after injection is added
- Subagents start asking users about tools mentioned in the injection that are not relevant to the current phase
- A subagent's first tool call is to verify an injected capability (exploration overhead, not work)
- Integration tests show subagent behavior changing unexpectedly after injection is added

**Phase to address:** Injection design (before implementation). The injection format and placement within existing Task() prompt templates must be specified before any code is written. Retrofitting injection into existing prompt templates after the fact requires re-testing every subagent path.

---

### Pitfall 3: MCP Discovery Returns Stale or Environment-Specific Results

**What goes wrong:** The discovery scan reads `~/.claude/settings.json` (or `mcp.json`) to enumerate MCP servers. It finds `context7`, `brave-search`, `deepwiki`, `firecrawl`, `github`. The wizard begins recommending "use Context7 for library lookups" in research subagent injections. But the user is working in a different machine where the Brave Search MCP is not configured. Or the MCP server is configured but the process is not running. Or the MCP server listed in settings.json is installed but not authorized for the current project. The wizard recommends a tool that silently fails.

**Why it happens:** MCP configuration is per-environment and per-session. The settings file reflects what was installed, not what is currently available and authorized. The Claude Code MCP availability model is runtime-specific: servers must be running, and tool access must be granted for the current session. There is no reliable file-based way to verify MCP availability at wizard startup time.

**How to avoid:**
- MCP recommendations must be expressed as suggestions, not commands: "Context7 may be available for library lookups — try `mcp__context7__resolve-library-id`"
- Discovery of MCP configuration should be separated from recommendations: list what is configured, but note that availability is session-dependent
- Never inject MCP tool calls into subagent prompts as requirements; inject them as optional enhancements only
- The subagent receives: "If mcp__context7 tools are available, use them for library research" — the conditional protects against unavailability
- Add a verification step: if MCP is mentioned in discovery, the wizard should check whether the tool call namespace exists before recommending it (this can be done by attempting a cheap test call or by checking the session's active tool list if available)

**Warning signs:**
- Discovery output lists MCP servers from settings.json but has no "verified available" flag
- Subagent prompts contain unconditional MCP tool call instructions
- Users report "Context7 not found" errors after the wizard recommends Context7
- The same wizard-state.json is used across machines and the MCP section is treated as truth

**Phase to address:** MCP discovery design. MCP availability is session-scoped, not file-scoped. The data model for toolkit-state.json must distinguish between "configured" and "verified available" for MCP entries.

---

### Pitfall 4: The Hardcoded Catalog Is Removed Before Dynamic Discovery Works End-to-End

**What goes wrong:** The Phase 7 hardcoded catalog in wizard.md is accurate for Keystone-authored tools and displays correctly. During v1.1 development, the hardcoded catalog is removed (it's "dead weight" once discovery exists) and replaced with a call to read toolkit-state.json. But discovery is incomplete: toolkit-state.json doesn't yet cover hooks, MCP servers aren't yet capability-matched, and the display format isn't finalized. Users who select "Discover tools" see a partial or empty catalog, or wizard.md fails when toolkit-state.json doesn't exist (fresh install, no discovery scan run yet).

**Why it happens:** Classic "remove old before new is ready" refactor. Developers underestimate how much the hardcoded catalog implicitly provides: it's always available, requires no file I/O at display time, and is guaranteed to be accurate for the installed Keystone set.

**How to avoid:**
- Keep the hardcoded catalog operational until dynamic discovery passes all catalog parity tests (dynamic catalog must show every entry from the hardcoded catalog plus any additional discovered tools)
- The fallback order: if toolkit-state.json exists and is non-empty, display dynamic catalog; otherwise display hardcoded catalog
- Never delete the hardcoded catalog until the dynamic path is smoke-tested on a fresh install where discovery hasn't run yet
- This is a case where two implementations must coexist temporarily — plan for this in phase design, not as a surprise

**Warning signs:**
- toolkit-state.json is read in the "Discover tools" path before it is guaranteed to exist
- The hardcoded catalog section in wizard.md is deleted in the same commit that adds dynamic catalog reading
- No fallback is defined for the case where toolkit-state.json is absent or malformed
- "Discover tools" returns empty output on a fresh install

**Phase to address:** Catalog migration design. The transition from hardcoded to dynamic catalog must be treated as a data migration, not a feature swap. Define the fallback behavior before removing the hardcoded implementation.

---

### Pitfall 5: Discovery Runs on Every `/wizard` Invocation Instead of On Demand

**What goes wrong:** The dynamic scanner is added to wizard-detect.sh because it's already running at `/wizard` startup. Running 160-agent discovery on every invocation adds latency to the common case (resume GSD work) — the case where discovery output is never even shown to the user. A user who types `/wizard` fifteen times during a GSD phase execution run pays the discovery scan cost every time, even though the catalog never changes between invocations.

**Why it happens:** wizard-detect.sh is the natural integration point. It already runs filesystem operations. Adding more filesystem reads there seems low-cost. The cost is only visible when measured against user-perceived latency and against the context budget for the startup block.

**How to avoid:**
- Discovery must be **lazily triggered**: run only when the user selects "Discover tools" or when a capability is needed by an injection step that hasn't been satisfied yet
- If eager startup scanning is desired (e.g., for hot-path injection), run discovery asynchronously and cache results to toolkit-state.json with a TTL: if toolkit-state.json exists and was written within the last 24 hours, skip rescan
- The standard wizard startup path (detect state, write wizard-state.json, show status box) must not change in character or latency
- Measure: time the existing wizard-detect.sh execution; any change to that script for discovery purposes must not increase execution time by more than 20%

**Warning signs:**
- The wizard-detect.sh script gains a loop over `~/.claude/agents/`
- The wizard status box takes noticeably longer to appear
- wizard-state.json grows to include a `toolkit` key with 160 entries on every cold start
- A comment in wizard-detect.sh says "this runs on every invocation" for the discovery section

**Phase to address:** Discovery trigger design (first phase of v1.1). The trigger model (eager vs. lazy, TTL-cached vs. session-fresh) must be decided before any scanner code is written. Default to lazy/on-demand.

---

### Pitfall 6: Capability Matching Classifies Agents by Name Pattern Instead of YAML Description

**What goes wrong:** The capability matcher categorizes agents by name: anything with "research" in the name goes to the research stage, anything with "code" to the execution stage. This works for obvious cases but misclassifies 60% of the 160-agent ecosystem: `api-debugger` is not for planning stages, but its name pattern doesn't help; `context-health-monitor` is a bridge agent used at phase transitions, but a name-based classifier assigns it to "monitoring" generically; `accounts-payable-agent` is a domain agent that is never relevant to any GSD stage. The user sees irrelevant recommendations at every stage.

**Why it happens:** Name-based classification is easy to implement and seems reasonable for a small, well-named agent set. It breaks at scale and with agent naming conventions that don't follow a predictable pattern.

**How to avoid:**
- Stage matching must use the agent YAML `description` field as the primary signal — it contains explicit trigger phrases and use cases
- Use keyword extraction from the `description` field mapped to stage buckets: `research|search|fetch|lookup|docs` → research, `plan|design|architect|structure` → planning, `execute|implement|build|code|test` → execution, `review|validate|check|verify|audit` → review
- Build a capability tag system as a secondary signal: if the `description` field contains "Use WHEN: [condition]" (which many Keystone agents already use), extract the condition for matching
- The capability matcher must handle the "not relevant to any stage" case explicitly — most of the 160 agents are domain-specific or tool-specific and should be surfaced only in the "all agents" catalog view, not in stage injection

**Warning signs:**
- The stage-matching logic is a name-based filter rather than a description-based classifier
- More than 10 agents are injected into a single subagent's prompt as "relevant to this stage"
- Domain-specific agents (blockchain-security-auditor, corporate-training-designer) appear in GSD execution stage injection recommendations
- The capability matcher returns 0 matches for a well-known stage (research) because no agents have "research" in their name

**Phase to address:** Capability matching algorithm design. This must be specified as a classification scheme before implementation — keyword sets, fallback behavior, maximum injection count per stage.

---

### Pitfall 7: Confirmation UX Becomes Another Wizard That Asks Too Many Questions

**What goes wrong:** The user selects "Bridge to GSD." The wizard detects that `context7` and `brave-search` MCPs are configured. It asks: "I see Context7 is available — use it for library research during bridge? [y/n]". User confirms. Then: "I see Brave Search is available — use it for documentation lookup? [y/n]". User confirms. Then: "I see deepwiki is configured — use it for upstream repo analysis? [y/n]". The user answered 3 capability questions before the bridge even started. This is a confirmation anti-pattern that makes the "Discover tools" feature more friction than value.

**Why it happens:** The "user confirmation when intent is ambiguous" requirement (from PROJECT.md) is interpreted as "ask the user about every discovered capability." This maximizes coverage but minimizes flow. The intent of the requirement is to prevent the wizard from using tools the user doesn't know about — not to build an interactive capability configurator.

**How to avoid:**
- Default to using discovered capabilities without confirmation for well-understood tools (MCP servers listed in the user's own settings.json are by definition authorized)
- Require confirmation only when capability use has side effects (e.g., "This will use Brave Search to fetch external URLs — is that acceptable in this context?") or when the tool is newly discovered (not seen in a previous session's toolkit-state.json)
- The "user confirmation" requirement is satisfied by showing what tools are being used in the status box, not by pre-flight questions for every tool
- Cap confirmation questions at one per `/wizard` invocation: if more than one new tool is discovered, batch them: "New tools detected: context7, brave-search. Use these where relevant? [y/n]"

**Warning signs:**
- More than one AskUserQuestion is called for capability confirmation before the user's primary action starts
- The confirmation flow has more than 2 branches
- Capability confirmation questions appear even when the user didn't select "Discover tools"
- The same tool is confirmed more than once across different wizard invocations (no memory of prior confirmation)

**Phase to address:** Confirmation UX design. Specify the exact confirmation trigger conditions before the UX is built. Pre-emptively constrain the number of confirmation questions per invocation to at most one batch question.

---

### Pitfall 8: Subagent Injection Breaks Existing Task() Prompt Contracts

**What goes wrong:** The GSD subagents (gsd-researcher, gsd-planner, gsd-executor) receive their prompts from GSD's own `execute-phase.md` workflow, which uses a specific prompt structure with `<objective>`, `<files_to_read>`, `<phase_context>` blocks in a specific order. The wizard's capability injection appends a `## Available Tools` section after `<phase_context>`. The subagent's instructions say "follow the steps in <objective>" — but the subagent now sees `## Available Tools` after its listed instructions and interprets the tool references as additional objectives rather than hints. The subagent starts reading agent files that were mentioned in the injection before doing the actual phase work.

**Why it happens:** GSD's internal prompt format is not documented as a public contract. The wizard wraps GSD without reading the internal prompt templates. Injection is appended without knowing whether the subagent's instructions say to process all content or only specific tagged sections.

**How to avoid:**
- Read the GSD subagent prompt templates (in `~/.claude/get-shit-done/workflows/`) before designing any injection format
- If injection must go into an existing Task() prompt, use a format that the subagent's instructions explicitly say to ignore or treat as hints: XML comments `<!-- wizard-hint: ... -->` or a clearly-labeled final section that the agent's instructions don't reference
- The safer approach: inject capability hints into the wizard's own Task() invocation description (the `description` field), not the `prompt` field — this keeps the prompt contract intact while still providing context to the subagent
- Test injection by checking whether the subagent's behavior changes when injection is removed: if it changes, the injection is being processed as instructions; if it doesn't change, the injection is ignored (either outcome is a signal for adjustment)
- Add a rule to the injection design: "Never inject content that matches a semantic structure the subagent's instructions already address" — tool-call names look like instructions, not hints, so they must be clearly labeled as optional enhancements

**Warning signs:**
- A GSD subagent's first tool call after injection is Read or Glob on an agent file mentioned in the injection
- The subagent produces output that references injected tools in its summary even when the task didn't require those tools
- GSD phase execution takes more turns after injection is added (the subagent is exploring the injected tools)
- Removing injection causes subagent output to revert to its pre-injection behavior (confirms injection was being processed)

**Phase to address:** Injection format design. Read GSD's internal subagent prompt templates before specifying any injection format. This requires access to `~/.claude/get-shit-done/workflows/` and the specific Task() invocation syntax used by GSD commands.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep discovery output in wizard-state.json (same file as detection state) | Single file to read/write | wizard-state.json grows with every new agent installed; detection phase reads full file every startup even when catalog not needed | Never — separate toolkit-state.json from wizard-state.json from the start |
| Hardcode the capability stage mapping (research → context7, execution → code-reviewer) | Simple, fast to implement | Breaks when user installs new tools; catalog diverges from actual capabilities | Only as a temporary scaffold while the classification algorithm is designed |
| Embed full agent descriptions in injected prompts | Subagent has full context about each tool | Each injection adds hundreds of tokens; multiplied by all subagent invocations, this violates the 10% budget | Never — inject name + one-line trigger only |
| Scan only the Keystone agent subdirectory instead of all `~/.claude/agents/` | Avoids the 160-agent scale problem | Defeats the "dynamic discovery of ALL user-installed agents" requirement | Only in Phase 1 of v1.1 as a scope-limited MVP |
| Use the same TTL-cached toolkit-state.json across machines (via git) | Users share capability awareness | MCP availability is per-machine; cached state will be wrong on new machines | Never — toolkit-state.json must be gitignored |

---

## Integration Gotchas

Common mistakes when connecting dynamic discovery to existing wizard components.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| wizard-detect.sh | Adding discovery loop inside detection script, growing startup time | Call discovery as a separate bash block triggered only when toolkit-state.json is absent or stale |
| wizard.md "Discover tools" option | Reading toolkit-state.json that doesn't yet exist on fresh install | Check file existence before reading; fall back to hardcoded catalog if absent |
| GSD Task() prompt injection | Appending capability hints after the phase_context block | Read GSD prompt template structure first; inject only in clearly non-instructional positions |
| MCP settings.json | Treating configured MCPs as available MCPs | Add "verified" flag; only recommend MCPs that were successfully invoked in the current session |
| wizard-state.json schema | Adding a `toolkit` key to the existing wizard-state.json | Create separate toolkit-state.json; wizard-state.json is detection state, toolkit-state.json is capability state |
| Active domain agent marking | Reading project_type from wizard-state.json (detection state) for dynamic catalog | This is correct — project_type comes from detection, not discovery. The integration between these two state files must be explicit |
| Stack-update-watcher | Newly discovered agents are not covered by the update watcher's known-agents list | When discovery finds a new agent version, check whether stack-update-watcher covers it; if not, note in catalog |

---

## Performance Traps

Patterns that work at small scale but fail as the agent ecosystem grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| O(N) agent scan at every startup | wizard-detect.sh execution time grows linearly with installed agents | TTL-cached discovery; skip rescan if toolkit-state.json is less than 24 hours old | At 160 agents, already adds measurable latency; at 500+ agents, startup is noticeably slow |
| Full description text in toolkit-state.json | File size grows to 100KB+; reading it for display consumes context budget | Store only name, category, one-liner, and activation phrase — not full YAML body | Beyond 50 agents with full descriptions |
| LLM-based capability classification | Each classification call costs tokens and latency | Use deterministic keyword matching from description fields, not LLM classification | Every agent — LLM classification should never be used for this |
| Per-subagent injection with full capability list | Context budget consumed by injection across many subagent spawns | Filter to ≤5 most-relevant capabilities per subagent per stage | After 3+ subagent spawns in a single GSD execution flow |
| MCP availability check via test call | Each test call adds a round-trip; multiple MCPs = multiple round-trips at startup | Check availability lazily (first time the tool is recommended) or trust user's settings.json at startup | When 5+ MCPs are configured — test calls add 5+ seconds to startup |

---

## Security Mistakes

Domain-specific security issues for dynamic discovery in an AI orchestration layer.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Reading agent files from arbitrary discovered paths and injecting file content into subagent prompts | A malicious agent file could inject instructions into subagent prompts via the discovery pipeline (prompt injection through the file system) | Discovery reads only YAML frontmatter (name, description, tools fields) — never reads or injects the agent body; the body is system prompt content and must not be passed to other agents |
| Writing MCP server credentials discovered in settings.json to toolkit-state.json | toolkit-state.json is in `.claude/` which may be committed; credentials would leak | Discovery reads only MCP server name and tool namespace — never auth tokens, API keys, or connection strings |
| Using toolkit-state.json paths as file-read targets in subagents | If an attacker can write to toolkit-state.json, they can redirect subagent file reads | Subagents read hardcoded paths plus phase-specific files — never dynamic paths from state files |

---

## UX Pitfalls

Common user experience mistakes specific to capability injection and dynamic discovery.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing all 160 agents in the catalog without grouping | Users are overwhelmed; catalog is useless as a discovery tool | Group by relevance to current scenario first (relevant to current stage), then by category (entry/bridge/domain/maintenance/third-party) |
| Marking an MCP tool "(available)" when it's configured but not usable in current context | User tries the tool, it fails; trust in wizard is damaged | Only mark tools "(available)" if verified usable in current session; otherwise mark "(configured — availability may vary)" |
| Showing capability injection to the user as a status update | Breaks the wizard's "detect → menu → action" flow; users think something is happening when the wizard is just assembling context | Injection is invisible — it happens in the Task() prompt construction, not in user-visible output |
| Removing the "(active)" domain agent marking when catalog becomes dynamic | Users relied on this visual cue to know which domain agent matched their project | The active-marking logic (from wizard.md project_type matching) must be preserved exactly as-is when the catalog becomes dynamic |
| Adding a "configure capabilities" menu item | Users are not managing an orchestration system — they are doing project work | No configuration menu. Discovery is automatic; confirmation is batched at most once per session |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Dynamic catalog populated:** Verify toolkit-state.json exists AND contains the correct count of agents (not just "discovery ran") — run discovery on a fresh clone and confirm the Keystone-authored agents appear in the dynamic catalog
- [ ] **Hardcoded catalog parity:** Every entry in the Phase 7 hardcoded catalog must appear in the dynamic catalog — diff the two lists explicitly before removing the hardcoded fallback
- [ ] **10% budget enforced:** Measure the wizard's context usage from startup through "Discover tools" selection and display — must stay under 20k tokens for a project with 160 installed agents
- [ ] **Injection is invisible:** Confirm that capability injection does NOT produce any user-visible output — run a GSD phase execution with injection enabled and verify the user sees no mention of injected tool names in the wizard UI
- [ ] **MCP availability is conditional:** Verify that all MCP references in injected content use conditional language ("if available") rather than imperative language ("use context7 for...") — search injected prompts for unconditional MCP tool call patterns
- [ ] **Fresh install works:** Run "Discover tools" on a project where wizard-detect.sh has never run — confirm the hardcoded fallback displays correctly and no file-not-found errors occur
- [ ] **toolkit-state.json is gitignored:** Confirm toolkit-state.json is listed in `.gitignore` — it contains machine-specific MCP state that must not be committed

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Discovery output bloats wizard-state.json causing budget overrun | MEDIUM | Extract toolkit key into separate toolkit-state.json; add explicit `del toolkit` migration to wizard-detect.sh for old wizard-state.json files |
| Subagent injection breaks GSD Task() prompt contract | HIGH | Revert injection to "description field only" (safe, tested, non-instructional); re-read GSD internal prompt templates before redesigning injection format |
| Hardcoded catalog removed before dynamic catalog works | LOW-MEDIUM | Revert wizard.md to include hardcoded catalog as fallback; leave dynamic catalog as primary with fallback chain |
| MCP recommendations cause tool-not-found errors | LOW | Switch all MCP recommendations to conditional language ("if available"); add availability check before surfacing recommendation |
| Capability classification mismatches cause irrelevant injections | MEDIUM | Reduce injection scope to zero (no injection) while reclassification algorithm is redesigned; users are unaffected since injection is invisible |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Discovery output becomes context sink (Pitfall 1) | Discovery scanner design (first v1.1 phase) | Measure wizard startup token usage before and after scanner addition; must be unchanged |
| Injection bloats subagent Task() prompts (Pitfall 2) | Injection format design (before any subagent prompt changes) | Compare GSD subagent turn count and context usage with and without injection; must not increase by >10% |
| MCP discovery returns stale results (Pitfall 3) | MCP discovery design | Verify wizard works identically on machines where listed MCPs are not running |
| Hardcoded catalog removed before dynamic works (Pitfall 4) | Catalog migration design | Run parity test (hardcoded list == dynamic list subset) before removing hardcoded catalog |
| Discovery runs on every invocation (Pitfall 5) | Discovery trigger design (first v1.1 phase) | Add execution timing to wizard-detect.sh; confirm discovery section is skipped when toolkit-state.json is recent |
| Capability matching uses name patterns (Pitfall 6) | Capability matching algorithm design | Test classification against all 160 agents; confirm domain-specific agents (blockchain, training, etc.) are not injected into GSD stages |
| Confirmation UX asks too many questions (Pitfall 7) | Confirmation UX design | Count AskUserQuestion calls per /wizard invocation including capability confirmation; must be ≤1 batch question |
| Injection breaks GSD prompt contracts (Pitfall 8) | Read GSD internal templates before injection design | Run a full GSD phase execution with injection; confirm subagent's first tool call is NOT a Read of an injected agent file |

---

## Token-Budget-Specific Notes for Claude Code Environments

The 10% context budget constraint (< 20k tokens in a 200k window) has implications specific to the Claude Code environment that are not present in standard API orchestration:

**Status box output counts against context.** Everything printed to the terminal by the wizard's detection phase is included in the context window. A discovery scanner that prints "Found 160 agents, 33 skills, 5 MCP servers" is not free — those characters are in context. All discovery output must be silent (write to file, print nothing).

**The Skill() invocation mechanism loads the SKILL.md into context.** When wizard.md calls `Skill('wizard-backing-agent')`, the SKILL.md content of wizard-backing-agent is loaded into the wizard's context. If the backing agent's SKILL.md grows to include capability injection blocks, those blocks are in context on every backing agent invocation even when the injected capabilities are not used. Keep skill files under 500 lines total; keep injected content in separate files loaded only when the specific route is taken.

**Agent files read via the Agent tool do not inherit the caller's context budget.** When wizard.md uses the Agent tool (for context-health-monitor), that agent gets its own context window. This means routing through an Agent call is budget-safe for expensive operations. But: the Agent's output is returned to and displayed in wizard.md's context. A verbose agent response that includes a 200-line catalog will consume those 200 lines of wizard's budget when the response is displayed.

**Task() spawned subagents have fresh 200k windows but their prompts count against the orchestrator's context.** The wizard's Task() call constructs a prompt and passes it to gsd-executor. The prompt text itself is in wizard.md's context as the Task() tool call output. A 2,000-token injection in the Task() prompt means 2,000 tokens added to wizard's context, not just executor's. At 10 Task() calls per GSD phase, this is 20,000 tokens — the entire budget — used for prompt construction overhead.

---

## Sources

- Direct analysis: `/Users/flong/Developer/keystone/skills/wizard.md` — Phase 7 hardcoded catalog implementation, menu structure, Discover tools option — HIGH confidence
- Direct analysis: `/Users/flong/Developer/keystone/skills/wizard-detect.sh` — current startup scan scope, JSON write format, execution budget — HIGH confidence
- Direct analysis: `/Users/flong/Developer/keystone/skills/wizard-backing-agent.md` — current Task() invocation pattern, prompt format — HIGH confidence
- Direct analysis: `/Users/flong/Developer/keystone/.planning/PROJECT.md` — v1.1 requirements, active milestone constraints — HIGH confidence
- Direct observation: `ls ~/.claude/agents/` — 160 installed agents at current state — HIGH confidence (this is the discovery scale)
- Direct observation: `ls ~/.claude/skills/` — 33 installed skills at current state — HIGH confidence
- Direct analysis: `/Users/flong/Developer/keystone/.planning/research/PITFALLS.md` (v1.0) — existing pitfall catalog, context budget pitfalls, wizard overhead patterns — HIGH confidence
- First-principles reasoning: Claude Code context model (skills inject SKILL.md into context at spawn; terminal output is in context; Task() prompts count against orchestrator budget) — MEDIUM confidence (training data; verify against current Claude Code documentation before implementing)

---
*Pitfalls research for: Dynamic toolkit discovery and capability injection for AI agent orchestration*
*Researched: 2026-03-13*
*Supersedes: v1.0 PITFALLS.md (retained for historical reference — new sections added below existing content)*
