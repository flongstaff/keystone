# Project Research Summary

**Project:** Keystone — Wizard Orchestrator for Claude Code Stack
**Domain:** Claude Code slash command + agent + skill orchestration layer (brownfield)
**Researched:** 2026-03-11
**Confidence:** HIGH

## Executive Summary

Keystone is a brownfield orchestration layer that provides a single `/wizard` entry point over two existing, well-tested frameworks: BMAD (planning) and GSD (execution). The research domain is unusual in that there are no external libraries to choose — the "stack" is the Claude Code extension model itself (skills, agents, slash commands), and all source material comes from direct code analysis of the existing codebase. This gives the research an exceptionally high confidence level: every architectural decision is validated against working code, not documentation or community consensus.

The recommended architecture is a three-component chain: a thin router skill that performs state detection in a single bash block, a wizard skill that presents scenario-appropriate menus and captures user intent, and a backing agent that does the heavy orchestration work by dispatching to existing agents. The central engineering constraint is a context budget of under 10% overhead — the wizard must cost less context than it saves. This rules out rich interactive flows, verbose explanations, and redundant file reads across components. The pattern is proven: the existing `execute-phase` command follows an identical slash command → backing agent structure.

The key risk is dual-failure-mode complexity: the wizard can fail by doing too much (context bloat that makes it slower than running commands directly) or by doing too little (silently dropping BMAD requirements at the handoff to GSD). Both failure modes are documented in the existing codebase's own concern files and are addressable with specific, testable constraints: cap the router skill at one bash block reading at most three files, and require traceability assertions at the BMAD→GSD bridge.

## Key Findings

### Recommended Stack

This is a brownfield project with fixed runtime targets. The "stack" is the Claude Code extension model: three primitive types compose in a specific direction (slash commands delegate to agents, agents preload skills, skills fork or inject context). All components install to `~/.claude/` directories alongside the existing 11 agents and 5 skills.

**Core technologies:**

- **Slash command (`commands/wizard.md`):** User-facing entry point — chosen over pattern-triggered agents because slash commands activate on explicit invocation, not conversation matching, giving the wizard deterministic behavior
- **Router skill (`skills/wizard-router/`):** State detection and scenario classification — implemented as a router-pattern skill (SKILL.md + workflows/ subdirectory) to keep invocation footprint small; the `user-invocable: true` flag makes it callable via `/wizard`
- **Wizard skill (`skills/wizard-interactive/`):** Interactive menu presentation and intent capture using `AskUserQuestion` — verified across 8+ existing GSD commands as the standard interaction mechanism
- **Backing agent (`agents/wizard/wizard-orchestrator.md`):** Spawned via `Task(subagent_type="wizard-orchestrator")` for all heavy orchestration; gets a fresh 200k context window; dispatches to existing agents rather than reimplementing their logic
- **`wizard-state.json` (`.planning/wizard-state.json`):** File-mediated communication between components; survives context resets because it is a file, not memory; uses `gsd-tools.cjs` for read/write utilities

**Model selection:** `sonnet` for both the router skill and backing agent. Routing and state detection do not require complex reasoning; all 11 existing agents use sonnet for comparable work. Opus is not justified.

**Critical version note:** The Claude Code agent YAML `skills:` field injects named skill SKILL.md files into agent context at spawn time — this is the mechanism for preloading domain knowledge. `context: fork` creates a fresh context window. `disable-model-invocation: true` prevents a skill from spawning its own completion. These fields are verified against the existing codebase.

### Expected Features

The wizard wraps existing functionality. 80% of required features already exist in the codebase and need extraction or wiring, not implementation from scratch.

**Must have (table stakes):**

- State detection across four scenarios (A: neither / B: GSD-only / C: BMAD-only / D: full-stack) — logic exists in `project-setup-wizard.md` Phase 1; extract it
- Next-command computation from file state (read `STATE.md`, `*-PLAN*.md`, `*-UAT.md` to determine exact next command) — logic exists; extract it
- Single `/wizard` entry point routing to the right recommendation
- State persistence via cold reads of `.planning/` files — no in-memory state; survives context resets
- Unambiguous output: "Run `/gsd:discuss-phase 3`" not "you could discuss the next phase"

**Should have (differentiators):**

- Automatic BMAD → GSD bridge trigger when BMAD docs are complete and GSD is uninitialized — highest user pain point per PROJECT.md
- UAT failure short-circuit: surface `phase-gate-validator` results plus the exact repair command
- IT infrastructure detection and auto-inject safety rules (`auto_advance: false`, dry-run requirements)
- Inline education mode accessible from any state branch, not just startup

**Defer (v2+):**

- Requirement traceability display (formatted surface of `bmad-outputs/STATUS.md` — partial infrastructure exists)
- Context health integration prompting (advisory, non-blocking)
- Complexity-based path recommendation for fresh projects
- Domain agent activation suggestions

**Anti-features (never build):**

- Replacing BMAD or GSD commands — wrap existing; never reimplement
- Autonomous phase execution without human checkpoints (`auto_advance: false` is a hard project constraint)
- Natural language intent parsing for routing (non-deterministic; use file-system state detection instead)
- State storage outside `.planning/` files (context rot problem GSD was built to solve)

### Architecture Approach

The architecture is a three-component pipeline with file-mediated communication. Each component has a strict size budget enforced by the 10% overhead constraint: router skill under 100 lines, wizard skill under 200 lines, backing agent under 400 lines. Components communicate exclusively through `wizard-state.json` — the schema for this file is the interface contract between all three and must be defined and frozen in Phase 1 before any other component is built.

**Major components:**

1. **Smart router skill** (`~/.claude/skills/wizard-router/`) — runs one bash block detecting scenario A/B/C/D; cross-validates markers (BMAD requires directory AND at least one doc file, not just directory); writes `wizard-state.json`; must not present UI or read more than 3 files
2. **Wizard skill** (`~/.claude/skills/wizard-interactive/`) — reads `wizard-state.json`; presents scenario-appropriate numbered menu; writes user intent back to `wizard-state.json`; spawns backing agent via `Task()`
3. **Backing agent** (`~/.claude/agents/wizard/wizard-orchestrator.md`) — gets fresh 200k context; reads `wizard-state.json`; routes to existing agents (bmad-gsd-orchestrator, phase-gate-validator, project-setup-wizard, etc.) without reimplementing their logic; emits exact next command; updates `wizard-state.json` with outcome

### Critical Pitfalls

1. **Orchestrator costs more context than it saves** — the 10% overhead budget (<20k tokens in a 200k window) is a hard constraint, not a guideline. Test with large realistic projects (PRD >500 lines, 8+ phases, 20+ stories). Enforce this as a pass/fail criterion in every phase's definition of done.

2. **Requirements silently drop at the BMAD→GSD handoff** — the existing `bmad-gsd-orchestrator` does not assert that every BMAD acceptance criterion appears in a GSD phase context file. The wizard must add this traceability check at the bridge step; otherwise requirements silently vanish and only surface at final QA.

3. **State detection produces contradictory results** — marker presence does not equal framework presence. `_bmad/` directory can exist empty; `.planning/` can exist without a `config.json` phases array. Cross-validate all markers: BMAD "present" requires directory AND at least one `docs/prd-*.md` or `docs/architecture-*.md`. Add a STATE.AMBIGUOUS case for cross-validation failures.

4. **Wizard diverges from existing agents over time** — "wrapping" must mean "calling the underlying agent," not "reimplementing the same logic in a new layer." Any scenario-specific logic added to the wizard skill should be added to the existing entry agents instead; the wizard stays as a thin dispatcher.

5. **Wizard state drifts from GSD state** — the wizard must derive its state read-only from GSD's existing files (`STATE.md`, `config.json`, `*-UAT.md`). Writing a new `wizard-state.json` is acceptable for wizard-specific UI state (last menu position, user intent), but the current phase and milestone must always be sourced from GSD's canonical files, never from a wizard-maintained copy.

## Implications for Roadmap

Based on research, the architecture research file explicitly recommends a four-phase build order driven by component dependencies. The features research confirms this ordering via its dependency tree (state detection is the root of every other feature). Both align on the same sequence.

### Phase 1: State Persistence Foundation

**Rationale:** `wizard-state.json` schema is the interface contract for all three components. Building any other component before the schema is stable guarantees a rebuild. The router skill's state detection is the only input to the schema, so it must exist first. Pitfall 3 (contradictory detection) and Pitfall 4 (divergence from existing agents) both manifest here — they must be addressed in design, not retrofitted.

**Delivers:** Frozen `wizard-state.json` schema (v1) + smart router skill that correctly classifies all four scenarios under the constraint of one bash block, three file reads max, and cross-validated markers. Tests: invoke `/wizard` against projects in each of the four scenarios and verify correct JSON output.

**Addresses (from FEATURES.md):** State detection, state persistence via cold reads, STATE.AMBIGUOUS case.

**Avoids (from PITFALLS.md):** Pitfall 3 (contradictory markers), Pitfall 4 (divergence), Pitfall 8 (context budget test from day one).

**Research flag:** No additional research needed. Detection logic exists verbatim in `project-setup-wizard.md` Phase 1 and must be extracted, not rewritten.

### Phase 2: Wizard Skill UI

**Rationale:** Depends on Phase 1 schema. Can be built and tested in isolation using a stub backing agent. The UI layer determines the user experience quality but cannot be tested meaningfully until state detection produces correct input. The menu design must enforce the two-turn maximum to reach a workflow (Pitfall 7).

**Delivers:** Interactive wizard skill with four scenario menus (A/B/C/D), intent capture, and `wizard-state.json` update. Maximum 2 turns from `/wizard` invocation to backing agent spawn. Stub backing agent confirms intent received.

**Implements (from ARCHITECTURE.md):** Wizard skill component; `Task()` invocation pattern; scenario-based menu routing (Pattern 2).

**Avoids (from PITFALLS.md):** Pitfall 7 (too many questions), Pitfall 6 (redundant state reads in the wizard layer).

**Research flag:** No additional research needed. `AskUserQuestion` usage is verified across 8+ existing GSD commands. Menu structure maps directly to the four documented scenarios.

### Phase 3: Backing Agent Routing

**Rationale:** Depends on Phases 1 and 2. Should be implemented one intent route at a time, verifying end-to-end before adding the next. The "resume" route is the simplest (emits a command string, no agent invocation) and should be implemented first. The "bridge-to-gsd" route addresses the highest user pain point and should be second. Traceability assertions for Pitfall 2 must be added at the bridge route step, not deferred.

**Delivers:** `wizard-orchestrator` agent routing these intents in order: (1) resume → emit GSD command, (2) bridge-to-gsd → invoke bmad-gsd-orchestrator with traceability check, (3) validate-phase → invoke phase-gate-validator, (4) check-drift → invoke context-health-monitor, (5) start-new-project → delegate to project-setup-wizard.

**Addresses (from FEATURES.md):** Automatic BMAD→GSD bridge trigger, UAT failure short-circuit, full lifecycle coverage.

**Avoids (from PITFALLS.md):** Pitfall 1 (fresh context for heavy work via Task), Pitfall 2 (traceability check at bridge), Pitfall 4 (dispatch to existing agents, no reimplementation), Pitfall 5 (derive phase state read-only from GSD files).

**Research flag:** The traceability check design (how to assert BMAD criteria appear in phase context files) may need a brief design spike. The data exists in `bmad-outputs/STATUS.md`; the assertion format needs to be defined.

### Phase 4: Context Reset Recovery and Polish

**Rationale:** Non-blocking. `wizard-state.json` survives context resets from Phase 1 onward. Phase 4 adds the UX layer: detecting prior session state and presenting a continuity message. Also includes IT infrastructure detection wiring, inline education mode accessibility from within any state (not just startup), and context budget validation against realistic large projects.

**Delivers:** Context continuity message on `/wizard` after reset; IT safety rule injection; education mode from any branch point; validated <10% context overhead on a worst-case project (PRD >500 lines, 8+ phases, 20+ BMAD stories).

**Addresses (from FEATURES.md):** IT infrastructure detection and override, inline education mode, context health integration prompting, complexity-based path recommendation.

**Avoids (from PITFALLS.md):** Pitfall 1 (production context budget test), Pitfall 8 (large project testing), Pitfall 9 (legacy BMAD version `.bmad/` detection), Pitfall 10 (stale command names covered by stack-update-watcher), Pitfall 11 (trigger phrase overlap audit).

**Research flag:** No additional research needed. All polish features use existing detection logic (IT infra: `project-setup-wizard.md`; domain detection: `session-start.sh`; education mode: W6 workflow in `project-setup-wizard.md`).

### Phase Ordering Rationale

The ordering is dependency-driven, not priority-driven. The schema is the root dependency — it blocks everything. The router skill produces the schema content — it must precede the wizard UI. The wizard UI captures intent — it must precede the backing agent. Context reset recovery is purely additive and has no blockers, making it correctly last.

This ordering also minimizes rework risk: each phase can be tested in isolation before the next begins. The backing agent in Phase 3 can use a stub for phases not yet routed. The wizard UI in Phase 2 can use a stub backing agent. None of the stubs need to be removed; they are replaced incrementally.

The pitfalls that matter most (Pitfalls 1, 3, 4) all manifest in Phase 1 design decisions. Addressing them in Phase 1 means they cannot silently undermine Phase 2 or 3.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 3 (traceability check):** The format for asserting BMAD acceptance criteria coverage in GSD phase context files is not defined anywhere in the existing codebase. A brief design spike is needed before the bridge route is implemented. This is a small, bounded design question, not a full research phase.

Phases with standard patterns (skip research-phase):

- **Phase 1:** State detection logic is ready to extract from `project-setup-wizard.md`. Schema design follows the established `.planning/` JSON conventions.
- **Phase 2:** `AskUserQuestion` and scenario menu patterns are verified across 8+ existing commands. No novel patterns needed.
- **Phase 4:** All features reuse existing detection and wiring logic. No new patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All components verified against working code in `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/commands/` — no external libraries or docs required |
| Features | HIGH | Derived from direct reading of 9 existing agents and PROJECT.md; 80% of features already exist in codebase and need extraction |
| Architecture | HIGH | Three-component design is directly described in PROJECT.md and validated against the execute-phase → gsd-executor pattern used throughout GSD |
| Pitfalls | HIGH | Sourced from CONCERNS.md (codebase's own documented fragile areas), PROJECT.md constraints, and analysis of existing agent edge cases |

**Overall confidence:** HIGH

### Gaps to Address

- **Traceability assertion format:** How to machine-check that every BMAD acceptance criterion appears in a GSD phase context file. The data exists; the assertion schema does not. Address in Phase 3 planning before the bridge route is implemented. Options: a `## Acceptance Criteria (from BMAD story N)` header convention in phase context files, or a validation step in `gsd-tools.cjs`.

- **Context budget measurement tooling:** No existing test measures token usage of the router + wizard + backing agent chain. The 10% constraint (<20k tokens in a 200k window) needs a measurement approach defined in Phase 1 and applied in every subsequent phase. One option: use `gsd-tools.cjs` to emit a token estimate after each component runs; another: manual review against a canonical large-project fixture.

- **Stub backing agent for Phase 2 testing:** The wizard skill testing plan depends on a stub backing agent that confirms intent receipt. This is a small implementation detail but needs to be explicit in Phase 2 planning to avoid blocking the UI layer test cycle.

## Sources

### Primary (HIGH confidence)

All findings are derived from first-party codebase analysis. No external sources were required or available.

- `~/.claude/agents/*.md` — all 11 agent YAML frontmatter fields and body patterns (verified: STACK.md)
- `~/.claude/skills/create-agent-skills/SKILL.md` — skill structure specification, router pattern, progressive disclosure (verified: STACK.md)
- `~/.claude/commands/gsd/*.md` — slash command YAML format, `agent:` delegation, `AskUserQuestion` usage (verified: STACK.md)
- `agents/entry/project-setup-wizard.md` — state detection Phase 1 bash block, W1–W6 workflows, IT infra override (verified: FEATURES.md, ARCHITECTURE.md)
- `agents/bridge/bmad-gsd-orchestrator.md` — BMAD→GSD handoff Operations A+B (verified: FEATURES.md)
- `agents/bridge/phase-gate-validator.md` — five phase gates, UAT validation (verified: FEATURES.md, ARCHITECTURE.md)
- `agents/bridge/context-health-monitor.md` — five drift checks (verified: FEATURES.md)
- `.planning/PROJECT.md` — requirements, constraints, pain points, wizard scenarios (verified: all research files)
- `.planning/codebase/CONCERNS.md` — documented fragile areas and technical debt (verified: PITFALLS.md)
- `.planning/codebase/ARCHITECTURE.md` — existing system structure and data flow (verified: ARCHITECTURE.md)
- `docs/workflows.md`, `docs/orchestration.md` — end-to-end workflow documentation (verified: FEATURES.md)

### Secondary (MEDIUM confidence)

- Claude Code agent system patterns (training data, August 2025 cutoff) — used to validate `context: fork`, `disable-model-invocation: true`, and `Task()` spawning patterns; all verified against first-party code

---
*Research completed: 2026-03-11*
*Ready for roadmap: yes*
