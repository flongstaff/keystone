# Milestones

## v1.1 Dynamic Toolkit Discovery (Shipped: 2026-03-14)

**Phases:** 5 phases (12-16), 6 plans | **Requirements:** 20/20 satisfied
**Timeline:** 2026-03-13 → 2026-03-14 (1 day) | **Commits:** 19

**Key accomplishments:**
1. Built toolkit-discovery.sh scanner — discovers 176 agents, 28 skills, 24 hooks, and MCP servers with 1h TTL caching (~23ms cached)
2. Wired compact toolkit summary (~600B) into wizard-state.json with status box display on every `/wizard` invocation
3. Added trust classification and batched confirmation UX for capability injection at all Agent()/Task() spawn sites
4. Injected stage-filtered capabilities into GSD workflow files (plan-phase, execute-phase, research-phase)
5. Replaced hardcoded Phase 7 catalog with dynamic registry-backed display, preserving hardcoded fallback for fresh installs
6. Deployed all 4 v1.1 skill files globally to ~/.claude/skills/ with cross-project verification

**Tech debt carried forward:**
- INJ-01 GSD workflow files are global-only (~/.claude/get-shit-done/workflows/) — re-clone requires re-applying Phase 14-02 changes
- Nyquist validation partial (1/5 compliant, 2 partial, 2 missing)

**Git range:** ff513e8..c75e9b7

---

## v1.0 Wizard Orchestrator (Shipped: 2026-03-13)

**Phases:** 12 phases (1-11 + 4.1), 17 plans | **Requirements:** 23/23 satisfied
**Timeline:** 2026-03-10 → 2026-03-13 (3 days)

**Key accomplishments:**
1. Built smart router skill with 5-scenario detection from wizard-state.json
2. Created interactive wizard with 4-scenario menus, 2-turn max to recommendation
3. Built backing agent with bridge-to-GSD route including traceability assertions
4. Added validate-phase, drift-check, and on-demand traceability display routes
5. Added context-reset continuity, IT safety injection, and health-monitor prompts
6. Built hardcoded catalog of all Keystone agents, skills, and hooks

**Tech debt carried forward:**
- bmad-ready Task prompt uses local-only path (low severity)
- Nyquist validation partial (10/12 compliant, 2 partial)
- 18 human verification items across 6 phases

---
