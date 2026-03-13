---
phase: 6
slug: recovery-safety-and-polish
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-12
validated: 2026-03-13
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — markdown skill + bash project, structural grep/bash checks only |
| **Config file** | None |
| **Quick run command** | `grep -q "Welcome back" skills/wizard-detect.sh && grep -q "IT Safety" skills/wizard-detect.sh && grep -q "uat-passing" skills/wizard.md && echo PASS` |
| **Full suite command** | All structural grep checks below + manual live flow verification |
| **Estimated runtime** | ~2 seconds (grep checks) |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run all structural checks (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 6-01-01 | 01 | 1 | RECOV-01 | structural | `grep -q "IS_RESET" skills/wizard-detect.sh && grep -q "ELAPSED" skills/wizard-detect.sh && echo PASS` | ✅ green |
| 6-01-02 | 01 | 1 | RECOV-01 | structural | `grep -q "Welcome back" skills/wizard-detect.sh && echo PASS` | ✅ green |
| 6-01-03 | 01 | 1 | RECOV-02 | structural | `grep -q "dry_run_required" skills/wizard-detect.sh && grep -q "auto_advance" skills/wizard-detect.sh && echo PASS` | ✅ green |
| 6-01-04 | 01 | 1 | RECOV-02 | structural | `grep -q "IT Safety" skills/wizard-detect.sh && echo PASS` | ✅ green |
| 6-01-05 | 01 | 1 | RECOV-03 | structural | `grep -q "uat-passing" skills/wizard.md && grep -q "Run health check" skills/wizard.md && echo PASS` | ✅ green |
| 6-01-06 | 01 | 1 | RECOV-03 | structural | `grep -B2 -A2 "Run health check" skills/wizard.md \| grep -q "context-health-monitor" && echo PASS` | ✅ green |
| 6-02-01 | 02 | 2 | RECOV-01,02,03 | automated | `TOTAL_CHARS=$(cat skills/wizard-detect.sh skills/wizard.md .claude/wizard-state.json 2>/dev/null \| wc -c \| tr -d ' ') && TOKENS=$((TOTAL_CHARS * 100 / 375)) && [ "$TOKENS" -lt 20000 ] && echo PASS` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `skills/wizard-detect.sh` — add IS_RESET detection block and status box lines (covers RECOV-01, RECOV-02 structural checks)
- [x] `skills/wizard-detect.sh` — add infra config write block (covers RECOV-02 structural checks)
- [x] `skills/wizard.md` — add uat-passing menu variant (covers RECOV-03 structural checks)

*All Wave 0 requirements satisfied — implementation complete in Plans 01 and 02.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| "Welcome back." appears in status box after >30s session gap | RECOV-01 | Requires live Claude Code context reset | 1. Run `/wizard` 2. Wait >30s 3. Run `/clear` then `/wizard` 4. Verify "Welcome back." in status box |
| IT Safety config injection on infra project | RECOV-02 | Requires infra project detection in live environment | 1. Set up project with infra keywords 2. Run `/wizard` 3. Check `.planning/config.json` for auto_advance:false + dry_run_required:true |
| Health check menu appears for uat-passing state | RECOV-03 | Requires uat-passing phase_status in wizard-state.json | 1. Set phase_status to "uat-passing" in wizard-state.json 2. Run `/wizard` 3. Verify "Run health check (Recommended)" is option 1 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved

---

## Validation Audit 2026-03-13

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All 7 automated checks pass. Token budget at ~12,796 tokens (64% of 20k budget). IS_RESET ordering verified (appears before JSON WRITE). Global deployment verified for wizard-detect.sh (wizard.md has local drift — operational, not a validation gap).
