---
phase: 15
slug: dynamic-catalog-display
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification (no automated test suite in this project) |
| **Config file** | none |
| **Quick run command** | Read wizard.md and confirm Option 4 handlers redirect to shared block |
| **Full suite command** | Per success criteria: count match, grouping, fallback, parity |
| **Estimated runtime** | ~30 seconds (manual inspection) |

---

## Sampling Rate

- **After every task commit:** Review modified wizard.md section for instruction correctness
- **After every plan wave:** Execute success criteria 1-4 from CONTEXT.md against live wizard invocation
- **Before `/gsd:verify-work`:** All 4 success criteria pass
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | CAT-01, CAT-02, CAT-03 | grep-verify | `grep -c "^## Display Catalog$" skills/wizard.md` | ✅ | ⬜ pending |
| 15-01-02 | 01 | 1 | CAT-01, CAT-02, CAT-03 | grep-verify | Parity + dedup + redirect count checks | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Plan tasks use grep-based automated verification against wizard.md content, which requires no additional framework.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| "Discover tools" reads toolkit-registry.json and displays tool count matching installed agents | CAT-01 | Requires live wizard invocation | Run `/wizard` → select "Discover tools" → verify tool count matches `ls ~/.claude/agents/ \| wc -l` |
| Tools grouped by stage relevance (research/planning/execution/review) then category | CAT-02 | Requires visual inspection of output grouping | Run `/wizard` → select "Discover tools" → confirm stage-first grouping |
| Fresh install shows hardcoded fallback without errors | CAT-03 | Requires registry absence simulation | Rename `.claude/toolkit-registry.json` → invoke Option 4 → confirm fallback displays without error |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
