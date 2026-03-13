---
phase: 8
slug: bridge-path-fix-and-cleanup
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — markdown skill project, structural grep checks only |
| **Config file** | None |
| **Quick run command** | `test -f agents/bridge/bmad-gsd-orchestrator.md && grep -q "_bmad-output" agents/bridge/bmad-gsd-orchestrator.md && echo PASS` |
| **Full suite command** | `grep -q "_bmad-output" agents/bridge/bmad-gsd-orchestrator.md && grep -qv "/bmad-gsd-orchestrator" skills/wizard-backing-agent.md && test ! -f skills/wizard-router.md && grep -qv "bmad-only" .claude/settings.local.json && grep -q "Route B" skills/wizard-backing-agent.md && grep -q "Route C" skills/wizard-backing-agent.md && echo "ALL PASS"` |
| **Estimated runtime** | ~1 second |

---

## Sampling Rate

- **After every task commit:** Run the structural check for that SC (see Per-Task map below)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | SC | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | SC #1 | structural | `grep -q "_bmad-output" agents/bridge/bmad-gsd-orchestrator.md && echo PASS` | ✅ | ✅ green |
| 08-01-02 | 01 | 1 | SC #2 | structural | `grep -qv "/bmad-gsd-orchestrator" skills/wizard-backing-agent.md && echo PASS` | ✅ | ✅ green |
| 08-01-03 | 01 | 1 | SC #3 | structural | `test ! -f skills/wizard-router.md && ! grep -q "wizard-router" skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 08-01-04 | 01 | 1 | SC #4 | structural | `grep -qv "bmad-only" .claude/settings.local.json && echo PASS` | ✅ | ✅ green |
| 08-01-05 | 01 | 1 | SC #6 | structural | `grep -q "Route B" skills/wizard-backing-agent.md && grep -q "Route C" skills/wizard-backing-agent.md && echo PASS` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No framework installation required. Pure edit-and-delete phase.*

---

## Manual-Only Verifications

| Behavior | SC | Why Manual | Test Instructions |
|----------|----|------------|-------------------|
| Bridge flow completes on `_bmad-output/` project | SC #1 | Requires external project with `_bmad-output/` structure | Run `/wizard` on a project that has `_bmad-output/planning-artifacts/` with PRD and architecture files; verify bridge operation A passes completeness gate |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 1s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** green — 2026-03-13 (Nyquist audit)

## Validation Audit 2026-03-13 (Nyquist gap fill)

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

**Audit notes:**
- SC #3 catalog cleanup regression: commit c20ae6b (Phase 7 validation) re-added 4 `wizard-router` catalog entries to `skills/wizard.md` that eac157b (Phase 8) had deleted.
- Fix: removed all 4 occurrences of `- **wizard-router** -- Silent entry point that routes to wizard -- /wizard` from wizard.md using replace_all.
- Verification command `grep -q "wizard-router" skills/wizard.md` now returns PASS (no match).
- Full suite command from Test Infrastructure table also confirmed ALL PASS after fix.
- 08-01-03 command updated to also check `! grep -q "wizard-router" skills/wizard.md` (the catalog half of SC #3, previously absent from the map).
