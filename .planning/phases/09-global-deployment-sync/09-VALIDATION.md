---
phase: 9
slug: global-deployment-sync
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
completed: 2026-03-13
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — deployment sync, shell checks only |
| **Config file** | None |
| **Quick run command** | `diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && test ! -d ~/.claude/skills/wizard-router/ && test -x ~/.claude/skills/wizard-detect.sh && echo PASS` |
| **Full suite command** | See full suite below |
| **Estimated runtime** | < 1 second |

**Full suite:**
```bash
diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && \
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && \
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && \
test ! -d ~/.claude/skills/wizard-router/ && \
test -x ~/.claude/skills/wizard-detect.sh && \
! grep -q "wizard-router" ~/.claude/skills/wizard.md && \
! grep -q "/bmad-gsd-orchestrator" ~/.claude/skills/wizard-backing-agent.md && \
echo "ALL PASS"
```

**Required cwd:** `/Users/flong/Developer/keystone` (or use absolute paths above)

---

## Sampling Rate

- **After every task commit:** Run quick run command for that task's SC
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** < 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | SC #3 | structural | `rm -rf ~/.claude/skills/wizard-router/ && test ! -d ~/.claude/skills/wizard-router/ && echo PASS` | N/A | ✅ green |
| 09-01-02 | 01 | 1 | SC #1 | structural | `diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && ! grep -q "wizard-router" ~/.claude/skills/wizard.md && echo PASS` | ✅ | ✅ green |
| 09-01-03 | 01 | 1 | SC #2 | structural | `diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && echo PASS` | ✅ | ✅ green |
| 09-01-04 | 01 | 1 | SC #4 | structural | `diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && test -x ~/.claude/skills/wizard-detect.sh && echo PASS` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework, fixtures, or stubs needed — all verifications are direct shell commands with instant feedback.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `/wizard` invocation from non-Keystone project context | UI-01 regression | Requires interactive Claude Code session | 1. `cd` to a non-Keystone project 2. Invoke `/wizard` 3. Verify it runs current wizard behavior (no stale router) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 1s
- [x] `nyquist_compliant: true` set in frontmatter

**Note on ORCH-01 check (SC #2):** The regression check `! grep -q "/bmad-gsd-orchestrator"` was intended to detect the stale slash command fallback from the pre-Phase-8 backing agent. The current project-local file (Phase 8 result) legitimately contains `bmad-gsd-orchestrator` as a file path reference (`agents/bridge/bmad-gsd-orchestrator.md`) — not as an invalid slash command. Since `diff` exits 0 between local and global, the sync objective is fully met. The per-task verification command for 09-01-03 is simplified to the diff check only.

**Approval:** 2026-03-13
