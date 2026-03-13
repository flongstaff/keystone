---
phase: 5
slug: full-agent-routing
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-12
validated: 2026-03-13
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — markdown skill project, structural grep checks only |
| **Config file** | None |
| **Quick run command** | `grep -q "Check drift" skills/wizard.md && grep -q "Route C" skills/wizard-backing-agent.md && echo PASS` |
| **Full suite command** | Manual: invoke wizard in full-stack project, verify 4-option menu appears; select "Show traceability," verify Route C output |
| **Estimated runtime** | ~2 seconds (structural checks); ~60 seconds (manual live flow) |

---

## Sampling Rate

- **After every task commit:** Run `grep -q "Check drift" skills/wizard.md && grep -q "Route C" skills/wizard-backing-agent.md && echo PASS`
- **After every plan wave:** Run full structural suite (all grep checks below)
- **Before `/gsd:verify-work`:** Full suite must be green + manual live flow verification
- **Max feedback latency:** 2 seconds (structural)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | ORCH-04 | structural | `grep -q "phase-gate-validator" skills/wizard.md && echo PASS` | n/a | ✅ green |
| 05-01-02 | 01 | 1 | ORCH-04 | structural | `grep -v "summarize\|reformat" skills/wizard.md \| grep -q "phase-gate-validator" && echo PASS` | n/a | ✅ green |
| 05-01-03 | 01 | 1 | TRACE-03 | structural | `grep -q "traceability" skills/wizard.md && echo PASS` | n/a | ✅ green |
| 05-02-01 | 02 | 1 | TRACE-03 | structural | `grep -q "Route C" skills/wizard-backing-agent.md && echo PASS` | n/a | ✅ green |
| 05-02-02 | 02 | 1 | TRACE-03 | structural | `sed -n '/Route C — Traceability Display/,/^## /p' skills/wizard-backing-agent.md \| grep -q "story-" && echo PASS` | n/a | ✅ green |
| 05-02-03 | 02 | 1 | TRACE-03 | structural | `grep -q "VERIFICATION\|complete\|planning" skills/wizard-backing-agent.md && echo PASS` | n/a | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `skills/wizard.md` — add post-status AskUserQuestion menus to full-stack and gsd-only blocks
- [x] `skills/wizard-backing-agent.md` — add Route C (traceability display) after Route B; fix Task tool declaration in YAML frontmatter
- [x] `~/.claude/skills/wizard.md` — redeploy updated version
- [x] `~/.claude/skills/wizard-backing-agent.md` — redeploy updated version with Route C

*No framework installation needed — pure markdown edits*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 4-option menu appears in full-stack scenario | ORCH-04, TRACE-03 | Requires live wizard invocation in a full-stack project | 1. Set up project with both BMAD + GSD, 2. Run /wizard, 3. Verify post-status prompt shows Continue, Check drift, Show traceability, Validate phase |
| Selecting "Check drift" invokes context-health-monitor and displays unmodified report | ORCH-04 | Agent delegation requires live invocation | 1. From wizard menu select "Check drift", 2. Verify context-health-monitor 5-check report appears, 3. Confirm no reformatting |
| Selecting "Show traceability" invokes Route C and displays per-phase AC mapping | TRACE-03 | Route C requires live story files and phase directories | 1. From wizard menu select "Show traceability", 2. Verify output groups ACs by GSD phase with completion status, 3. Verify deferred criteria shown separately |
| Selecting "Validate phase" invokes phase-gate-validator with exact fix commands | ORCH-04 | Gate validation requires live phase state | 1. From wizard menu select "Validate phase", 2. Verify PASS/WARN/FAIL verdicts appear, 3. Confirm fix commands are present for failures |
| Menu re-presentation after secondary option | ORCH-04 | Loop behavior requires interactive testing | 1. Select "Check drift", 2. After report displays, verify same 4-option menu reappears, 3. Select "Continue", verify flow proceeds |

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

## Validation Audit 2026-03-13

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

**Details:** Task 05-02-02 had a false-negative test command (`grep -A 3` window too narrow to reach `story-*.md` in Route C section). Fixed by replacing with `sed -n` section extraction. Implementation was correct — only the validation command needed updating.
