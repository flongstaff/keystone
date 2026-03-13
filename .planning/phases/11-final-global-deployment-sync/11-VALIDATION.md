---
phase: 11
slug: final-global-deployment-sync
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
approved: 2026-03-13
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — deployment sync + one-line text fix, shell checks only |
| **Config file** | None |
| **Quick run command** | `diff /Users/flong/Developer/keystone/skills/wizard.md /Users/flong/.claude/skills/wizard.md && test -x /Users/flong/.claude/skills/wizard-detect.sh && echo PASS` |
| **Full suite command** | `diff /Users/flong/Developer/keystone/skills/wizard.md /Users/flong/.claude/skills/wizard.md && diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md /Users/flong/.claude/skills/wizard-backing-agent.md && diff /Users/flong/Developer/keystone/skills/wizard-detect.sh /Users/flong/.claude/skills/wizard-detect.sh && test -x /Users/flong/.claude/skills/wizard-detect.sh && grep -q 'Option 3 (Validate phase)' /Users/flong/.claude/skills/wizard.md && echo ALL_PASS` |
| **Estimated runtime** | < 1 second |

---

## Sampling Rate

- **After every task commit:** Run the verification command for that specific SC
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** < 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | SC #1 | structural | `grep -q 'Option 3 (Validate phase)' skills/wizard.md && echo PASS` | ✅ (post-edit) | ✅ green |
| 11-01-02 | 01 | 1 | SC #3 | structural | `cp -p skills/wizard.md ~/.claude/skills/wizard.md && diff skills/wizard.md ~/.claude/skills/wizard.md && echo PASS` | ✅ (post-copy) | ✅ green |
| 11-01-03 | 01 | 1 | SC #4 | structural | `cp -p skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && diff skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && echo PASS` | ✅ (post-copy) | ✅ green |
| 11-01-04 | 01 | 1 | SC #2 | structural | `cp -p skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && diff skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && test -x ~/.claude/skills/wizard-detect.sh && echo PASS` | ✅ (post-copy) | ✅ green |
| 11-01-05 | 01 | 1 | SC #5 | structural | Full suite command (all diffs + grep + executable check) | ✅ (composite) | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework, fixtures, or stubs needed — operations are direct shell commands with instant feedback.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 1s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-03-13
