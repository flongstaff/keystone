# Phase 11: Final Global Deployment Sync - Research

**Researched:** 2026-03-13
**Domain:** Shell file deployment — text edit + copy operations on `~/.claude/skills/`
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Option 3 label fix (SC #1):**
- `wizard.md` line 321: gsd-only non-uat-passing Option 3 (Validate phase) cross-references "full-stack Option 4" — should say "Option 3"
- Fix in project-local `skills/wizard.md` first, then deploy to global
- One-word change: "Option 4" → "Option 3"

**Sync mechanism (carried from Phase 9):**
- `cp -p` of all 3 skill files from project-local `skills/` to `~/.claude/skills/`
- Copy all files regardless of individual diff status — idempotent, ensures completeness
- `cp -p` preserves permissions (wizard-detect.sh executable bit)
- Order: fix label first, then copy all files

**Post-sync verification (carried from Phase 9):**
- `diff` between each local and global file — expect zero output (SC #5)
- `test -x ~/.claude/skills/wizard-detect.sh` to confirm executable bit preserved
- Repeatable quick-run command in VERIFICATION.md for future audit use

### Claude's Discretion
- Exact task breakdown and wave structure
- VERIFICATION.md format and additional assertions beyond core checks
- Whether to combine all operations into a single plan or split

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 11 is the final deployment sync of the v1.0 milestone. It has two operations: (1) fix a one-word label error in project-local `skills/wizard.md`, then (2) copy all three skill files to `~/.claude/skills/`. This mirrors Phase 9 exactly in mechanism, but is smaller in scope — no orphan cleanup, and the only content change is fixing "Option 4" to "Option 3" at line 321 of wizard.md.

The actual diffs are narrow and verified by live inspection today. `wizard.md` differs in 6 places: 4 Phase 10 changes (uat-passing/complete menu handling and simplified question text at lines 70/72/145/233/235/303) and the label bug at line 321 (which exists in both local and global since Phase 10 didn't fix it — it's the pre-existing stale label that slipped through). `wizard-backing-agent.md` differs in 1 place (Route C sync note updated in Phase 10). `wizard-detect.sh` differs at lines 73-85 (VERIFICATION.md ladder check added in Phase 10). All three files need the `cp -p` sync.

The label bug context: in the full-stack non-uat-passing menu, "Validate phase" is Option 3 and "Discover tools" is Option 4. In the gsd-only non-uat-passing menu, "Validate phase" is also Option 3. The line at 321 says "Same as full-stack Option 4 above" which is incorrect — it should say "Option 3" since that's the Validate phase option in the full-stack section too.

**Primary recommendation:** Single plan, single wave — fix label, copy 3 files, verify diff. All operations take under 1 second and have no interdependencies beyond "fix before copy."

---

## Current State (verified by live inspection, 2026-03-13)

### Global vs. Local diff summary

| File | Status | Detail |
|------|--------|--------|
| `skills/wizard.md` → `~/.claude/skills/wizard.md` | **DIFFERS** | 6 lines: 4 Phase 10 uat-passing/complete menu changes + 1 question text change + same stale "Option 4" label that exists in both (label bug is in local too — must be fixed before copy) |
| `skills/wizard-backing-agent.md` → `~/.claude/skills/wizard-backing-agent.md` | **DIFFERS** | 1 line: Route C sync note (line 271) — local has "Both ladders check VERIFICATION.md" language; global has older two-differences note |
| `skills/wizard-detect.sh` → `~/.claude/skills/wizard-detect.sh` | **DIFFERS** | ~12 lines: VERIFICATION.md ladder check block (lines 73-85) present in local, absent in global |

### Permission state

| File | Local | Global |
|------|-------|--------|
| `wizard-detect.sh` | `-rwxr-xr-x@` (executable) | `-rwxr-xr-x@` (executable) |
| `wizard.md` | normal | normal |
| `wizard-backing-agent.md` | normal | normal |

The executable bit is already set on both. `cp -p` will preserve it.

### Label bug location (verified)

- **File:** `skills/wizard.md` (and identically in global `~/.claude/skills/wizard.md`)
- **Line:** 321
- **Current text:** `- **Option 3 (Validate phase):** Same as full-stack Option 4 above.`
- **Correct text:** `- **Option 3 (Validate phase):** Same as full-stack Option 3 above.`
- **Context:** gsd-only non-uat-passing menu. The full-stack non-uat-passing menu has Validate phase as Option 3 (line 168), not Option 4. The "Option 4" reference is an error that predates Phase 10.

---

## Standard Stack

### Core

| Operation | Command | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Text edit | `Edit` tool on `skills/wizard.md` line 321 | Fix label bug in local file | Change "Option 4" → "Option 3" at exact line |
| File copy | `cp -p skills/wizard.md ~/.claude/skills/wizard.md` | Sync with permission preservation | `-p` flag preserves executable bit and timestamps |
| Diff check | `diff skills/wizard.md ~/.claude/skills/wizard.md` | Verify zero delta post-sync | Standard verification; exit 0 = match |
| Permission check | `test -x ~/.claude/skills/wizard-detect.sh` | Confirm executable bit survived | Guards against `cp` stripping permissions |

### No Supporting Libraries Needed

This phase uses only POSIX shell built-ins, standard Unix tools, and the `Edit` tool for the line fix. No npm, Python, or framework dependencies.

**Installation:** None required.

---

## Architecture Patterns

### Recommended Plan Structure

```
11-01-PLAN.md   (single plan)
  Wave 1:
    Task 11-01-01  Edit skills/wizard.md line 321: "Option 4" → "Option 3"
    Task 11-01-02  cp -p skills/wizard.md ~/.claude/skills/wizard.md
    Task 11-01-03  cp -p skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md
    Task 11-01-04  cp -p skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh
    Task 11-01-05  diff assertions + executable bit check (all 5 SCs)

11-VERIFICATION.md (repeatable audit commands, modeled on Phase 9 VERIFICATION.md)
```

### Pattern: Edit-then-copy (fix before deploy)

**What:** Apply the label fix to project-local first, then copy all files to global. This ensures the global file receives both the Phase 10 changes AND the label fix in a single copy operation.
**When to use:** Any time a content fix and a deployment must be applied together.
**Rationale from CONTEXT.md:** "fix label first, then copy all files" — explicit ordering constraint.

### Pattern: Absolute paths for global targets

**What:** All commands targeting `~/.claude/skills/` must use literal `~` (unquoted) or `$HOME`.
**Why:** Running from project root — relative paths resolve into `skills/`, not `~/.claude/skills/`. Quoting `~` suppresses tilde expansion.

### Anti-Patterns to Avoid

- **Copying before fixing the label:** Propagates the bug to global. Fix first, then copy.
- **Using `cp` without `-p` for wizard-detect.sh:** Strips the executable bit. Always `cp -p` for all three files.
- **Quoting the tilde:** `"~/.claude/..."` does not expand in bash/zsh. Use unquoted `~` or `$HOME`.
- **Fixing only the global file without fixing local:** SC #1 requires fixing the project-local source of truth first; SC #5 requires diff = 0 between local and global.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Permission preservation | Custom chmod after copy | `cp -p` | Single flag handles all metadata |
| Content verification | md5sum / sha256sum comparison | `diff` | `diff` exits 1 on any difference; simpler, readable output |
| Deploy script | Bash script with error handling | Inline task commands | One-off sync; automation overhead not justified |
| Text substitution | sed/awk for line edit | `Edit` tool | Edit tool is targeted, readable, and idempotent |

---

## Common Pitfalls

### Pitfall 1: Fix only the global file, not the local file

**What goes wrong:** Edit `~/.claude/skills/wizard.md` line 321 directly. Local stays wrong. Then `cp -p` overwrites the global fix with the still-broken local.
**Why it happens:** Temptation to "just fix the one that's broken."
**How to avoid:** CONTEXT.md is explicit: "Fix in project-local `skills/wizard.md` first, then deploy to global." The Edit tool target must be `skills/wizard.md`, not `~/.claude/skills/wizard.md`.
**Warning signs:** After `cp -p`, `diff` still exits 0, but the label bug reappears in global — means the local file still has the bug.

### Pitfall 2: Source/destination path reversal on copy

**What goes wrong:** `cp -p ~/.claude/skills/wizard.md skills/wizard.md` — overwrites the source of truth with the stale global copy.
**Why it happens:** Arguments look similar; easy typo.
**How to avoid:** Always state as "local → global": `cp -p skills/[file] ~/.claude/skills/[file]`.
**Warning signs:** After copy, `diff` shows differences — or worse, the Phase 10 changes disappear from the local file.

### Pitfall 3: Tilde quoting suppresses expansion

**What goes wrong:** `cp -p skills/wizard.md "~/.claude/skills/wizard.md"` — tries to write to a literal path named `~`.
**Why it happens:** Quoting suppresses tilde expansion in bash/zsh.
**How to avoid:** Use unquoted `~` or `$HOME` in all commands.

### Pitfall 4: cp -p on macOS with extended attributes

**What goes wrong:** `cp -p` on macOS preserves extended attributes (xattrs). The `@` in `ls -la` output (`.rwxr-xr-x@`) is normal. Not an error.
**Why it happens:** macOS adds quarantine xattrs to files. `cp -p` copies them.
**How to avoid:** No action needed. The `@` is cosmetic; permissions and content are correct.

### Pitfall 5: Label bug present in BOTH local and global

**What goes wrong:** Developer checks `diff skills/wizard.md ~/.claude/skills/wizard.md` and sees a 0-byte diff at line 321 — concludes the label is already fixed.
**Why it happens:** Both copies have the same bug. `diff` is 0 for line 321 because they match each other (both wrong).
**How to avoid:** The bug must be caught by reading the line, not by diffing. The CONTEXT.md is the source of truth: line 321 says "Option 4" and it must be changed to "Option 3". Verify with `grep -n "Option 4" skills/wizard.md` after the edit.

---

## Code Examples

### Step-by-step sync sequence (Phase 11)

```bash
# From project root: /Users/flong/Developer/keystone

# Step 1: Verify the label bug exists in local (should show line 321)
grep -n "Option 4" skills/wizard.md | grep "321"
# Expected: 321:- **Option 3 (Validate phase):** Same as full-stack Option 4 above.

# Step 2: Fix label in local wizard.md (use Edit tool — change "Option 4" to "Option 3" at line 321)
# Result: line 321 reads: - **Option 3 (Validate phase):** Same as full-stack Option 3 above.

# Step 3: Confirm fix
grep -n "Option" skills/wizard.md | grep "321"
# Expected: 321:- **Option 3 (Validate phase):** Same as full-stack Option 3 above.

# Step 4: Copy all three files (local → global, preserve permissions)
cp -p /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md
cp -p /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md
cp -p /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh

# Step 5: Verify (expect all assertions to pass)
diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && echo "wizard.md: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && echo "wizard-backing-agent.md: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && echo "wizard-detect.sh: MATCH"
test -x ~/.claude/skills/wizard-detect.sh && echo "executable bit: PRESERVED"
grep -n "Option 3 (Validate phase).*Option 3 above" ~/.claude/skills/wizard.md && echo "label fix: DEPLOYED"
```

### VERIFICATION.md quick-run command (repeatable audit)

```bash
diff /Users/flong/Developer/keystone/skills/wizard.md /Users/flong/.claude/skills/wizard.md && \
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md /Users/flong/.claude/skills/wizard-backing-agent.md && \
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh /Users/flong/.claude/skills/wizard-detect.sh && \
test -x /Users/flong/.claude/skills/wizard-detect.sh && \
grep -q "Option 3 (Validate phase).*Option 3 above" /Users/flong/.claude/skills/wizard.md && \
echo "ALL PASS"
```

Note: Absolute paths because `diff` with relative paths only works when cwd is the project root. VERIFICATION.md should document required cwd or use absolute paths.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — deployment sync + one-line text fix, shell checks only |
| Config file | None |
| Quick run command | `diff /Users/flong/Developer/keystone/skills/wizard.md /Users/flong/.claude/skills/wizard.md && test -x /Users/flong/.claude/skills/wizard-detect.sh && echo PASS` |
| Full suite command | Five-assertion command above (wizard.md + backing-agent + detect.sh diff + executable bit + label grep) |
| Estimated runtime | < 1 second |

### Phase Requirements to Test Map

Phase 11 has no formal requirement IDs. Success criteria map directly to shell assertions:

| SC # | Behavior Verified | Test Type | Automated Command | File Exists? |
|------|-------------------|-----------|-------------------|-------------|
| SC #1 | gsd-only Option 3 cross-reference says "Option 3" (not "Option 4") | structural | `grep -q "Option 3 (Validate phase).*Option 3 above" /Users/flong/.claude/skills/wizard.md && echo PASS` | ✅ (post-edit) |
| SC #2 | `~/.claude/skills/wizard-detect.sh` matches local (VERIFICATION.md ladder included) | structural | `diff /Users/flong/Developer/keystone/skills/wizard-detect.sh /Users/flong/.claude/skills/wizard-detect.sh && echo PASS` | ✅ (post-copy) |
| SC #3 | `~/.claude/skills/wizard.md` matches local (Option 3 fix + complete status handling) | structural | `diff /Users/flong/Developer/keystone/skills/wizard.md /Users/flong/.claude/skills/wizard.md && echo PASS` | ✅ (post-copy) |
| SC #4 | `~/.claude/skills/wizard-backing-agent.md` matches local | structural | `diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md /Users/flong/.claude/skills/wizard-backing-agent.md && echo PASS` | ✅ (post-copy) |
| SC #5 | Zero differences between all local and global skill files | structural | Full five-assertion suite | ✅ (composite) |

### Sampling Rate

- **Per task commit:** Run the verification command for that specific SC
- **Per wave merge:** Run full suite command (all 5 assertions)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — no test infrastructure required. Operations are direct shell commands with instant feedback. No framework installation, no test files to create beyond VERIFICATION.md itself.

---

## Precedent

Phase 9 (Global Deployment Sync) is the direct template for this phase. Key reusable patterns:

| Pattern | Phase 9 Form | Phase 11 Form |
|---------|-------------|---------------|
| Sync mechanism | `rm -rf` orphan, then `cp -p` three files | `cp -p` three files (no orphan; fix first) |
| Verification | `diff` + `test ! -d` orphan check + `test -x` | `diff` + `test -x` + `grep` label check |
| VALIDATION format | Quick-run suite with AND-chained assertions | Same structure, updated assertions |
| Absolute paths | `/Users/flong/Developer/keystone/skills/...` | Same |
| `cp -p` preserves executable bit | Confirmed | Confirmed (bit already set on both copies) |

Phase 9 VERIFICATION.md is at `.planning/phases/09-global-deployment-sync/09-VERIFICATION.md` and serves as the format template.

---

## Open Questions

1. **Label bug scope: only line 321?**
   - What we know: CONTEXT.md explicitly identifies line 321 as the only instance ("One-word change: 'Option 4' → 'Option 3'"). Live `grep` confirms "Option 4" appears at line 321 in the gsd-only non-uat-passing section.
   - What's unclear: Whether any other cross-references use "Option 4" incorrectly in other sections.
   - Recommendation: After the edit, run `grep -n "Option 4" skills/wizard.md` to confirm no other spurious references. The full-stack menus legitimately have an "Option 4 (Discover tools)" — those should remain. Only the cross-reference at line 321 needs to change.

---

## Sources

### Primary (HIGH confidence)

- Live filesystem inspection — `diff`, `grep -n`, `ls -la` verified 2026-03-13
- `11-CONTEXT.md` — locked decisions from /gsd:discuss-phase session
- `09-RESEARCH.md` — direct template and precedent for Phase 9 sync mechanism
- `09-VERIFICATION.md` — VERIFICATION.md format template

### Secondary (MEDIUM confidence)

- `10-VERIFICATION.md` — confirms Phase 10 changes that are now stale in global

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Current diff state: HIGH — verified by live `diff` commands run 2026-03-13
- Label bug location: HIGH — verified by `grep -n` on both local and global; confirmed CONTEXT.md description matches actual line content
- Sync operations: HIGH — `cp -p` is POSIX; identical to Phase 9 which completed successfully
- Validation commands: HIGH — modeled on working Phase 9 VERIFICATION.md
- Pitfalls: HIGH — all identified in Phase 9 research; confirmed still applicable; one new pitfall added (label in both files)

**Research date:** 2026-03-13
**Valid until:** N/A — one-time deployment sync; research reflects snapshot state at research time
