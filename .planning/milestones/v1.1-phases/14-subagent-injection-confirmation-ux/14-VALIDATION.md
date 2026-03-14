---
phase: 14
slug: subagent-injection-confirmation-ux
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test suite (existing pattern in tests/) |
| **Config file** | `tests/test-wizard-detect.sh` (existing example to follow) |
| **Quick run command** | `bash tests/test-injection.sh` |
| **Full suite command** | `bash tests/test-wizard-detect.sh && bash tests/test-injection.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/test-injection.sh`
- **After every plan wave:** Run `bash tests/test-wizard-detect.sh && bash tests/test-injection.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | INJ-01 | smoke | `grep -q '<capabilities>' test output` | ❌ W0 | ⬜ pending |
| 14-01-02 | 01 | 1 | INJ-02 | smoke | text search in wizard-backing-agent.md | ❌ W0 | ⬜ pending |
| 14-01-03 | 01 | 1 | INJ-03 | manual | `wc -w sample-block.txt` (proxy) | ❌ W0 | ⬜ pending |
| 14-01-04 | 01 | 1 | INJ-04 | automated | `grep -n 'capabilities' skills/wizard.md \| grep -v Task\|Agent` | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 1 | CONF-01 | manual | Invoke wizard, select "Check drift", confirm no AskUserQuestion for known agents | ❌ W0 | ⬜ pending |
| 14-02-02 | 02 | 1 | CONF-02 | manual | Add fake unknown tool to by_stage, run wizard, verify single prompt | ❌ W0 | ⬜ pending |
| 14-02-03 | 02 | 1 | CONF-03 | automated | `grep 'configured — availability may vary' skills/wizard.md` | ❌ W0 | ⬜ pending |
| 14-03-01 | 03 | 1 | PERF-03 | automated | `grep 'toolkit-registry' skills/wizard.md skills/wizard-backing-agent.md` (expect 0) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test-injection.sh` — covers INJ-01 through INJ-04 and PERF-03 via text search assertions
- [ ] Sample capability block text file for `wc -w` INJ-03 estimation — can be inline in test

*Existing test infrastructure in `tests/test-wizard-detect.sh` covers wizard-detect.sh but not injection behavior.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Capability suffix not visible in wizard output | SC #1 | Requires live wizard invocation and UI observation | Run `/wizard`, select "Check drift", confirm no `<capabilities>` text appears in wizard turn |
| Known-safe tools inject without confirmation | CONF-01 | Requires live AskUserQuestion behavior check | Invoke wizard action that spawns Task(), confirm no confirmation prompt for known agents |
| Unknown tools get one batched prompt | CONF-02 | Requires fake unknown tool injection + live UI check | Add fake unknown tool to by_stage, run wizard, verify single AskUserQuestion |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
