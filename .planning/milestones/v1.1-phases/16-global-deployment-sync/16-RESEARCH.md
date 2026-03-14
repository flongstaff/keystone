# Phase 16: Global Deployment Sync - Research

**Researched:** 2026-03-14
**Domain:** Shell file deployment — copy 4 skill files to `~/.claude/skills/`, verify path resolution, confirm gitignore
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**File set and deployment location:**
- 4 files deployed to `~/.claude/skills/` flat (same directory):
  1. `toolkit-discovery.sh` (NEW — does not exist globally yet)
  2. `wizard-detect.sh` (v1.1 changes: toolkit discovery call, toolkit JSON write)
  3. `wizard.md` (v1.1 changes: Step 2.5 injection block, dynamic catalog display)
  4. `wizard-backing-agent.md` (v1.1 changes: Step 2.5 bridge capability block)
- Sync all 4 files regardless of individual diff size — idempotent, prevents drift
- `cp -p` preserves permissions (executable bit for .sh files)
- No selective sync — copy everything, verify everything

**Path resolution verification:**
- wizard-detect.sh uses `SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)` to locate toolkit-discovery.sh
- Explicitly verify this resolves correctly from `~/.claude/skills/` context (not just project-local)
- Test: run `wizard-detect.sh` from a non-Keystone directory and confirm toolkit-discovery.sh is found

**Cross-project functional test:**
- Two-step manual bash test from /tmp (or any non-Keystone directory):
  1. Run `bash ~/.claude/skills/toolkit-discovery.sh` standalone — verify it finds `~/.claude/agents/` and produces valid JSON with correct counts
  2. Run `bash ~/.claude/skills/wizard-detect.sh` — verify `wizard-state.json` contains `toolkit` object with discovery counts matching step 1
- toolkit-registry.json writes to the calling project's `.claude/` directory (alongside wizard-state.json)
- Test cleanup: Claude's discretion

**Post-sync verification (carried from Phase 9/11):**
- `diff` between each project-local and global file — expect zero output for all 4 files
- `test -x ~/.claude/skills/wizard-detect.sh` — executable bit preserved
- `test -x ~/.claude/skills/toolkit-discovery.sh` — executable bit preserved (new file)

**Gitignore:**
- Project-level `.gitignore` is sufficient (already contains `toolkit-registry.json` entry)
- Verify-only — no changes needed. Confirm:
  1. `toolkit-registry.json` appears in `.gitignore`
  2. `toolkit-registry.json` does not appear in `git status` output

**Milestone closure:**
- NOT included in Phase 16 plan — separate `/gsd:complete-milestone` invocation after verification
- Phase 16 next-steps should note: "After verification passes, run `/gsd:complete-milestone` to close v1.1"
- No v1.1 regression smoke test — each prior phase verified its own features; Phase 16 scope is deployment sync only

### Claude's Discretion

- Exact task breakdown and wave structure
- VERIFICATION.md format and additional assertions beyond core checks
- Test artifact cleanup approach (remove /tmp test files or leave for OS cleanup)
- Whether to combine all operations into a single plan or split

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 16 is the third (and final) global deployment sync of the Keystone project. It copies 4 v1.1 skill files from project-local `skills/` to `~/.claude/skills/`, verifies cross-project path resolution for the newly deployed `toolkit-discovery.sh`, and confirms `toolkit-registry.json` is gitignored. No new capabilities are added — this is pure deployment sync.

The critical difference from Phase 9 and 11 is the addition of `toolkit-discovery.sh`, which is a genuinely new global file (not an update to an existing global). The `SCRIPT_DIR` pattern in `wizard-detect.sh` (`cd "$(dirname "$0")" && pwd`) resolves correctly relative to the script's location, meaning once `toolkit-discovery.sh` is deployed alongside `wizard-detect.sh` in `~/.claude/skills/`, the relative path invocation will find it. This is the only non-trivial verification: confirming the two shell scripts discover each other correctly when run from outside the Keystone project directory.

Live inspection confirms the current diff state: all 4 files differ between local and global. `toolkit-discovery.sh` is entirely absent from global (new file). `wizard-detect.sh` has ~34 diff lines (toolkit discovery integration block). `wizard.md` has ~468 diff lines (Step 2.5 injection block and dynamic catalog). `wizard-backing-agent.md` has ~29 diff lines (Step 2.5 bridge capability block). The gitignore entry exists at line 38 and `toolkit-registry.json` does not appear in `git status` (confirmed — file exists in `.claude/` but is properly ignored).

**Primary recommendation:** Single plan, single wave — copy all 4 files with `cp -p`, run the path resolution test from /tmp, run all diff/executable assertions. All operations take under 5 seconds and have no complex interdependencies.

---

## Current State (verified by live inspection, 2026-03-14)

### Global vs. Local diff summary

| File | Status | Detail |
|------|--------|--------|
| `skills/toolkit-discovery.sh` → `~/.claude/skills/toolkit-discovery.sh` | **ABSENT GLOBALLY** | New file — does not exist at global path |
| `skills/wizard-detect.sh` → `~/.claude/skills/wizard-detect.sh` | **DIFFERS** | ~34 diff lines — toolkit discovery block (SCRIPT_DIR, TOOLKIT_JSON, TOOLKIT_LINE extraction, toolkit status box line, JSON write) |
| `skills/wizard.md` → `~/.claude/skills/wizard.md` | **DIFFERS** | ~468 diff lines — Step 2.5 block (~80 lines), Build Capability Block helper (~35 lines), dynamic catalog display changes |
| `skills/wizard-backing-agent.md` → `~/.claude/skills/wizard-backing-agent.md` | **DIFFERS** | ~29 diff lines — Step 2.5 bridge capability block (~22 lines), prompt update |

### Permission state

| File | Local permissions | Global permissions | Note |
|------|------------------|--------------------|------|
| `toolkit-discovery.sh` | `-rwxr-xr-x@` (executable) | N/A (absent) | Must land executable |
| `wizard-detect.sh` | `-rwxr-xr-x@` (executable) | `-rwxr-xr-x@` (executable) | `cp -p` preserves |
| `wizard.md` | `-rw-r--r--@` (normal) | `-rw-r--r--@` (normal) | No special permissions needed |
| `wizard-backing-agent.md` | `-rw-r--r--@` (normal) | `-rw-r--r--@` (normal) | No special permissions needed |

### Gitignore state

| Item | Status |
|------|--------|
| `toolkit-registry.json` in `.gitignore` | YES — line 38: `toolkit-registry.json` |
| `toolkit-registry.json` in `git status` | NOT PRESENT — file exists in `.claude/` but correctly ignored |

### Path resolution behavior (SCRIPT_DIR pattern)

`wizard-detect.sh` line 283-284:
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_JSON=$(bash "$SCRIPT_DIR/toolkit-discovery.sh" 2>/dev/null)
```

When `wizard-detect.sh` is invoked via `bash ~/.claude/skills/wizard-detect.sh`:
- `$0` = `/Users/flong/.claude/skills/wizard-detect.sh`
- `dirname "$0"` = `/Users/flong/.claude/skills`
- `SCRIPT_DIR` = `/Users/flong/.claude/skills`
- Invoked path = `/Users/flong/.claude/skills/toolkit-discovery.sh`

This resolves correctly once `toolkit-discovery.sh` is deployed to `~/.claude/skills/`. No path change needed in the script.

### Cross-project test environment

- `~/.claude/agents/` exists and contains 176 agents
- `~/.claude/skills/` exists (the deployment target)
- `~/.claude/hooks/` exists (scanned by toolkit-discovery.sh)
- Running from `/tmp` provides a clean non-Keystone test context

---

## Standard Stack

### Core

| Operation | Command | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| File copy | `cp -p skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh` | Deploy new file with permission preservation | `-p` preserves executable bit from local copy |
| File copy | `cp -p skills/[file] ~/.claude/skills/[file]` | Sync 3 updated files | Idempotent, byte-for-byte copy |
| Diff check | `diff skills/[file] ~/.claude/skills/[file]` | Verify zero delta post-sync | Exit 0 = match; standard verification pattern from Phase 9/11 |
| Permission check | `test -x ~/.claude/skills/wizard-detect.sh` | Confirm executable bit survived | Guards against silent permission loss |
| Permission check | `test -x ~/.claude/skills/toolkit-discovery.sh` | Confirm executable bit survived (new file) | Same guard for new file |
| Gitignore check | `grep "toolkit-registry.json" .gitignore` | Confirm entry exists | Verify-only — no changes expected |
| Git status check | `git status --short \| grep toolkit` | Confirm file not tracked | Exit with no output = ignored |

### No Supporting Libraries Needed

POSIX shell built-ins and standard Unix tools only. No npm, Python, or framework dependencies.

**Installation:** None required.

---

## Architecture Patterns

### Recommended Plan Structure

```
16-01-PLAN.md   (single plan)
  Wave 1:
    Task 16-01-01  cp -p all 4 files from local → global (~/.claude/skills/)
    Task 16-01-02  diff assertions: all 4 files match (zero output expected)
    Task 16-01-03  executable bit checks: toolkit-discovery.sh + wizard-detect.sh
    Task 16-01-04  cross-project path resolution test from /tmp
    Task 16-01-05  gitignore verification (grep + git status)

16-VERIFICATION.md (repeatable audit commands, modeled on Phase 9/11)
```

### Pattern: Copy-all, then verify-all

**What:** Copy all 4 files unconditionally, then run all verification assertions.
**When to use:** When files are sources of truth in local and all should land at global.
**Rationale from CONTEXT.md:** "No selective sync — copy everything, verify everything." Idempotent; prevents drift from partial syncs.

### Pattern: Absolute paths for global targets

**What:** All commands targeting `~/.claude/skills/` use unquoted `~` or `$HOME`, never quoted `"~"`.
**Why:** Quoting suppresses tilde expansion in bash/zsh. Running from project root — relative paths resolve into `skills/`, not `~/.claude/skills/`.

### Pattern: SCRIPT_DIR for co-located script discovery

**What:** `wizard-detect.sh` uses `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` to locate `toolkit-discovery.sh` in the same directory.
**Why:** Enables the scripts to work correctly whether deployed at `skills/` (project-local) or `~/.claude/skills/` (global) without path changes.
**Cross-project test:** Run `bash ~/.claude/skills/wizard-detect.sh` from `/tmp` — `SCRIPT_DIR` resolves to `/Users/flong/.claude/skills/`, finds `toolkit-discovery.sh` there.

### Pattern: /tmp for cross-project functional test

**What:** `cd /tmp` before running the functional test so `wizard-state.json` and `toolkit-registry.json` write to `/tmp/.claude/` rather than the Keystone project directory.
**Why:** Test verifies global path behavior, not project-local fallbacks.
**Expected side effect:** `/tmp/.claude/` directory created. Cleanup is at Claude's discretion (OS will reclaim on reboot).

### Anti-Patterns to Avoid

- **Quoting the tilde:** `"~/.claude/..."` does not expand. Use unquoted `~` or `$HOME`.
- **Source/destination reversal:** `cp -p ~/.claude/skills/wizard.md skills/wizard.md` overwrites source of truth with stale global. Always local → global.
- **Selective sync:** Copying only files that differ violates the locked "copy everything" decision and creates drift risk on future phases.
- **Running functional test from Keystone directory:** `SCRIPT_DIR` would resolve to project-local `skills/`, masking any global path failure.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Permission preservation | `chmod +x` after copy | `cp -p` | Single flag handles permissions, timestamps, and xattrs |
| Content verification | md5sum / sha256sum | `diff` | Exits 1 on any difference; output identifies specific changed lines |
| Existence check before copy | `if [ ! -f ]; then cp` | `cp -p` unconditionally | Copy is idempotent; checking adds noise, not safety |
| Deploy automation | Bash script with error handling | Inline task commands | One-off sync; automation overhead not justified for 4 file copies |
| Path discovery | Hardcoded absolute paths in wizard-detect.sh | SCRIPT_DIR pattern (already in place) | Scripts already use relative co-location — no changes needed |

---

## Common Pitfalls

### Pitfall 1: Source/destination path reversal

**What goes wrong:** `cp -p ~/.claude/skills/wizard.md skills/wizard.md` — overwrites project-local source of truth with the stale global copy.
**Why it happens:** Arguments look similar; easy typo in either direction.
**How to avoid:** State consistently as "local → global": `cp -p skills/[file] ~/.claude/skills/[file]`.
**Warning signs:** After copy, `diff` shows the global file is OLDER; or v1.1 changes (Step 2.5 block) disappear from the local file.

### Pitfall 2: Tilde quoting suppresses expansion

**What goes wrong:** `cp -p skills/wizard.md "~/.claude/skills/wizard.md"` — tries to write to a literal path named `~`.
**Why it happens:** Quoting suppresses tilde expansion in bash/zsh.
**How to avoid:** Use unquoted `~` or `$HOME` in all commands.

### Pitfall 3: cp -p on macOS extended attributes (cosmetic — not an error)

**What goes wrong:** `ls -la` shows `.rwxr-xr-x@` — the `@` indicates extended attributes. Might look like an error.
**Why it happens:** macOS adds quarantine xattrs to files. `cp -p` copies them.
**How to avoid:** No action needed. Permissions and content are correct. The `@` is cosmetic.

### Pitfall 4: Functional test run from Keystone directory

**What goes wrong:** Running `bash ~/.claude/skills/wizard-detect.sh` from `/Users/flong/Developer/keystone` — `SCRIPT_DIR` resolves correctly (it's always relative to the script's own path, not cwd), but `wizard-state.json` and `toolkit-registry.json` write to the Keystone `.claude/` directory instead of a neutral test location.
**Why it happens:** The output files write to `$PWD/.claude/`, not to `~/.claude/`.
**How to avoid:** Run functional test from `/tmp` or another non-Keystone directory. Confirm the test produces `/tmp/.claude/wizard-state.json`.

### Pitfall 5: Forgetting toolkit-discovery.sh is entirely new globally

**What goes wrong:** Running diffs for only 3 files (wizard.md, wizard-detect.sh, wizard-backing-agent.md) and missing the toolkit-discovery.sh copy.
**Why it happens:** Phase 9/11 template had 3 files. Phase 16 adds a 4th.
**How to avoid:** Plan explicitly names all 4 `cp -p` commands. Verification runs `test -f ~/.claude/skills/toolkit-discovery.sh` before diffs.

### Pitfall 6: Cross-project test produces empty toolkit counts

**What goes wrong:** `wizard-state.json` shows `toolkit: {}` or missing — discovery returned nothing.
**Why it happens:** Most likely `toolkit-discovery.sh` was not deployed first, OR it was copied without executable bit, OR it failed silently.
**How to avoid:** Run `bash ~/.claude/skills/toolkit-discovery.sh` standalone FIRST (step 1 of functional test) — confirm valid JSON with counts > 0. Then run `wizard-detect.sh` (step 2). If step 1 fails, fix before proceeding.

---

## Code Examples

### Full sync sequence (4 files, local → global)

```bash
# From project root: /Users/flong/Developer/keystone
# Step 1: Copy all 4 files (local → global, preserve permissions)
cp -p /Users/flong/Developer/keystone/skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh
cp -p /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh
cp -p /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md
cp -p /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md

# Step 2: Verify file sync (all 4 must exit 0)
diff /Users/flong/Developer/keystone/skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh && echo "toolkit-discovery.sh: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && echo "wizard-detect.sh: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && echo "wizard.md: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && echo "wizard-backing-agent.md: MATCH"

# Step 3: Verify executable bits
test -x ~/.claude/skills/toolkit-discovery.sh && echo "toolkit-discovery.sh: executable"
test -x ~/.claude/skills/wizard-detect.sh && echo "wizard-detect.sh: executable"
```

### Cross-project path resolution test (run from /tmp)

```bash
# Step 1: Standalone toolkit discovery
cd /tmp
mkdir -p .claude
bash ~/.claude/skills/toolkit-discovery.sh 2>/dev/null | python3 -m json.tool | grep -A5 '"counts"'
# Expected: agents: 176, skills: N, hooks: N, mcp: N

# Step 2: Full wizard-detect.sh run
bash ~/.claude/skills/wizard-detect.sh 2>/dev/null
cat /tmp/.claude/wizard-state.json | python3 -c "import json,sys; s=json.load(sys.stdin); print('toolkit:', s.get('toolkit', {}).get('counts', 'MISSING'))"
# Expected: toolkit: {'agents': N, 'skills': N, 'hooks': N, 'mcp': N}
```

### Gitignore verification

```bash
# From project root
grep "toolkit-registry.json" /Users/flong/Developer/keystone/.gitignore && echo "gitignore entry: PRESENT"
git -C /Users/flong/Developer/keystone status --short | grep toolkit && echo "SHOULD NOT APPEAR" || echo "git status: CLEAN (not tracked)"
```

### VERIFICATION.md quick-run command (repeatable audit)

```bash
diff /Users/flong/Developer/keystone/skills/toolkit-discovery.sh /Users/flong/.claude/skills/toolkit-discovery.sh && \
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh /Users/flong/.claude/skills/wizard-detect.sh && \
diff /Users/flong/Developer/keystone/skills/wizard.md /Users/flong/.claude/skills/wizard.md && \
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md /Users/flong/.claude/skills/wizard-backing-agent.md && \
test -x /Users/flong/.claude/skills/toolkit-discovery.sh && \
test -x /Users/flong/.claude/skills/wizard-detect.sh && \
grep -q "toolkit-registry.json" /Users/flong/Developer/keystone/.gitignore && \
echo "ALL PASS"
```

---

## State of the Art

This is the third deployment sync for this project. The established pattern is stable and well-understood.

| Phase | Files Deployed | New Pattern |
|-------|---------------|-------------|
| Phase 9 | 3 files (wizard.md, wizard-detect.sh, wizard-backing-agent.md) + deleted orphan (wizard-router/) | delete-then-copy; VALIDATION.md quick-run |
| Phase 11 | Same 3 files (one with label fix first) | edit-then-copy |
| Phase 16 | Same 3 files + 1 new file (toolkit-discovery.sh) | copy-all-4; SCRIPT_DIR cross-project test |

The VERIFICATION.md format from Phase 9/11 is the template — AND-chained assertions with a single `echo "ALL PASS"` at end.

---

## Precedent

Phase 9 and Phase 11 are the direct templates for this phase.

| Pattern | Phase 9 | Phase 11 | Phase 16 |
|---------|---------|---------|---------|
| Sync mechanism | `rm -rf` orphan + `cp -p` 3 files | `cp -p` 3 files (label fix first) | `cp -p` 4 files (no fix needed — toolkit-discovery.sh is new) |
| Verification | `diff` + orphan check + `test -x` | `diff` + `test -x` + `grep` label | `diff` (4 files) + `test -x` (2 files) + path resolution test + gitignore check |
| VERIFICATION format | AND-chained assertions | AND-chained assertions | AND-chained assertions |
| Absolute paths | `/Users/flong/Developer/keystone/skills/...` | Same | Same |
| Functional test | None | None | NEW — cross-project /tmp test for SCRIPT_DIR |

Phase 9 VERIFICATION.md: `.planning/phases/09-global-deployment-sync/09-VERIFICATION.md`
Phase 11 VERIFICATION.md: `.planning/phases/11-final-global-deployment-sync/11-VERIFICATION.md`

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — deployment sync, shell checks only |
| Config file | None |
| Quick run command | `diff /Users/flong/Developer/keystone/skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh && test -x ~/.claude/skills/toolkit-discovery.sh && echo PASS` |
| Full suite command | AND-chained assertion suite (see Code Examples above) |
| Estimated runtime | < 5 seconds including functional test |

### Phase Requirements to Test Map

Phase 16 has no formal requirement IDs. Success criteria map directly to shell assertions:

| SC # | Behavior Verified | Test Type | Automated Command | File Exists? |
|------|-------------------|-----------|-------------------|-------------|
| SC #1 | `toolkit-discovery.sh` exists globally and matches local | structural | `diff /Users/flong/Developer/keystone/skills/toolkit-discovery.sh ~/.claude/skills/toolkit-discovery.sh && echo PASS` | ✅ (post-copy) |
| SC #2 | `wizard-detect.sh` matches local (includes toolkit discovery call and toolkit JSON write) | structural | `diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && echo PASS` | ✅ (post-copy) |
| SC #3 | `wizard.md` matches local (includes Step 2.5 injection block and dynamic catalog read) | structural | `diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && echo PASS` | ✅ (post-copy) |
| SC #4 | Running `/wizard` from non-Keystone directory discovers `~/.claude/agents/` | functional | `cd /tmp && bash ~/.claude/skills/wizard-detect.sh && python3 -c "import json; s=json.load(open('.claude/wizard-state.json')); assert s['toolkit']['counts']['agents'] > 0"` | ✅ (post-deploy) |
| SC #5 | `toolkit-registry.json` appears in `.gitignore` and not in `git status` | gitignore | `grep -q "toolkit-registry.json" .gitignore && ! git status --short | grep -q toolkit && echo PASS` | ✅ (already verified) |

### Sampling Rate

- **Per task commit:** Run the verification command for that specific SC
- **Per wave merge:** Run full suite command (all assertions)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — no test infrastructure required. Operations are direct shell commands with instant feedback. No framework installation, no test files to create beyond VERIFICATION.md itself.

---

## Open Questions

1. **Functional test cleanup approach**
   - What we know: `cd /tmp && bash ~/.claude/skills/wizard-detect.sh` creates `/tmp/.claude/wizard-state.json` and `/tmp/.claude/toolkit-registry.json`
   - What's unclear: Whether to explicitly `rm -rf /tmp/.claude/` after the test or leave for OS cleanup
   - Recommendation: Leave for OS cleanup (macOS reclaims `/tmp` contents on reboot). No security risk — these are non-sensitive discovery outputs. CONTEXT.md explicitly defers this to Claude's discretion.

2. **wizard-backing-agent.md executable bit**
   - What we know: `wizard-backing-agent.md` is a markdown file (`-rw-r--r--@`) — no executable bit expected
   - What's unclear: Whether to include an `test -x` assertion for it
   - Recommendation: No `test -x` for markdown files — only assert executable bit for `.sh` files (`toolkit-discovery.sh` and `wizard-detect.sh`).

---

## Sources

### Primary (HIGH confidence)

- Live filesystem inspection — `diff`, `ls -la`, directory listings verified 2026-03-14
- `16-CONTEXT.md` — locked decisions from /gsd:discuss-phase session
- `09-RESEARCH.md` — direct precedent for deployment sync pattern
- `11-RESEARCH.md` — direct precedent for deployment sync pattern
- `skills/wizard-detect.sh` lines 283-284 — SCRIPT_DIR pattern verified by direct read

### Secondary (MEDIUM confidence)

- Phase 9 and 11 VERIFICATION.md files — format templates for AND-chained assertion suite

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Current diff state: HIGH — verified by live `diff` commands and `ls -la` run 2026-03-14
- Sync operations: HIGH — `cp -p` is POSIX; identical mechanism to Phase 9/11 which completed successfully
- SCRIPT_DIR path resolution: HIGH — verified by reading wizard-detect.sh lines 283-284; resolution logic is deterministic based on `$0`
- Validation commands: HIGH — modeled on working Phase 9/11 VERIFICATION.md templates
- Gitignore state: HIGH — verified by `grep` (entry at line 38) and `git status` (file not tracked)
- Pitfalls: HIGH — all from Phase 9/11 research; one new pitfall added (toolkit-discovery.sh entirely absent globally)

**Research date:** 2026-03-14
**Valid until:** N/A — one-time deployment sync; research reflects snapshot state at research time
