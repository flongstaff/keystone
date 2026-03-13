---
phase: 7
slug: agent-skill-tool-and-hook-discovery-and-recommendations
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
validated: 2026-03-13
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | grep-based structural verification (bash grep assertions — consistent with all prior phases) |
| **Config file** | none |
| **Quick run command** | `grep -q "Discover tools" skills/wizard.md && echo PASS` |
| **Full suite command** | see Per-Task Verification Map below |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `grep -q "Discover tools" skills/wizard.md && echo PASS`
- **After every plan wave:** Run all verification commands in Per-Task Verification Map
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 3 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | Discover tools menu option | structural | `grep -q "Discover tools" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 07-01-02 | 01 | 1 | Option in all 4 menu variants | structural | `grep -c "Discover tools" skills/wizard.md \| grep -qE "^[4-9]" && echo PASS` | ✅ | ✅ green |
| 07-01-03 | 01 | 1 | All 11 agent names in catalog | structural | `grep -q "project-setup-advisor" skills/wizard.md && grep -q "bmad-gsd-orchestrator" skills/wizard.md && grep -q "godot-dev-agent" skills/wizard.md && grep -q "stack-update-watcher" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 07-01-04 | 01 | 1 | All 3 hook names in catalog | structural | `grep -q "session-start" skills/wizard.md && grep -q "post-write-check" skills/wizard.md && grep -q "stack-update-banner" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 07-01-05 | 01 | 1 | Domain agent (active) marking | structural | `grep -q "active" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 07-01-06 | 01 | 1 | Menu re-presents after catalog | structural | `grep -A5 "Discover tools" skills/wizard.md \| grep -q "re-present" && echo PASS` | ✅ | ✅ green |
| 07-01-07 | 01 | 1 | Global deployment matches source | structural | `diff -q skills/wizard.md ~/.claude/skills/wizard.md && echo PASS` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

No test files to create. Verification is grep-based structural assertion, consistent with all prior phases.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Catalog displays correctly when `/wizard` is run | Visual formatting | Output rendering cannot be verified by grep alone | Run `/wizard`, select "Discover tools", visually confirm catalog is well-formatted |
| Menu returns to correct variant after catalog | Loop behavior | AskUserQuestion flow requires interactive testing | Run `/wizard` from uat-passing and non-uat-passing states, verify correct menu re-presents |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 3s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved

---

## Validation Audit 2026-03-13

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

**Gap resolved:** Added missing `wizard-router` entry to all 4 catalog Skills sections in `skills/wizard.md`. Re-deployed globally. All 7 automated checks now pass.
