---
phase: 16
slug: global-deployment-sync
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — deployment sync, shell checks only |
| **Config file** | None |
| **Quick run command** | `diff /Users/flong/Developer/keystone/skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh && test -x ~/.claude/skills/toolkit-discovery.sh && echo PASS` |
| **Full suite command** | `diff /Users/flong/Developer/keystone/skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh && diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && test -x ~/.claude/skills/toolkit-discovery.sh && test -x ~/.claude/skills/wizard-detect.sh && grep -q "toolkit-registry.json" /Users/flong/Developer/keystone/.gitignore && echo "ALL PASS"` |
| **Estimated runtime** | < 5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command for that specific SC
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | SC #1-3 | structural | `cp -p` 4 files then `diff` all 4 | ✅ | ⬜ pending |
| 16-01-02 | 01 | 1 | SC #1-2 | structural | `test -x ~/.claude/skills/toolkit-discovery.sh && test -x ~/.claude/skills/wizard-detect.sh` | ✅ | ⬜ pending |
| 16-01-03 | 01 | 1 | SC #4 | functional | `cd /tmp && bash ~/.claude/skills/wizard-detect.sh && python3 -c "import json; s=json.load(open('.claude/wizard-state.json')); assert s['toolkit']['counts']['agents'] > 0"` | ✅ | ⬜ pending |
| 16-01-04 | 01 | 1 | SC #5 | gitignore | `grep -q "toolkit-registry.json" .gitignore && ! git status --short \| grep -q toolkit && echo PASS` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework, fixtures, or stubs needed — all verifications are direct shell commands.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `/wizard` from non-Keystone project discovers `~/.claude/agents/` | SC #4 | Requires interactive Claude Code invocation outside Keystone | 1. Open a non-Keystone project directory 2. Run `/wizard` 3. Verify toolkit discovery section appears in wizard output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
