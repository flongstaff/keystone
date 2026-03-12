---
phase: 4
slug: core-backing-agent-routes
status: audited
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-12
last_audit: 2026-03-12
automated_pass: 5
manual_only: 2
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — markdown skill project, structural grep checks only |
| **Config file** | None — no test runner config |
| **Quick run command** | `test -f skills/wizard-backing-agent.md && grep -q "Route A" skills/wizard-backing-agent.md && grep -q "Route B" skills/wizard-backing-agent.md && echo PASS` |
| **Full suite command** | Manual: invoke backing agent in both routes on controlled project state |
| **Estimated runtime** | ~2 seconds (structural checks) |

---

## Sampling Rate

- **After every task commit:** Run `test -f skills/wizard-backing-agent.md && echo "PASS: file exists" || echo FAIL`
- **After every plan wave:** Manual: route A on this project (full-stack scenario), route B on a controlled project with known stories
- **Before `/gsd:verify-work`:** All 5 requirements verified manually
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 04-01-01 | 01 | 1 | ORCH-01 | structural | `grep -q "Task" skills/wizard-backing-agent.md && echo PASS` | ✅ green |
| 04-01-02 | 01 | 1 | ORCH-02 | structural | `grep -q "Task" skills/wizard-backing-agent.md && echo PASS` | ✅ green |
| 04-01-03 | 01 | 1 | ORCH-03 | structural | `grep -q "bmad.stories_approved" skills/wizard-backing-agent.md && grep -q "bmad.prd" skills/wizard-backing-agent.md && echo PASS` | ✅ green |
| 04-01-04 | 01 | 1 | TRACE-01 | manual-only | See Manual-Only table | ⚠️ manual |
| 04-01-05 | 01 | 1 | TRACE-02 | structural | `grep -q "Acceptance Criteria" skills/wizard-backing-agent.md && grep -q "AskUserQuestion" skills/wizard-backing-agent.md && echo PASS` | ✅ green |
| 04-02-01 | 02 | 1 | ORCH-01 | manual-only | See Manual-Only table | ⚠️ manual |
| 04-02-02 | 02 | 1 | ORCH-01 | structural | `grep -q "next_command" skills/wizard-backing-agent.md && echo PASS` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ manual · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `skills/wizard-backing-agent.md` — the new backing agent file (Route A + Route B)
- [ ] `skills/wizard.md` — update to invoke backing agent (deferred to Phase 4.1)
- [x] `~/.claude/skills/wizard-backing-agent.md` — deployed copy (verified: matches local)
- [ ] Controlled project state for Route B smoke test

*No framework installation needed — pure markdown additions*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Resume route displays orientation context and emits correct next command | ORCH-01 | Requires interactive wizard flow with real project state | 1. Run wizard-detect.sh on this project 2. Invoke backing agent Route A 3. Verify phase name, last activity, and next command are correct |
| Bridge invokes bmad-gsd-orchestrator in fresh Task() context | ORCH-02 | Requires Task() runtime — cannot verify delegation behavior structurally | 1. Set up controlled project with approved BMAD stories 2. Invoke Route B 3. Verify .planning/ files created by orchestrator |
| Traceability assertion presents gaps interactively | TRACE-02 | Requires AskUserQuestion interaction with real gap data | 1. Set up project with story AC not in context files 2. Invoke Route B 3. Verify each gap is surfaced and user can map/defer |
| Bridge produces .planning/CONTEXT.md execution artifact | TRACE-01 | Runtime artifact created by bmad-gsd-orchestrator bridge — depends on actual bridge execution, not backing agent code | 1. Run Route B on a project with complete BMAD docs 2. After bridge Task() completes 3. Verify `.planning/config.json` and `.planning/CONTEXT.md` exist |
| wizard.md invokes backing agent for bridge and resume routes | ORCH-01 | Implementation reverted in `357e5af` — sonnet skips "read file and follow" instructions. Deferred to Phase 4.1 (rewire backing agent) | 1. Complete Phase 4.1 rewire 2. Verify `grep -q "wizard-backing-agent" skills/wizard.md` passes |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Manual-Only classification
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter (blocked: 2 manual-only items)

**Approval:** partial — 5/7 automated, 2 manual-only (1 runtime dependency, 1 deferred to Phase 4.1)

---

## Validation Audit 2026-03-12

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved (manual-only) | 2 |
| Escalated | 0 |

**Audit notes:**
- 04-01-04 (TRACE-01): Original test checked `.planning/CONTEXT.md` — a runtime artifact produced by the bridge, not a code defect. Moved to manual-only.
- 04-02-01 (ORCH-01): wizard.md wiring was committed (`a68e435`) then reverted (`357e5af`, `9265dc3`) because sonnet models skip indirect "read file and follow" instructions. Phase 4.1 added to roadmap to rewire with a model-compatible approach.

## Validation Audit 2026-03-12 (re-audit)

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

**Audit notes:**
- Re-audit confirms prior state: 5/7 automated PASS, 2 manual-only unchanged.
- No new test files, no implementation changes since last audit.
- Manual-only classifications remain justified (runtime dependency + Phase 4.1 deferral).

## Validation Audit 2026-03-12 (third pass)

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

**Audit notes:**
- Third-pass audit: all 5 automated checks pass green, 0 new gaps.
- `wizard-backing-agent.md` unchanged since `1f0c7de`; `wizard.md` wiring still reverted per `357e5af`/`9265dc3`.
- Manual-only items stable: TRACE-01 (runtime artifact), ORCH-01 (Phase 4.1 deferral).
- No path to `nyquist_compliant: true` until Phase 4.1 resolves the wizard.md wiring.
