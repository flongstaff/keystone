# Phase 6: Recovery, Safety, and Polish - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

The wizard survives context resets with continuity messaging, automatically injects safety constraints for infrastructure projects, prompts health checks after phase execution, and is validated against the 10% context budget. All changes extend existing wizard-detect.sh and wizard.md — no new files.

</domain>

<decisions>
## Implementation Decisions

### Context-reset continuity
- Detect reset via wizard-state.json age: if `detected_at` is older than ~30 seconds, it's a reset
- Show "Welcome back." line at the top of the existing status box — no separate banner or extra UI
- Last-position-only: phase name, last activity, next command (all already available in wizard-state.json + STATE.md)
- Purely informational — no behavior change, same menu, same options. The continuity line is a visual signal only
- wizard-detect.sh computes IS_RESET and conditionally prepends the line to the status box output

### IT safety injection
- wizard-detect.sh writes to .planning/config.json when project_type is "infra":
  - `auto_advance: false`
  - `dry_run_required: true`
- Config write is idempotent — only writes if .planning/config.json exists (GSD is initialized)
- Safety banner displayed in status box on every /wizard invocation for infra projects: "IT Safety: active"
- Banner is persistent — never dismissed, shown every time (safety is never "acknowledged and dismissed")
- it-infra-agent.md handles actual dry-run enforcement at execution time — wizard sets the config, domain agent enforces it

### Health-monitor prompt after execution
- Integrated into post-status menu when `phase_status == "uat-passing"` (phase execution complete, UAT passing)
- "Run health check" becomes the recommended first option, above Continue
- Uses context-health-monitor agent (same as existing "Check drift" option — they invoke the same agent)
- After health check completes, re-present the same menu with Continue moved to recommended position
- For full-stack uat-passing: fit within 4-option AskUserQuestion limit by collapsing "Check drift" (redundant with health check) into the health check option. Menu: Run health check (Recommended), Continue, Show traceability, Validate phase
- For gsd-only uat-passing: Run health check (Recommended), Continue, Validate phase
- Non-uat-passing states keep existing menus unchanged
- wizard.md reads `phase_status` from wizard-state.json to determine which menu variant to present

### Token budget validation
- Manual audit during this phase — count tokens in always-loaded files only:
  - wizard-detect.sh (every run)
  - wizard.md (every run)
  - wizard-state.json (every run)
- wizard-backing-agent.md excluded from budget — loaded in separate Task() context, not "before delegating"
- Target: total < 20k tokens (10% of 200k window)
- Trim priority if over budget: backing agent first (verbose bash examples, pitfall comments), then wizard.md (explain mode text, duplicate option text), then detect.sh (last resort — already lean)

### Claude's Discretion
- Exact IS_RESET threshold (30s is guidance, exact value can be tuned)
- Status box formatting details for "Welcome back." and "IT Safety: active" lines
- How to handle the 4-option constraint when uat-passing menus need both health check and existing options
- Token counting methodology (char-based estimate vs tokenizer)
- Whether to trim backing agent proactively or only if audit shows budget exceeded

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/wizard-detect.sh`: Detection script that writes wizard-state.json. Already has `detected_at` timestamp, `project_type` detection, `phase_status` computation via file-state ladder, and status box printing. All three features (continuity, safety, health prompt) extend this file
- `skills/wizard.md`: Interactive wizard with scenario branching and post-status menus. Health-monitor prompt adds a menu variant; continuity is handled in detect.sh output
- `skills/wizard-backing-agent.md`: Route B (bridge) + Route C (traceability). Token trim target if budget exceeded
- `agents/bridge/context-health-monitor.md`: Self-contained 5-check drift analysis. Already invoked by wizard.md "Check drift" option — health check reuses same agent
- `agents/domain/it-infra-agent.md`: Existing domain agent for infrastructure projects. Handles execution-time safety enforcement

### Established Patterns
- wizard-detect.sh writes wizard-state.json, wizard.md reads it — separation of detection and UI
- Status box printed by wizard-detect.sh with printf formatting and box-drawing characters
- Post-status AskUserQuestion menu loop: options re-present same menu after completion (Phase 5 pattern)
- Agent tool pass-through: wizard never summarizes or reformats agent output (Phase 5 rule)
- Global deployment: project-local source -> copy to ~/.claude/skills/

### Integration Points
- wizard-detect.sh: Add IS_RESET detection (compare detected_at age), add infra config write, add "Welcome back." and "IT Safety" lines to status box
- wizard.md: Add conditional menu variant for uat-passing phase_status (health check as recommended first option)
- .planning/config.json: Write auto_advance:false + dry_run_required:true for infra projects
- wizard-state.json: Already has all needed fields (detected_at, project_type, phase_status) — no schema changes needed

</code_context>

<specifics>
## Specific Ideas

- Continuity should feel like "picking up where you left off" (Phase 4 decision) — the "Welcome back." line is a gentle signal, not a diagnostic dump
- Safety injection is a persistent reminder — "IT Safety: active" in every status box for infra projects reinforces that this is a safety-critical project
- Health check after execution is a recommendation, not a gate — Continue is always available, health check just gets the recommended position
- The 4-option AskUserQuestion limit naturally resolves the menu complexity: "Check drift" and "Run health check" are the same agent, so they collapse into one option when health check is recommended

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-recovery-safety-and-polish*
*Context gathered: 2026-03-12*
