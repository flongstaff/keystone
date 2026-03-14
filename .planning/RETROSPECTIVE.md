# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.1 — Dynamic Toolkit Discovery

**Shipped:** 2026-03-14
**Phases:** 5 | **Plans:** 6 | **Requirements:** 20/20

### What Was Built
- toolkit-discovery.sh: full scanner for agents (176), skills (28), hooks (24), and MCP servers with TTL caching
- State integration: compact toolkit summary (~600B) embedded in wizard-state.json on every /wizard invocation
- Capability injection: stage-filtered tool pointers injected into all Agent()/Task() spawns across wizard and GSD workflows
- Trust classification: hardcoded KNOWN_SAFE allowlist with batched confirmation for unknown tools
- Dynamic catalog: registry-backed "Discover tools" display with hardcoded Phase 7 fallback
- Global deployment: 4 skill files synced to ~/.claude/skills/ for cross-project access

### What Worked
- Single-day milestone execution (5 phases in ~8 hours) — tight scope and clear requirements
- Two-level architecture decision (compact summary + full registry) kept startup tokens flat
- PERF-03 constraint (never read registry at startup) enforced cleanly throughout
- Milestone audit passed on first run — requirements were well-specified and verifiable

### What Was Inefficient
- Roadmap plan checkboxes for v1.1 phases left unchecked (`- [ ]`) despite all plans being complete — only caught during milestone completion
- Documentation estimates in Phase 15 plan (~234 lines saved) were significantly off from actual (39 lines net) — estimate methodology needs calibration
- GSD workflow files (Phase 14-02) can only be modified globally — creates re-apply burden on clean installs

### Patterns Established
- `<capabilities>` XML tag for subagent injection — matches GSD prompt conventions
- Trust classification: hardcoded allowlist pattern for known-safe vs unknown tools
- Display Catalog prose redirect pattern — single shared block serving multiple menu handlers
- TTL-gated caching for expensive scans — 1h TTL with ~23ms cache hit performance

### Key Lessons
1. When modifying framework-global files (GSD workflows), document the re-apply steps explicitly — otherwise knowledge is lost on re-clone
2. Stage matching via keyword regex is sufficient for 176 agents — no need for LLM-based semantic matching (validates Out of Scope decision)
3. Compact summary constraint (~600B) forced good design — filtering to 6 per stage produced a usable, not overwhelming, capability list
4. PERF-03 (lazy registry loading) should be the default pattern for any expensive data source — load on demand, never at startup

### Cost Observations
- Model mix: ~80% opus, ~20% sonnet (research and planning phases used opus; execution mixed)
- Sessions: ~6 (1-2 per phase, some phases combined)
- Notable: Single-day turnaround for 5 phases suggests tight scoping pays dividends in velocity

---

## Milestone: v1.0 — Wizard Orchestrator

**Shipped:** 2026-03-13
**Phases:** 12 (including 1 decimal) | **Plans:** 17 | **Requirements:** 23/23

### What Was Built
- Smart router skill (wizard-detect.sh) with 5-scenario detection from disk state
- Interactive wizard (wizard.md) with 4-scenario menus and 2-turn max to recommendation
- Backing agent (wizard-backing-agent.md) with bridge-to-GSD route and traceability assertions
- Full routing surface: validate-phase, drift-check, traceability display
- Recovery: context-reset continuity, IT safety injection, health-monitor prompts
- Hardcoded tool catalog with all Keystone agents, skills, and hooks

### What Worked
- Three-component architecture (router + wizard + agent) kept concerns separated
- Phase-gated execution with audit loops caught integration breaks before they compounded
- Gap-closure phases (8, 9, 10, 11) were effective at cleaning up issues the audit identified

### What Was Inefficient
- 4 gap-closure phases (8-11) after the main build (phases 1-7) — indicates initial implementation missed integration testing
- Phase 4 had to be rewired as Phase 4.1 after a fix commit orphaned the backing agent — root cause was insufficient integration testing at commit time
- Multiple global deployment sync phases (9, 11) — deploy-and-verify should be a single step, not a recurring phase

### Patterns Established
- wizard-state.json as the single source of truth for project state
- Global deployment pattern: project-local → ~/.claude/skills/ via cp -p
- Phase numbering: integers for planned work, decimals for urgent insertions

### Key Lessons
1. Integration testing should happen at commit time, not as a separate audit-driven phase
2. Global deployment sync should be automated or at least a single-command operation, not a manual multi-step phase
3. Gap-closure phases are a symptom of insufficient verification during execution — invest in better phase-gate validation
4. Decimal phase numbering (4.1) works well for urgent insertions without disrupting the roadmap

### Cost Observations
- Sessions: ~12-15 (multiple sessions per phase for complex phases)
- Notable: Gap-closure phases (8-11) consumed ~30% of total effort for ~5% of feature value — validating investment in better phase execution

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 12 | 17 | Established phase-gate validation; identified need for integration testing |
| v1.1 | 5 | 6 | Tighter scoping; audit passed first try; single-day execution |

### Top Lessons (Verified Across Milestones)

1. Tight scope produces faster milestones — v1.1 (5 phases, 1 day) vs v1.0 (12 phases, 3 days including 4 gap-closure)
2. Global deployment sync is a recurring concern — automate or reduce friction
3. Milestone audits before completion catch real issues — both milestones benefited from pre-completion audit
