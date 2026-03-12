---
phase: 1
slug: schema-and-state-detection
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-11
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test harness (self-contained, no external runner) |
| **Config file** | none |
| **Quick run command** | `bash tests/test-wizard-detect.sh` |
| **Full suite command** | `bash tests/test-wizard-detect.sh` |
| **Estimated runtime** | ~10 seconds (27 tests across 4 requirements) |

---

## Sampling Rate

- **After every task commit:** Run `bash -n .claude/commands/wizard.md 2>&1`
- **After every plan wave:** Manual test against all 5 scenario states (none, bmad-only, gsd-only, full-stack, ambiguous)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds (syntax check); 60 seconds (manual)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | DETECT-01 | integration | `bash tests/test-wizard-detect.sh` (tests 1a-1f: 6 scenario classification) | tests/test-wizard-detect.sh | green |
| 01-01-02 | 01 | 1 | DETECT-02 | integration | `bash tests/test-wizard-detect.sh` (tests 2a-2d: dir+content cross-validation) | tests/test-wizard-detect.sh | green |
| 01-01-03 | 01 | 1 | DETECT-03 | integration | `bash tests/test-wizard-detect.sh` (tests 3a-3d: ambiguous triggers) | tests/test-wizard-detect.sh | green |
| 01-01-04 | 01 | 1 | DETECT-04 | integration | `bash tests/test-wizard-detect.sh` (tests 4a-4h: file-state ladder) | tests/test-wizard-detect.sh | green |
| 01-01-05 | 01 | 1 | DETECT-05 | manual-smoke | Fresh Claude Code session, invoke `/wizard` | N/A | manual-only |
| 01-01-06 | 01 | 1 | ROUTE-01 | manual-smoke | Type `/wizard` in Claude Code | N/A | manual-only |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `skills/wizard-router.md` — skill file (created this phase)
- [ ] `.claude/commands/wizard.md` — slash command entry point (created this phase)
- [ ] `skills/` directory — does not exist yet (created this phase)

*No test framework installation needed — pure bash, no npm test runner.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cold read from disk | DETECT-05 | Requires fresh Claude Code session | Open new session, invoke `/wizard`, verify JSON read from disk |
| `/wizard` invocable | ROUTE-01 | Requires Claude Code slash command resolution | Type `/wizard` in CLI, verify it resolves |

*DETECT-01 through DETECT-04 are now covered by automated tests in `tests/test-wizard-detect.sh`.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-11

---

## Validation Audit 2026-03-12

| Metric | Count |
|--------|-------|
| Gaps found | 4 |
| Resolved | 4 |
| Escalated | 0 |
| Manual-only | 2 |
| Total assertions | 27 |

**Test file:** `tests/test-wizard-detect.sh`
**Run command:** `bash tests/test-wizard-detect.sh`
