---
phase: 2
slug: wizard-ui-layer
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-12
audited: 2026-03-12
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — markdown skill project, no automated test runner |
| **Config file** | None — structural grep checks only |
| **Quick run command** | `test -f skills/wizard.md && grep -q "AskUserQuestion" skills/wizard.md && echo PASS` |
| **Full suite command** | Manual: invoke `/wizard` against controlled project states for each of 6 scenarios |
| **Estimated runtime** | ~2 seconds (structural); ~5 minutes (manual full suite) |

---

## Sampling Rate

- **After every task commit:** Run `test -f skills/wizard.md && grep -q "scenario" skills/wizard.md && echo PASS`
- **After every plan wave:** Manual test against all 6 scenario states (none, bmad-ready, bmad-incomplete, gsd-only, full-stack, ambiguous) with Explain tested on at least 2 scenarios
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds (structural checks)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | UI-01 | structural | `grep -q "bmad-ready" skills/wizard.md && grep -q "bmad-incomplete" skills/wizard.md && grep -q "full-stack" skills/wizard.md && grep -q "gsd-only" skills/wizard.md && grep -qw "none" skills/wizard.md && grep -q "ambiguous" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 02-01-02 | 01 | 1 | UI-03 | structural | `test -f skills/wizard.md && ! grep -q "^@" skills/wizard.md && echo PASS` (no @-file references) | ✅ | ✅ green |
| 02-01-03 | 01 | 1 | UI-04 | structural | `grep -q "Explain" skills/wizard.md && grep -q "WITHOUT.*Explain" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 02-01-04 | 01 | 1 | UI-04 | manual-smoke | Invoke /wizard on none-scenario, pick Explain, confirm re-present | — | ✅ green |
| 02-02-01 | 01 | 1 | UI-02 | structural | `grep -q "auto-invoke" skills/wizard.md && grep -q "AskUserQuestion" skills/wizard.md && echo PASS` (0-turn auto-invoke + 1-turn menu) | ✅ | ✅ green |
| 02-02-02 | 01 | 2 | ROUTE-02 | structural | `grep -q "skills/wizard.md" .claude/commands/wizard.md && echo PASS` | ✅ | ✅ green |
| 02-02-03 | 01 | 2 | ROUTE-02 | structural | `grep -q "next_command" skills/wizard.md && grep -q 'Run:' skills/wizard.md && echo PASS` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `skills/wizard.md` — created with 6 scenario blocks (bmad-only split into bmad-ready/bmad-incomplete)
- [x] Updated `.claude/commands/wizard.md` — rebound to skills/wizard.md
- [x] Test scenario scratch directories — documented in UAT checklist for each of 6 scenarios

*No test framework installation needed — pure markdown, no npm test runner*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Scenario-appropriate menus display correctly | UI-01 | AskUserQuestion rendering cannot be tested outside Claude Code | Invoke /wizard in 6 different project states (none, bmad-ready, bmad-incomplete, gsd-only, full-stack, ambiguous), verify each shows correct menu |
| 0-turn for full-stack/gsd-only | UI-02 | Requires live Claude Code interaction | Create project with ROADMAP.md, invoke /wizard, confirm no menu before command display |
| 1-turn for none scenario | UI-02 | Requires live Claude Code interaction | Empty project dir, invoke /wizard, confirm 1 menu then auto-action |
| Explain mode free side-channel | UI-04 | Requires live AskUserQuestion interaction | Pick Explain, confirm same menu re-presented without Explain option |
| Literal next_command display | ROUTE-02 | Requires live wizard-state.json reading | Verify exact command text in wizard output matches JSON |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete

---

## Validation Audit 2026-03-12

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

**Notes:** Original VALIDATION.md referenced `bmad-only` scenario name from design spec. Implementation correctly split this into `bmad-ready` (bridge available) and `bmad-incomplete` (bridge not available) — 6 scenarios total, improving UX. Updated all structural grep checks and task IDs to match actual implementation.
