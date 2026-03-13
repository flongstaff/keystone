# Phase 9: Global Deployment Sync - Research

**Researched:** 2026-03-13
**Domain:** Shell file deployment — copy and delete operations on `~/.claude/skills/`
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sync mechanism:**
- Direct `cp -p` of all 3 Keystone skill files (wizard.md, wizard-backing-agent.md, wizard-detect.sh) from project-local `skills/` to `~/.claude/skills/`
- Copy all files regardless of diff status — idempotent, ensures completeness
- `cp -p` preserves permissions (wizard-detect.sh executable bit)
- Order: delete orphans first, then copy fresh files (clean slate approach)

**Orphan cleanup:**
- `rm -rf ~/.claude/skills/wizard-router/` — direct deletion, no temp backup
- Known orphan only — no scan for other stale files
- `rm -rf` is idempotent — no existence check needed before deletion

**Post-sync verification:**
- `diff` between each local and global file — expect zero output (matches SC #4)
- `test ! -d ~/.claude/skills/wizard-router/` to confirm orphan deletion (SC #3)
- `test -x ~/.claude/skills/wizard-detect.sh` to confirm executable bit preserved
- Repeatable quick-run command in VALIDATION.md for future audit use

### Claude's Discretion
- Exact task breakdown and wave structure
- VALIDATION.md format and additional assertions beyond the core checks
- Whether to combine operations into a single plan or split across multiple

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 9 is a pure deployment sync: copy 3 project-local skill files to `~/.claude/skills/` and delete the orphaned `wizard-router/` directory. No logic changes, no new capabilities. The phase exists because Phase 8 modified skill files in the project-local `skills/` directory but did not propagate those changes to the global `~/.claude/skills/` location that Claude Code reads when `/wizard` is invoked from any project context.

The actual diffs are narrow and confirmed by live inspection: `wizard.md` has 4 extra `wizard-router` catalog lines in the global copy (one per post-status menu variant); `wizard-backing-agent.md` is already in sync (no diff); `wizard-detect.sh` is already in sync (no diff). The `wizard-router/` directory exists at `~/.claude/skills/wizard-router/` containing `SKILL.md` and a stale copy of `wizard-detect.sh` — it must be deleted.

The entire phase reduces to two shell operations: `rm -rf` then three `cp -p` calls, followed by `diff` assertions. Planning complexity is in ensuring the VALIDATION.md captures the repeatable audit commands correctly.

**Primary recommendation:** Single plan, single wave — all four operations (delete orphan, copy 3 files) are sequential, take under 1 second, and have no interdependencies beyond "delete before copy."

---

## Standard Stack

### Core

| Operation | Command | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Orphan delete | `rm -rf ~/.claude/skills/wizard-router/` | Remove stale skill directory | Idempotent, no existence check needed |
| File copy | `cp -p skills/wizard.md ~/.claude/skills/wizard.md` | Sync with permission preservation | `-p` flag preserves executable bit and timestamps |
| Diff check | `diff skills/wizard.md ~/.claude/skills/wizard.md` | Verify zero delta post-sync | Standard verification; exit 0 = match |
| Permission check | `test -x ~/.claude/skills/wizard-detect.sh` | Confirm executable bit survived | Guards against `cp` stripping permissions |

### No Supporting Libraries Needed

This phase uses only POSIX shell built-ins and standard Unix tools. No npm, Python, or framework dependencies.

**Installation:** None required.

---

## Architecture Patterns

### Recommended Plan Structure

```
09-01-PLAN.md   (single plan)
  Wave 1:
    Task 09-01-01  rm -rf ~/.claude/skills/wizard-router/
    Task 09-01-02  cp -p skills/wizard.md ~/.claude/skills/wizard.md
    Task 09-01-03  cp -p skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md
    Task 09-01-04  cp -p skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh

09-VALIDATION.md  (repeatable audit commands, modeled on Phase 8 VALIDATION.md)
```

### Pattern: Delete-before-copy (clean slate)

**What:** Delete orphaned directory, then copy fresh files. Not copy-then-delete.
**When to use:** When the orphan and the source files don't conflict but the orphan should not survive.
**Rationale from CONTEXT.md:** "clean slate approach" — operator intent is to leave global skills in an exact known state.

### Pattern: Absolute paths for global targets

**What:** All commands targeting `~/.claude/skills/` must use the literal `~` or `$HOME` expansion.
**Why:** Running from project root — relative paths resolve into `skills/`, not `~/.claude/skills/`. Mixing up source vs. destination is the single most likely error.

### Anti-Patterns to Avoid

- **Checking existence before `rm -rf`:** Unnecessary; `rm -rf` on a non-existent path exits 0. Adds noise.
- **Using `cp` without `-p` for wizard-detect.sh:** Strips the executable bit. Always use `cp -p` for all three files.
- **Scanning for other stale global files:** Out of scope per CONTEXT.md. Only the known orphan is targeted.
- **Backing up `wizard-router/` before deletion:** Out of scope per CONTEXT.md. No temp backup.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Permission preservation | Custom chmod after copy | `cp -p` | Single flag handles all metadata |
| Existence check before delete | `if [ -d ... ]; then rm -rf ...` | `rm -rf` unconditionally | `-rf` is idempotent on missing targets |
| Content verification | md5sum / sha256sum comparison | `diff` | `diff` exits 1 on any difference; simpler, more readable |
| Deploy script | Bash script with error handling | Inline task commands | One-off sync; automation overhead not justified |

---

## Common Pitfalls

### Pitfall 1: Source/destination path reversal

**What goes wrong:** `cp -p ~/.claude/skills/wizard.md skills/wizard.md` — overwrites the source of truth with the stale global copy.
**Why it happens:** Arguments look similar; easy typo in either direction.
**How to avoid:** Always state it as "local → global": `cp -p skills/[file] ~/.claude/skills/[file]`.
**Warning signs:** After copy, `diff` reports the global file is OLDER than project-local. Or the 4 stale `wizard-router` catalog lines reappear in project-local wizard.md.

### Pitfall 2: Forgetting `~` expands differently in different shells

**What goes wrong:** `rm -rf "~/.claude/skills/wizard-router/"` (quoted tilde) does not expand — tries to delete a literal path named `~`.
**Why it happens:** Quoting suppresses tilde expansion in bash/zsh.
**How to avoid:** Use unquoted `~` or `$HOME` in commands: `rm -rf ~/.claude/skills/wizard-router/`.

### Pitfall 3: cp -p fails on macOS extended attributes

**What goes wrong:** `cp -p` on macOS preserves extended attributes (xattrs). The `@` in `ls -la` output (e.g., `.rwxr-xr-x@`) indicates xattrs are present. This is normal behavior — not an error.
**Why it happens:** macOS adds quarantine xattrs to downloaded files. `cp -p` copies them.
**How to avoid:** No action needed. The `@` in `ls` output is cosmetic; permissions and content are correct.

### Pitfall 4: diff returns non-zero exit even when files match whitespace

**What goes wrong:** `diff` exits 1 if any difference exists — including trailing newline differences. A seemingly clean copy can still show 1-line diff due to line ending or BOM.
**Why it happens:** Editors sometimes modify trailing newlines on save.
**How to avoid:** `cp -p` does byte-for-byte copy; diff will exit 0 on identical copies. If diff shows output after `cp -p`, the source file has been modified and should be re-inspected.

### Pitfall 5: Regression from Phase 7 validation (documented precedent)

**What goes wrong:** Phase 7's Nyquist audit accidentally re-added 4 `wizard-router` catalog entries to wizard.md that Phase 8 had removed. This is documented in 08-VALIDATION.md audit notes.
**Why it happens:** A validation script that reads-and-rewrites a file can restore previously deleted lines if it works from a cached or pre-edit version.
**How to avoid:** After any post-sync diff check, if the diff shows the 4 `wizard-router` lines are present again, that indicates a regression — not a stale global. The VALIDATION.md quick-run command should check `! grep -q "wizard-router" ~/.claude/skills/wizard.md`.

---

## Current State (verified by live inspection, 2026-03-13)

### Global vs. Local diff summary

| File | Status | Detail |
|------|--------|--------|
| `skills/wizard.md` → `~/.claude/skills/wizard.md` | **DIFFERS** | Global has 4 extra lines: `- **wizard-router** -- Silent entry point...` in all 4 post-status menu variants (lines 126, 206, 287, 356 of global) |
| `skills/wizard-backing-agent.md` → `~/.claude/skills/wizard-backing-agent.md` | **MATCHES** | diff exits 0 — already in sync |
| `skills/wizard-detect.sh` → `~/.claude/skills/wizard-detect.sh` | **MATCHES** | diff exits 0 — already in sync |
| `~/.claude/skills/wizard-router/` | **EXISTS** | Contains `SKILL.md` (1.2k) and `wizard-detect.sh` (14k, stale copy) |

### Permission state

| File | Local permissions | Global permissions |
|------|------------------|--------------------|
| `wizard-detect.sh` | `-rwxr-xr-x` (executable) | `-rwxr-xr-x` (executable) |
| `wizard.md` | normal | normal |
| `wizard-backing-agent.md` | normal | normal |

The executable bit on `wizard-detect.sh` is already correct globally. `cp -p` will preserve it. No `chmod` needed after copy.

---

## Code Examples

### Full sync sequence (verified commands)

```bash
# Step 1: Delete orphan (idempotent)
rm -rf ~/.claude/skills/wizard-router/

# Step 2: Copy all three files (local → global, preserve permissions)
cp -p /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md
cp -p /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md
cp -p /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh

# Step 3: Verify (expect all four to pass)
diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && echo "wizard.md: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && echo "wizard-backing-agent.md: MATCH"
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && echo "wizard-detect.sh: MATCH"
test ! -d ~/.claude/skills/wizard-router/ && echo "wizard-router: DELETED"
test -x ~/.claude/skills/wizard-detect.sh && echo "executable bit: PRESERVED"
```

### VALIDATION.md quick-run command (repeatable audit)

```bash
diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && \
diff /Users/flong/Developer/keystone/skills/wizard-backing-agent.md ~/.claude/skills/wizard-backing-agent.md && \
diff /Users/flong/Developer/keystone/skills/wizard-detect.sh ~/.claude/skills/wizard-detect.sh && \
test ! -d ~/.claude/skills/wizard-router/ && \
test -x ~/.claude/skills/wizard-detect.sh && \
echo "ALL PASS"
```

Note: This command uses absolute paths because `diff` with relative paths only works when cwd is the project root. VALIDATION.md should document the required cwd.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — deployment sync, shell checks only |
| Config file | None |
| Quick run command | `diff /Users/flong/Developer/keystone/skills/wizard.md ~/.claude/skills/wizard.md && test ! -d ~/.claude/skills/wizard-router/ && test -x ~/.claude/skills/wizard-detect.sh && echo PASS` |
| Full suite command | See "VALIDATION.md quick-run command" example above |
| Estimated runtime | < 1 second |

### Phase Requirements to Test Map

Phase 9 has no formal requirement IDs. It protects existing requirements from regression:

| Protected Req | Behavior Verified | Test Type | Automated Command | File Exists? |
|---------------|-------------------|-----------|-------------------|-------------|
| UI-01 (no regression) | Global wizard.md has no stale wizard-router catalog entries | structural | `! grep -q "wizard-router" ~/.claude/skills/wizard.md && echo PASS` | ✅ |
| ORCH-01 (no regression) | Global wizard-backing-agent.md has no /bmad-gsd-orchestrator fallback | structural | `! grep -q "/bmad-gsd-orchestrator" ~/.claude/skills/wizard-backing-agent.md && echo PASS` | ✅ |
| SC #3 | wizard-router/ directory is gone | structural | `test ! -d ~/.claude/skills/wizard-router/ && echo PASS` | N/A — directory delete |
| SC #4 | All three files match local versions exactly | structural | Full diff suite above | ✅ |

### Sampling Rate

- **Per task commit:** Run the verification command for that specific SC
- **Per wave merge:** Run full suite command (all 5 assertions)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — no test infrastructure required. Operations are direct shell commands with instant feedback. No framework installation, no test files to create.

---

## Open Questions

1. **Hardcoded absolute path in VALIDATION.md**
   - What we know: `diff` with relative paths requires running from project root; absolute paths work from any cwd
   - What's unclear: Whether VALIDATION.md should use absolute paths or document the required cwd
   - Recommendation: Use absolute paths in the commands but add a comment that the project root is `/Users/flong/Developer/keystone` — makes the audit command portable across context resets

2. **wizard-backing-agent.md already in sync**
   - What we know: Live diff confirms 0 differences between local and global
   - What's unclear: The CONTEXT.md noted this as a known diff (invalid `/bmad-gsd-orchestrator` fallback) — Phase 8 must have fixed the global copy as part of its execution, not just the local copy
   - Recommendation: Still copy it (locked decision says "copy all files regardless of diff status") — the copy is idempotent and takes milliseconds

---

## Sources

### Primary (HIGH confidence)
- Live filesystem inspection — `diff`, `ls -la`, directory listings verified 2026-03-13
- 09-CONTEXT.md — locked decisions from /gsd:discuss-phase session
- 08-VALIDATION.md — precedent for VALIDATION.md format, including the regression audit notes that document the wizard-router catalog line issue

### Secondary (MEDIUM confidence)
- 08-CONTEXT.md — confirmed Phase 8's "SC #7: already doesn't exist" claim was inaccurate; live inspection shows `~/.claude/skills/wizard-router/` does exist

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Current diff state: HIGH — verified by live `diff` commands
- Sync operations: HIGH — `cp -p` and `rm -rf` are POSIX; no library uncertainty
- Validation commands: HIGH — modeled on working Phase 8 VALIDATION.md
- Pitfalls: MEDIUM — macOS xattr behavior observed, tilde expansion is documented shell behavior

**Research date:** 2026-03-13
**Valid until:** N/A — this is a one-time deployment sync; research reflects snapshot state at research time
