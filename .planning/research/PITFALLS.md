# Domain Pitfalls

**Domain:** Wizard/Orchestrator layer over AI coding workflow tools (BMAD + GSD)
**Researched:** 2026-03-11
**Confidence:** HIGH — derived from direct analysis of existing codebase, documented
concerns, and established patterns in the Claude Code agent ecosystem

---

## Critical Pitfalls

Mistakes that cause rewrites, requirement loss, or make the wizard worse than
the problem it solves.

---

### Pitfall 1: The Orchestrator Costs More Context Than It Saves

**What goes wrong:** The wizard itself burns significant context loading its own
detection logic, routing decisions, menu output, and state summaries — before
the user has done any actual work. A wizard that consumes 15% of context window
on plumbing has failed its core value proposition. The project constraint is
clear: "Wizard overhead must be < 10% of context window."

**Why it happens:** Developers treat the wizard like a UI application and pack it
with rich formatting, verbose explanations, re-reads of multiple state files, and
multi-turn conversations with the user before handing off. Each feature feels
small; together they create a context sink.

**Consequences:** Users get worse outcomes than just running `/gsd:discuss-phase`
directly. The wizard becomes an anti-pattern in the ecosystem it was meant to fix.
Power users bypass it, making it a dead artifact.

**Warning signs:**
- Detection bash block grows beyond 30 lines
- Router skill reads more than 3 files before outputting the routing decision
- Wizard turn count exceeds 5 before delegating to a downstream agent
- User says "this is slower than just running the command myself"
- Context health monitor shows >10% usage before any phase work

**Prevention:**
- Cap the router skill's file reads to: `config.json` + one state marker
- Do detection in a single bash block, not across multiple tool calls
- Route immediately after detection — one confirmation turn at most, then delegate
- Lazy-load phase context (don't read ROADMAP.md unless user asks for it)
- Test: time-to-handoff should be under 3 turns in any scenario

**Phase mapping:** Router skill build (Phase 1). Must be validated before wizard
UI layer is built on top of it.

---

### Pitfall 2: Requirements Silently Drop at the BMAD→GSD Handoff

**What goes wrong:** The wizard routes the user through the handoff, BMAD
acceptance criteria exist in story files, GSD phases get created — but the
mapping from BMAD criteria to GSD phase acceptance tests is lossy or implicit.
By Phase 3 of execution, a criterion like "system must support concurrent users"
was never loaded into the phase context and gets silently omitted from UAT.

**Why it happens:** The existing `bmad-gsd-orchestrator` creates the `.planning/`
structure from PRD epics, but there is no explicit traceability assertion: "does
every BMAD acceptance criterion appear, verbatim or paraphrased, in at least one
GSD phase context file?" The wizard wraps this orchestrator without fixing the
traceability gap.

**Consequences:** User completes all GSD phases, runs final QA, discovers features
that were in the PRD were never implemented. Late-stage discovery, expensive to
fix, loss of trust in the workflow.

**Warning signs:**
- Phase context files reference epics but not story-level acceptance criteria
- doc-shard-bridge produces shards with "Acceptance Criteria: [see PRD]" instead
  of inlining the criteria
- UAT files pass without referencing specific BMAD story criteria
- `bmad-outputs/STATUS.md` shows phases done but stories still in "In Progress"

**Prevention:**
- The backing agent must include a traceability check: for each BMAD story
  acceptance criterion, assert it appears in a phase context file
- Use a format that makes this machine-checkable: e.g., a `## Acceptance Criteria
  (from BMAD story N)` header with verbatim criteria per phase context file
- Wizard's completion summary must show requirement coverage count, not just
  "phases created: N"
- Phase gate validator Gate 1 already checks UAT against criteria — but only if
  criteria were loaded into the phase context in the first place

**Phase mapping:** Backing agent design (Phase 2). Traceability schema must be
defined before first phase context files are written.

---

### Pitfall 3: State Detection Produces Contradictory or Ambiguous Results

**What goes wrong:** The smart router detects both `_bmad/` (BMAD installed) and
`.planning/ROADMAP.md` (GSD initialized), but the ROADMAP.md was created from
scratch without BMAD docs — so it's "both" in terms of markers but "GSD-only" in
terms of actual state. Router shows STATE D (Full Stack) when the user should be
in STATE B (GSD Only). User follows wrong workflow.

**Why it happens:** Detection logic uses file-system markers as proxies for true
state. Markers can exist out-of-sync: leftover `.planning/` from a prior project,
BMAD installed globally but no docs generated yet, `_bmad/` directory created
empty by a failed install. The existing `project-setup-wizard` already has this
problem (detection Phase 1 runs many checks but doesn't cross-validate them).

**Consequences:** Wrong workflow delivered. User runs BMAD handoff commands on a
project that has no BMAD docs. Agent fails with confusing error rather than a
clear "this project wasn't BMAD-planned."

**Warning signs:**
- BMAD_DIR=true but BMAD_PRD=false and BMAD_ARCH=false simultaneously
- GSD_STATE=true but `.planning/config.json` has no phases array
- STATE changes from one wizard invocation to the next on the same project
  without user doing anything

**Prevention:**
- Cross-validate markers: BMAD "present" requires both `_bmad/` directory AND
  at least one of `docs/prd-*.md` or `docs/architecture-*.md`
- GSD "initialized" requires `config.json` with a non-empty phases array,
  not just the presence of `.planning/`
- Add a STATE.AMBIGUOUS case: when markers exist but cross-validation fails,
  show what was found and ask the user to confirm intent rather than guessing
- The router skill's detection output must include the cross-validation result,
  not just raw marker presence

**Phase mapping:** Router skill build (Phase 1). Detection logic must be written
with cross-validation from the start, not as a later fix.

---

### Pitfall 4: The Wizard Becomes a Second Entry Point That Diverges From Existing Agents

**What goes wrong:** The wizard wraps `project-setup-wizard.md` and
`project-setup-advisor.md`, but over time the wizard's internal logic duplicates
and then diverges from those agents' routing logic. Now there are two detection
implementations: the existing agents and the new wizard skill. When someone
updates the existing agents to add a new scenario, the wizard skill isn't updated.

**Why it happens:** "Wrapping" is ambiguous. It can mean "call the underlying agent"
or "reimplement the same logic in a new layer." The second interpretation creates
a maintenance fork. The constraint says "wrap existing agents, don't replace" but
this is easy to violate in implementation — it feels faster to reimplement the
wizard flow inline than to delegate to an agent that then asks questions back.

**Consequences:** Two diverged state machines. Users get different recommendations
from `/wizard` vs. the existing project-setup agents. Trust in the system degrades.
Maintenance cost doubles.

**Warning signs:**
- The router skill contains a full detection bash block instead of calling
  `project-setup-wizard` or `project-setup-advisor`
- The wizard skill has its own STATE A/B/C/D logic instead of reading the existing
  agent's output
- `project-setup-wizard.md` is modified to accommodate the new wizard's needs
  (violates "don't change BMAD/GSD internals")

**Prevention:**
- The router skill must invoke `project-setup-wizard` or `project-setup-advisor`
  as its detection step — not reimplement the logic
- Any scenario not handled by those agents should be added TO those agents,
  not added to the wizard skill directly
- Write a test: running the wizard and running the underlying entry agent should
  produce identical state classifications for the same project

**Phase mapping:** Router skill design (Phase 1, pre-implementation).

---

## Moderate Pitfalls

---

### Pitfall 5: Wizard State Persistence Gets Out of Sync With GSD State

**What goes wrong:** The wizard stores its own state in `.planning/wizard-state.json`
or similar. GSD also stores state in `.planning/STATE.md` and `.planning/config.json`.
After a context reset, the wizard reads its own state file and says "you're at
Phase 3" but GSD's state files say "Phase 2 complete, Phase 3 not started."
The wizard's state is stale, GSD's is canonical, and they contradict.

**Why it happens:** Adding a new state file is the easy solution when building
wizard state persistence. It feels clean. But it creates a secondary source of
truth that drifts from GSD's primary state.

**Consequences:** Wizard gives wrong "resume" suggestion after context reset. User
runs wrong phase command. If they follow the wizard's bad advice, GSD may execute
Phase 3 before Phase 2's gate has passed.

**Warning signs:**
- Wizard creates any file in `.planning/` that doesn't already exist in GSD's schema
- "Where am I?" question returns different answers depending on whether the wizard
  or `/gsd:discuss-phase` was used to check

**Prevention:**
- The wizard must derive state exclusively from GSD's existing state files:
  `.planning/STATE.md`, `.planning/config.json`, `*-UAT.md`, `*-PLAN*.md`
- Read-only derivation only — never write wizard-specific state files
- The existing `project-setup-wizard.md` already does this correctly (lines 66-84);
  the new wizard skill should extract and reuse that logic, not reinvent it

**Phase mapping:** Backing agent design (Phase 2).

---

### Pitfall 6: Over-Engineering the Three-Component Split

**What goes wrong:** The design calls for a router skill + wizard skill + backing
agent — three components with clean separation. But clean separation gets
interpreted as "each component must be capable of operating independently" which
leads to each component duplicating detection, state-reading, and context-loading.
Result: 3x the tokens spent on overhead.

**Why it happens:** Good software design instincts applied to the wrong context.
In a normal application, loose coupling is good. In a context-budget-constrained
AI system, redundant capability loading is expensive.

**Consequences:** Component boundaries that made sense on a whiteboard cost tokens
in practice. The backing agent re-runs detection because it doesn't trust the
router's output. The wizard skill re-reads state because it doesn't persist the
router's detection results in a cheap way.

**Warning signs:**
- Backing agent has its own detection bash block
- Wizard skill re-reads `.planning/config.json` when the router already parsed it
- Any component reads a file that a prior component in the same user request
  already read

**Prevention:**
- Define a lightweight detection result format that the router outputs inline
  (structured text or minimal JSON in the conversation) that downstream components
  can parse without re-reading files
- The backing agent should only read what the conversation history doesn't already
  contain
- Budget tokens explicitly: router <2k, wizard UI <3k, backing agent gets remaining
  budget for the actual work

**Phase mapping:** Architecture design (before any implementation).

---

### Pitfall 7: The Guided Wizard UI Asks Too Many Questions

**What goes wrong:** The wizard presents a menu (STATE A: "What do you want to
use? 1. BMAD only / 2. GSD only / 3. BMAD→GSD / 4. Explain first"). Then it asks
"Which workflow?" Then it asks "Should I show install commands?" Then "Do you want
me to run the first command now?" The user answered a 4-question wizard when one
question would have done.

**Why it happens:** Each clarifying question feels necessary. Wizard authors
are afraid of doing the wrong thing and design the system to gather maximum
certainty before acting. But the user came to the wizard to reduce decisions, not
to make more.

**Consequences:** Wizard becomes friction, not flow. Users learn to avoid it.
Context is spent on conversation overhead, not work. The existing entry agents
already have this problem to a small degree.

**Warning signs:**
- Wizard's guided path requires more than 2 turns to reach a workflow
- User answer to turn 1 fully determines the answer to turn 2 (making turn 2
  unnecessary)
- User frequently selects "4. Explain first" — this means the other options
  weren't clear enough, not that the user needs more turns

**Prevention:**
- Default to the highest-confidence action with a confirmation step, not an
  open-ended menu
- Example: if BMAD is complete and GSD is not initialized, the only sensible
  next step is the handoff — say "Ready to bridge to GSD. Run this? [Y/n]" not
  "What would you like to do?"
- Reserve the numbered menu for genuinely ambiguous states (STATE A: new project
  with no indicators of user intent)
- "Explain" option is always available but never the default

**Phase mapping:** Wizard skill UI design (Phase 3).

---

### Pitfall 8: Context Window Budget Ignored During Development

**What goes wrong:** During development, the wizard is tested on small projects
where context overhead is invisible. In production, a user with a large BMAD PRD,
multiple phase context files, and a long git log finds that the wizard burns 20%
of context before they reach the first real command.

**Why it happens:** Context costs are invisible in development. Developers test
with empty projects, not with projects that have 50 BMAD stories, 8 phase context
files, and 3 months of git history.

**Consequences:** The wizard is technically functional but violates the <10%
overhead budget in real conditions. It's a production regression from the existing
lighter-weight agents.

**Warning signs:**
- No token budget test exists for the router + wizard + backing agent combined
- Development test projects have fewer than 5 phases and no large BMAD docs
- No measurement of context used before first user-work command executes

**Prevention:**
- Test with a "worst case" project: PRD >500 lines, architecture >800 lines,
  8+ phases, 20+ stories
- Measure token usage of each component in the chain, not just final output
- The 10% budget means: in a 200k context window, the router+wizard overhead
  must be under 20k tokens combined — enforce this as a pass/fail test criterion

**Phase mapping:** Testing/validation (every phase, not just the final one).

---

## Minor Pitfalls

---

### Pitfall 9: BMAD Legacy Version Handling Breaks Detection

**What goes wrong:** The existing agents already handle legacy BMAD detection
(`.bmad/` vs `_bmad/`). The new wizard skill uses the same detection logic but
misses the legacy case in one branch. Users on BMAD v4 get routed to STATE A
(no BMAD) instead of STATE C (BMAD only) when they actually have legacy BMAD docs.

**Why it happens:** Legacy case is an edge case; it's easy to forget in
a new implementation.

**Prevention:**
- Reuse the detection logic from `project-setup-wizard.md` Phase 1 verbatim,
  including the `.bmad/` legacy check
- Never rewrite detection from scratch; copy and reference the existing agent

---

### Pitfall 10: Hardcoded Slash Command Names

**What goes wrong:** The wizard outputs commands like `/gsd:discuss-phase N` and
`/workflow-init`. BMAD or GSD updates their command names (this has already
happened — BMAD v4→v6 changed directory structure). The wizard outputs stale
commands that fail.

**Why it happens:** Commands are treated as stable constants. They aren't.

**Prevention:**
- Treat slash command names as soft references with a version note: "as of GSD
  3.x, the command is `/gsd:discuss-phase N` — check docs if this doesn't work"
- The `stack-update-watcher` agent already handles this problem for agents;
  ensure the wizard's output commands are covered by its update checks

---

### Pitfall 11: Wizard Activates on Too Broad a Trigger Phrase Set

**What goes wrong:** The wizard is configured to activate on phrases like "wizard",
"set up this project", "where do I start", "resume", "what should I run". These
overlap with the existing entry agents' trigger phrases. Both the wizard and
`project-setup-wizard` activate for the same phrase, producing duplicate output.

**Why it happens:** Trigger phrases are copy-pasted from the existing agents when
creating the new skill's YAML frontmatter.

**Prevention:**
- The new `/wizard` command should be invoked via slash command, not via natural
  language triggers that overlap with existing agents
- Natural language triggers should remain with the existing entry agents
- If natural language triggers are added to the wizard skill, audit all 11 existing
  agent `description` fields for overlap first

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Router skill: state detection | Contradictory markers (Pitfall 3) | Cross-validate BMAD markers (dir + docs), not just dir presence |
| Router skill: wrap vs. reimplement | Divergence from existing agents (Pitfall 4) | Call existing entry agents, do not reimplement detection |
| Router skill: handoff format | Per-component re-reading state (Pitfall 6) | Define inline detection result format once; pass it forward |
| Backing agent: traceability | Silent requirement drop at handoff (Pitfall 2) | Assert every BMAD criterion appears in a phase context file |
| Backing agent: state storage | Wizard state diverges from GSD state (Pitfall 5) | Derive state read-only from existing GSD files only |
| Wizard UI: question count | Too many turns before handoff (Pitfall 7) | Max 2 turns to reach a workflow; default to action not menu |
| Wizard UI: context budget | Overhead exceeds 10% in real conditions (Pitfall 8) | Test with large realistic projects before claiming done |
| All phases: testing | Context budget invisible in dev (Pitfall 8) | Include token measurement in every phase's definition of done |
| Integration: trigger phrases | Activation overlap with existing agents (Pitfall 11) | Use slash command entry, audit overlap before adding NL triggers |
| Integration: slash commands | Stale command names after BMAD/GSD updates (Pitfall 10) | Version-note commands in output; include in stack-update-watcher coverage |
| Critical: orchestrator overhead | Wizard costs more context than it saves (Pitfall 1) | Enforce <10% budget test; measure before claiming any phase done |

---

## Sources

- Direct analysis of `/Users/flong/Developer/claude-code-stack/agents/` (all 11
  agents) — HIGH confidence
- `/Users/flong/Developer/claude-code-stack/.planning/codebase/CONCERNS.md` —
  technical debt, known bugs, and fragile areas documented by codebase analysis —
  HIGH confidence
- `/Users/flong/Developer/claude-code-stack/.planning/PROJECT.md` — project
  constraints and stated pain points — HIGH confidence
- `/Users/flong/Developer/claude-code-stack/.planning/codebase/ARCHITECTURE.md` —
  system structure and data flow — HIGH confidence
- Context: knowledge of Claude Code agent system, skills architecture, and
  context window management patterns — MEDIUM confidence (training data,
  August 2025 cutoff)
