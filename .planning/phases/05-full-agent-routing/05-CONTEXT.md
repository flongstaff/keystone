# Phase 5: Full Agent Routing - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Add validate-phase, drift-check, and on-demand traceability display routes to the wizard, completing the full intent routing surface. The wizard's full-stack and gsd-only scenarios gain a post-status prompt with secondary options alongside the primary "Continue" action. Drift check and validation delegate to existing agents. Traceability display is a new Route C in the backing agent.

</domain>

<decisions>
## Implementation Decisions

### Secondary option access
- Full-stack and gsd-only scenarios gain a post-status AskUserQuestion prompt before auto-invoke
- "Continue" is always the recommended first option (preserves fast path)
- Full-stack menu: Continue, Check drift, Show traceability, Validate phase (4 options)
- Gsd-only menu: Continue, Check drift, Validate phase (3 options — no traceability without BMAD)
- Other scenarios (none, bmad-ready, bmad-incomplete, ambiguous) keep their existing menus unchanged
- After any secondary option completes, return to the same post-status menu — user can run another or continue

### Failure presentation
- Pass-through: delegate to existing agents and let their structured reports flow through unmodified
- Phase-gate-validator produces its own PASS/WARN/FAIL report with exact fix commands — wizard does not reformat
- Context-health-monitor produces its own 5-check health report with fix commands — wizard does not reformat
- No summarization or digest layer — the existing agent output IS the presentation

### Traceability display
- Phase-level summary: group by GSD phase showing criteria count and completion status
- Completion status uses file-state ladder (same logic as wizard-router): no dir = not started, CONTEXT.md = planning, PLAN.md = plans ready, mid-execution = executing, VERIFICATION.md = complete
- Deferred criteria shown separately with pointer to .planning/DEFERRED-CRITERIA.md
- Bottom line shows total mapped vs deferred counts
- If no BMAD story files found: short error message + pointer to DEFERRED-CRITERIA.md, then return to menu
- Built as Route C in wizard-backing-agent.md (needs data work: reading stories + scanning .planning/)

### Route trigger flow
- Auto-target current phase from gsd.current_phase in wizard-state.json — no extra "which phase?" question
- User can override via "Other" free text (e.g., "validate phase 2")
- Drift check: wizard.md invokes context-health-monitor directly via Agent tool (simple delegation, no backing agent needed)
- Validate phase: wizard.md invokes phase-gate-validator directly via Agent tool (simple delegation)
- Show traceability: wizard.md invokes wizard-backing-agent Route C via Agent tool with route hint in prompt
- Route intent passed as argument in Agent/Skill call, never persisted to wizard-state.json

### Claude's Discretion
- Exact wording of post-status prompt question and option labels
- How "Other" free text is parsed for phase number overrides
- Agent tool invocation details (subagent_type, prompt phrasing, model selection)
- Traceability report formatting details (box drawing, spacing, alignment)
- How backing agent Route C extracts and matches criteria to phases

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `agents/bridge/context-health-monitor.md`: Self-contained 5-check drift analysis with structured report output — invoke directly via Agent tool
- `agents/bridge/phase-gate-validator.md`: Self-contained 5-gate validation with PASS/WARN/FAIL verdicts and fix commands — invoke directly via Agent tool
- `skills/wizard-backing-agent.md`: Routes A (resume) and B (bridge) already built — add Route C (traceability display)
- `skills/wizard.md`: Full-stack and gsd-only scenario blocks need updating to add post-status prompt
- `skills/wizard-detect.sh`: File-state ladder logic for phase status detection — traceability display reuses same approach

### Established Patterns
- Wizard delegates heavy work to backing agent (Route A, B) — traceability follows same pattern
- Wizard delegates simple analysis to existing agents directly — drift check and validation follow this pattern
- Phase 4 rule: "Never write to wizard-state.json" — backing agent only reads it
- Agent tool for read-only analysis; Task() reserved for heavy operations like bridging (Phase 4)
- AskUserQuestion with recommended first option is standard GSD pattern

### Integration Points
- `wizard.md` full-stack block: replace auto-invoke with post-status AskUserQuestion, then dispatch based on selection
- `wizard.md` gsd-only block: same change, minus traceability option
- `wizard-backing-agent.md`: add Route C (traceability display) after existing Route B
- wizard-state.json `gsd.current_phase`: used for auto-targeting phase in drift/validation

</code_context>

<specifics>
## Specific Ideas

- The post-status prompt should feel like a natural pause — "here's where you are, what do you want to do?" — not a gate or interrogation
- Secondary options are power-user features: the default path (Continue) should require minimal thought
- Pass-through for drift/validation reports means the wizard is transparent — what the agent produces is what the user sees, no telephone game

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-full-agent-routing*
*Context gathered: 2026-03-12*
