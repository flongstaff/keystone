# Feature Landscape

**Domain:** Unified wizard/orchestrator for a two-framework AI coding stack (BMAD planning + GSD execution)
**Researched:** 2026-03-11
**Confidence:** HIGH — based on direct reading of all existing agents, hooks, and docs in the codebase

---

## Research Method

No web search was available. All findings are derived from direct analysis of the existing Claude Code Stack:
- 6 agents read in full (project-setup-wizard, project-setup-advisor, bmad-gsd-orchestrator, doc-shard-bridge, phase-gate-validator, context-health-monitor)
- docs/workflows.md, docs/orchestration.md, .planning/PROJECT.md read in full
- Pain points sourced from PROJECT.md "Current pain points the wizard solves" section

This gives HIGH confidence on features for this specific domain because the wizard is wrapping known, installed, documented infrastructure.

---

## Table Stakes

Features a user MUST have or the wizard is useless. Without these, users are worse off than running commands manually.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **State detection at entry** | Without knowing where the project is, the wizard can't route anywhere. Four states exist: neither/BMAD-only/GSD-only/both. Detecting wrong state causes harmful suggestions. | Medium | Detection script exists in project-setup-wizard already; router skill must replicate or delegate to it |
| **Single entry command** | The whole point is one command. Multiple entry points defeats the wizard premise entirely. | Low | `/wizard` is decided; must activate agent/skill reliably |
| **Route to the right next action** | Users open the wizard because they don't know what to run next. A wizard that says "here are your options" without a recommended default gives no value over the existing docs. | Medium | Must read `.planning/STATE.md`, `.planning/*.md` glob, UAT files to compute next command |
| **Context-efficient dispatch** | The wizard sits in the context window before real work happens. If it consumes 20%+ of context before delegating, it harms every session. | High | PROJECT.md constraint: wizard overhead < 10% of context window |
| **Full lifecycle coverage** | Must handle all four entry states (fresh/BMAD-only/GSD-only/full-stack) and all lifecycle transitions (plan → bridge → execute → verify → milestone → next milestone). Missing a state means users fall back to manual commands. | High | Six workflow paths exist in the wizard agent already; router must cover all of them |
| **Preserve and pass context** | BMAD docs must flow into GSD without re-asking questions already answered in planning. This is the #1 current pain point in PROJECT.md. | High | bmad-gsd-orchestrator already does this, but only when triggered manually; wizard must trigger it automatically |
| **State persistence across resets** | Context windows reset. The wizard must always be able to re-orient from file state, never from in-memory state. | Medium | `.planning/STATE.md`, `.planning/config.json`, UAT file presence are the signals; wizard must read these cold |
| **Unambiguous next command output** | Must end every interaction with the exact command to run, not a description of options. "Run `/gsd:discuss-phase 3`" not "you could discuss the next phase." | Low | Already a rule in existing project-setup-wizard; must be enforced in new router skill |

---

## Differentiators

Features that make Keystone better than running commands manually. Not expected — users don't know to ask for them — but they create the "oh, this is actually useful" moment.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Automatic BMAD → GSD bridge trigger** | Today users must remember to say "initialise GSD from BMAD docs" at the right moment. Wizard detects when BMAD is complete and proactively offers/runs the bridge. Removes the most common mistake (running /gsd:new-project on a BMAD project). | High | Requires reading BMAD story approval counts, PRD/architecture presence, and .planning absence simultaneously |
| **Next-command computation from file state** | Rather than showing menus, compute the exact next command from `.planning/` file state: "plans exist but no UAT → execute-phase 3." This is deterministic and can be done without user input. | Medium | Logic already exists in project-setup-wizard Phase 1 detection; needs to be extracted into the router skill |
| **UAT failure short-circuit** | When UAT shows failures, wizard automatically generates and presents fix plan — no user needs to know which command repairs a failed phase. | Medium | phase-gate-validator already reports what failed; wizard adds the "here's the fix command" layer |
| **Requirement traceability display** | At any point, show which BMAD acceptance criteria map to which GSD phase and their status. Today this requires manually reading bmad-outputs/STATUS.md. | Medium | Doc already exists; wizard can surface it in a formatted summary on demand |
| **Context health integration** | After execute-phase, automatically prompt "run context-health-monitor before continuing?" — users currently skip this and only discover drift at the gate. | Low | Advisory integration; just emit the prompt at the right lifecycle moment |
| **Inline education mode** | When a user asks "explain" at any branch point, wizard gives a concise explanation of what each choice means, then returns to the same branch. Does not restart the whole flow. | Medium | "W6: Explain" workflow exists; needs to be accessible from within any wizard state, not just at startup |
| **Complexity-based path recommendation** | Wizard recommends BMAD+GSD vs GSD-only vs quick-task based on scope signals (duration estimate, team size, risk level). Currently users must self-classify. | Medium | Complexity heuristic already in project-setup-advisor (3 days / 1 week / multi-team thresholds); extract it |
| **IT infrastructure project detection and override** | Auto-detect infra projects and inject safety rules (auto_advance: false, dry-run requirements, rollback docs) without requiring the user to remember or configure them. | Low | Detection logic exists in project-setup-wizard Phase 1; IT rules defined in it-infra-agent; wizard just needs to wire them together |
| **Domain agent activation suggestions** | When the project type matches a domain agent (Godot, IT infra, open-source, admin docs), wizard surfaces "you may want to use [domain-agent] for this phase" at appropriate points rather than requiring the user to know these agents exist. | Low | Domain detection already done in session-start.sh and project-setup-advisor; just surface it |

---

## Anti-Features

Features to explicitly NOT build. Each one is a complexity trap that has killed similar tools.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Replacing BMAD or GSD commands** | Replacing existing, working tools requires maintaining two codebases, breaks user muscle memory, and eliminates the benefit of upstream improvements to BMAD/GSD. PROJECT.md makes this an explicit constraint. | Wrap existing commands. Wizard dispatches to `/gsd:discuss-phase N` — it does not reimplement discuss-phase. |
| **A GUI or visual workflow builder** | Claude Code is a terminal-first, text-first environment. Any visual layer would require a separate server, break inside SSH sessions, and add maintenance burden entirely outside the Claude Code ecosystem. | Use structured text output with ASCII box drawing (as the existing project-setup-wizard already does). |
| **Autonomous phase execution without human checkpoints** | auto_advance: false is a hard constraint in the project. Agents that run multiple phases without pausing for human review create irreversible changes, especially on infra projects. | Require explicit user confirmation before every phase transition. Always present "run this next" rather than running it. |
| **Storing state in agent memory** | Agent memory is destroyed on context reset. Any state stored only in the conversation context will be lost. This is the "context rot" problem GSD was built to solve. | Write all state to `.planning/` files. Router reads cold from disk every time. |
| **Generic AI orchestration features** | Features like "spawn N agents in parallel for any task" or "auto-retry failed steps" are useful for general orchestration but are already handled by GSD's execute-phase. Adding them to the wizard creates duplication and competing behavior. | Let GSD handle parallel execution and retry. Wizard routes to GSD; GSD handles orchestration details. |
| **Cross-project orchestration** | Managing multiple projects from one wizard session multiplies state complexity by N and is explicitly out of scope in PROJECT.md. | One wizard, one project. If users want multi-project views, that's a separate tool. |
| **Natural language intent parsing for routing** | Parsing "I want to build a new feature" into a specific GSD phase route requires a full NLU step that will fail on edge cases. Current wizard uses explicit state detection, which is deterministic and testable. | Detect routing from file system state, not from user intent. When intent is needed, present numbered menu choices. |
| **Changelog / history tracking** | The wizard is not a project management dashboard. Adding ticket tracking, sprint burndown, or velocity metrics brings in complexity that belongs in BMAD docs or an external tool. | BMAD stories in `docs/stories/` and `bmad-outputs/STATUS.md` serve as the source of truth. Wizard reads them; it does not add to them. |
| **Configuration wizard / onboarding tour** | First-run setup flows ("let's configure your preferences") add friction before any value is delivered. The stack installs via npm with known defaults. | State detection handles the "first time" case (STATE A: Clean Slate). No separate onboarding needed. |

---

## Feature Dependencies

```
State detection → Everything (all routing depends on knowing current state)

State detection → Route computation → Next command output
State detection → BMAD bridge trigger (requires BMAD docs present + GSD absent)
State detection → Complexity recommendation (fresh project only)

Route computation → UAT failure short-circuit (requires UAT file presence)
Route computation → Context health integration (requires post-execute-phase state)

BMAD bridge trigger → Requirement traceability display (requires bmad-outputs/STATUS.md)

Domain detection (exists in session-start.sh) → IT override injection
Domain detection → Domain agent activation suggestions

Inline education mode → Any state branch point (must not restart flow)
```

Dependencies that must be sequenced:

1. **State detection must be implemented first.** Nothing else can be built without it. The detection logic in project-setup-wizard (Phase 1 bash block) is the reference implementation.

2. **Route computation depends on state detection.** The next-command computation logic (reading `*-PLAN*.md`, `*-UAT.md`, `STATE.md` globs) is the second building block.

3. **BMAD bridge trigger depends on both.** Must know: (a) BMAD docs are complete, (b) GSD is not yet initialized.

4. **All differentiators depend on table stakes.** No differentiator can be built before the core routing path works end-to-end.

---

## MVP Recommendation

Prioritize to make the wizard functional and deliver immediate value:

**Phase 1 (table stakes — must have):**
1. State detection (four states: neither/BMAD-only/GSD-only/full-stack)
2. Next-command computation from file state
3. Single-entry `/wizard` routing to the right recommendation
4. State persistence via `.planning/` file reads
5. Unambiguous "run this command next" output

**Phase 2 (key differentiators — make it better than manual):**
6. Automatic BMAD → GSD bridge trigger (highest user pain point per PROJECT.md)
7. UAT failure short-circuit
8. IT infrastructure detection and override injection
9. Inline education mode at branch points

**Phase 3 (polish — make it delightful):**
10. Requirement traceability display on demand
11. Context health integration prompting
12. Complexity-based path recommendation for fresh projects
13. Domain agent activation suggestions

**Defer indefinitely:**
- Cross-project orchestration (out of scope)
- Visual interfaces
- Autonomous phase execution
- Natural language intent parsing

---

## What Exists vs What Needs Building

Understanding what already exists is critical for a brownfield project. Do not rebuild what works.

| Feature | Exists? | Where | Needs Building |
|---------|---------|-------|---------------|
| State detection (4 states) | YES | project-setup-wizard Phase 1 bash block | Extract into router skill |
| Six workflow paths (W1–W6) | YES | project-setup-wizard Phase 3 workflow library | Wire into router skill |
| Next-command computation | YES | project-setup-wizard Phase 1 GSD state detail | Extract into router skill |
| BMAD → GSD bridge | YES | bmad-gsd-orchestrator Operation A | Auto-trigger condition only |
| GSD → BMAD story sync | YES | doc-shard-bridge Operation B, bmad-gsd-orchestrator Operation B | Auto-trigger condition only |
| Phase gate validation | YES | phase-gate-validator (5 gates) | Routing to it, not reimplementing |
| Context health monitoring | YES | context-health-monitor (5 checks) | Routing to it, prompting at right lifecycle moment |
| IT infra detection and rules | YES | project-setup-wizard IT Infrastructure Override + it-infra-agent | Wire together, expose in router |
| Domain detection | YES | project-setup-advisor Step 2, session-start.sh | Expose at right wizard branch points |
| Education mode | YES | project-setup-wizard W6 Explain | Make accessible from within any state, not just startup |
| Requirement traceability | PARTIAL | bmad-outputs/STATUS.md exists | Formatted display surface only |
| Complexity recommendation | YES | project-setup-advisor SCENARIO D decision table | Extract and surface in fresh-project flow |
| Context budget enforcement | NO | — | Must design; constraint is < 10% overhead |

---

## Sources

- `/Users/flong/Developer/claude-code-stack/.planning/PROJECT.md` — requirements, constraints, pain points (PRIMARY)
- `/Users/flong/Developer/claude-code-stack/agents/entry/project-setup-wizard.md` — existing wizard implementation
- `/Users/flong/Developer/claude-code-stack/agents/entry/project-setup-advisor.md` — existing advisor implementation
- `/Users/flong/Developer/claude-code-stack/agents/bridge/bmad-gsd-orchestrator.md` — bridge operations
- `/Users/flong/Developer/claude-code-stack/agents/bridge/doc-shard-bridge.md` — document sharding
- `/Users/flong/Developer/claude-code-stack/agents/bridge/phase-gate-validator.md` — phase gates
- `/Users/flong/Developer/claude-code-stack/agents/bridge/context-health-monitor.md` — drift detection
- `/Users/flong/Developer/claude-code-stack/docs/workflows.md` — end-to-end workflow documentation
- `/Users/flong/Developer/claude-code-stack/docs/orchestration.md` — cross-runtime orchestration patterns

All findings are HIGH confidence — derived from direct code/doc reading, not inferred.
