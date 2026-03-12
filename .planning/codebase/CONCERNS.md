# Codebase Concerns

**Analysis Date:** 2026-03-11

## Tech Debt

**Hook Script Dependency Chain Fragility:**
- Issue: `post-write-check.sh` relies on external tools (grep, jq for potential future checks) but does not validate their availability at hook invocation time. If a tool becomes unavailable mid-session, warnings may silently fail to display.
- Files: `hooks/post-write-check.sh` (lines 19-70)
- Impact: Silent failures in safety checks could allow dangerous patterns (hardcoded secrets, missing error handling) to pass without warning, creating false confidence
- Fix approach: Add explicit tool availability checks at hook entry with graceful degradation (warn user if jq/python3 not available, continue with limited checks)

**Shell Script Date Command Portability:**
- Issue: `scripts/weekly-stack-check.sh` and `hooks/stack-update-banner.sh` use both BSD date (`date -v+7d`) and GNU date (`date -d "+7 days"`) with fallback pattern. The fallback silently returns empty string if both fail, leading to malformed JSON.
- Files: `hooks/stack-update-banner.sh` (line 44, 50), `scripts/weekly-stack-check.sh` (line 36)
- Impact: On systems without compatible date tools, cache file may contain empty `next_check_recommended` field, breaking subsequent cache reads and potentially blocking update notifications
- Fix approach: Detect available date variant at script start, select one consistently, or pre-compute date in calling context (GSD agents)

**Python Inline Code in Bash:**
- Issue: Three scripts embed Python code as inline heredocs: `install-runtime-support.sh` (lines 131-149, 202-228), relying on Python 3 being available at runtime.
- Files: `scripts/install-runtime-support.sh`
- Impact: Installation fails on systems without Python 3, with unclear error message. No fallback to pure-bash alternatives.
- Fix approach: Extract Python blocks to separate `.py` files committed to repository, or use pure bash/jq for JSON/text manipulation where feasible

**Cron Job Registration Not Idempotent:**
- Issue: `install-runtime-support.sh` (lines 235-246) uses `crontab -l | grep -q` to detect if cron line exists, but grep matching is substring-only. Partial matches (e.g., different paths to same script) could cause duplicate cron entries.
- Files: `scripts/install-runtime-support.sh` (lines 237-239)
- Impact: Repeated installations could add duplicate cron jobs, causing `weekly-stack-check.sh` to run multiple times per week, wasting resources
- Fix approach: Anchor grep pattern with start/end anchors, or use explicit crontab format with unique identifiers

**Hook Path Hard-Coded in settings.json Patching:**
- Issue: `install-runtime-support.sh` hardcodes `$HOME/.claude/hooks/` paths in JSON (line 213, 221), but if user installs to a different location or path contains special characters (spaces, quotes), JSON becomes malformed.
- Files: `scripts/install-runtime-support.sh` (lines 202-228)
- Impact: `settings.json` patch could be invalid JSON, breaking Claude Code's ability to parse hooks on next startup
- Fix approach: Use jq with `--arg` flags to safely substitute paths into JSON template, validate output JSON before writing

**Post-Write Check Hook Missing File Argument Handling:**
- Issue: `post-write-check.sh` attempts to detect file path from `CLAUDE_TOOL_INPUT_FILE_PATH` env var (line 12), but this variable name is not documented and may not be set by Claude Code in all versions/contexts. If not set, hook silently exits with no action.
- Files: `hooks/post-write-check.sh` (lines 7-14)
- Impact: File safety checks could be skipped entirely if hook invocation context doesn't provide expected environment variable, creating false sense of security
- Fix approach: Log a warning when file cannot be determined, document the required hook invocation format, coordinate with Claude Code team on stable env var contract

## Known Bugs

**Date Formatting Inconsistency in Cache:**
- Symptoms: `stack-update-banner.sh` background refresh and `weekly-stack-check.sh` may write different ISO 8601 formats (one includes timezone offset `+00:00`, one may not)
- Files: `hooks/stack-update-banner.sh` (line 55), `scripts/weekly-stack-check.sh` (line 40)
- Trigger: Run weekly-stack-check.sh on macOS (uses `date -Iseconds`), then immediately restart Claude Code session (runs stack-update-banner.sh background refresh, also tries `date -Iseconds`)
- Workaround: Cache is mostly resilient to format variations due to `jq -r` parsing, but date comparisons may fail if timestamps are compared as strings rather than epoch seconds

**Python Import Path in weekly-stack-check.sh:**
- Symptoms: `weekly-stack-check.sh` reads BMAD version from `$HOME/.claude/skills/bmad/core/package.json` (line 32), which is not guaranteed to exist if BMAD was installed via npm globally rather than locally
- Files: `scripts/weekly-stack-check.sh` (line 32)
- Trigger: Install BMAD globally (`npx bmad-method install` defaults to global), then run weekly-stack-check.sh standalone
- Workaround: Script exits with error and suggests manual retry, but error message is cryptic (`echo "Fetch failed — check connectivity"`)

**OpenCode Agent Directory Detection Fragile:**
- Symptoms: `install-runtime-support.sh` attempts to guess OpenCode agent directory by trying three candidates (lines 164-172), but may succeed with a directory that doesn't actually work for OpenCode
- Files: `scripts/install-runtime-support.sh` (lines 164-172)
- Trigger: Run installer on system where `$HOME/.config/opencode/agents` doesn't exist but `$HOME/.config/opencode/` exists, allowing mkdir to succeed and script to proceed with potentially wrong path
- Workaround: User can manually verify agent deployment and redeploy if incorrect

## Security Considerations

**Hardcoded Secret Detection Regex Bypass:**
- Risk: `post-write-check.sh` uses negative lookahead pattern (line 26) to avoid flagging examples, but pattern is incomplete. It checks for `example|placeholder|changeme|your-|<|>`, but misses other common patterns like `INSERT_HERE`, `FIXME`, `REPLACE_ME`, `[object Object]` (common JSON serialization errors)
- Files: `hooks/post-write-check.sh` (line 26)
- Current mitigation: Script warns user with `ERRORS` array but never blocks execution. User must manually review warnings.
- Recommendations: Expand bypass pattern to include common placeholder markers. Consider using a dedicated secret scanning library (e.g., `truffleHog` wrapper) rather than regex. Run secret scan as separate offline tool before any network interaction.

**Python JSON File Read Insecurity:**
- Risk: `install-runtime-support.sh` reads BMAD version via inline Python that opens file without catching `FileNotFoundError` (line 52 in weekly-stack-check.sh references same pattern). If file is deleted between check and read, Python exception is unhandled.
- Files: `hooks/stack-update-banner.sh` (line 52), `scripts/weekly-stack-check.sh` (line 32)
- Current mitigation: Both wrap the Python call in a subshell with `2>/dev/null || echo "?"`, so missing files default to version `"?"`. Subsequent comparisons treat `"?"` as "unknown", avoiding false positives.
- Recommendations: Add explicit `try/except` in Python blocks instead of relying on shell redirection. Log file-not-found to debug log so installation issues can be diagnosed.

**Settings.json Patch Overwrites Without Backup Check:**
- Risk: `install-runtime-support.sh` backs up `settings.json` before patching (line 200) with `cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"`, but backup only succeeds silently if dir is writable. If backup fails, it continues anyway and patches original (line 225 writes to `$SETTINGS` unconditionally).
- Files: `scripts/install-runtime-support.sh` (lines 198-228)
- Current mitigation: Uses `2>/dev/null || true` on backup line, so installation doesn't fail. Python script is applied regardless of backup success.
- Recommendations: Exit with error if backup fails. Never modify original settings.json without confirmed backup. Use `set -e` on this section or explicit error checks.

**Log File Permissions Implicit:**
- Risk: `post-write-check.sh`, `session-start.sh`, `stack-update-banner.sh`, and `weekly-stack-check.sh` all write logs to `$HOME/.claude/logs/` without setting explicit permissions. If a user's logs directory is world-readable, security logs (which may reference file paths, command outputs, or error messages containing sensitive data) could be exposed.
- Files: `hooks/post-write-check.sh` (line 9), `hooks/session-start.sh` (line 9), `hooks/stack-update-banner.sh` (line 6), `scripts/weekly-stack-check.sh` (line 19)
- Current mitigation: Logs directory is created `mkdir -p` with default umask, resulting in `755` permissions on directory and whatever default umask produces for files.
- Recommendations: Create logs directory with explicit `mkdir -p -m 700` to restrict to user-only access. Set logs to `644` or `600` depending on sensitivity.

## Performance Bottlenecks

**Synchronous Network Call in Background Refresh Logic:**
- Problem: `stack-update-banner.sh` (lines 47-49) makes two sequential npm network calls to fetch package versions inside a background subshell spawned from the main hook. If npm registry is slow (common during high-traffic periods), entire hook latency increases, potentially blocking Claude Code session start notification.
- Files: `hooks/stack-update-banner.sh` (lines 46-68)
- Cause: `npm view` is synchronous and doesn't have configurable timeout. On slow networks, can take 5-10 seconds per call.
- Improvement path: (1) Add explicit timeout to npm calls using `timeout 5s npm view ...`. (2) Detect npm availability before making calls. (3) Skip background refresh if cache is already recent (within 3 days instead of 7) to reduce frequency of network attempts.

**Weekly Cron Script Exits on First Fetch Failure:**
- Problem: `weekly-stack-check.sh` (line 28-30) exits immediately if either BMAD or GSD fetch fails, preventing partial updates (e.g., if GSD fetch succeeds but BMAD fails, GSD version isn't written to cache).
- Files: `scripts/weekly-stack-check.sh` (lines 24-30)
- Cause: Uses `if [ "$BMAD_LATEST" = "FETCH_FAILED" ] || [ "$GSD_LATEST" = "FETCH_FAILED" ]` with early exit, rather than continuing with partial data.
- Improvement path: Continue on individual fetch failures. Write whichever versions succeed to cache, mark failed fetches as "unknown". Update cache with timestamp regardless of success/failure so failed attempt is logged. This allows banner to show partial updates rather than stale cache.

**Python JSON Read on Every Session Start:**
- Problem: `session-start.sh` reads `.planning/config.json` using Python subprocess (lines 30-37) on every session start to extract project name. If .planning/ directory has many files or system is under load, Python startup overhead (typically 100-200ms) becomes noticeable.
- Files: `hooks/session-start.sh` (lines 30-37)
- Cause: Uses Python as subprocess rather than native bash/jq, adds startup cost.
- Improvement path: Extract project name from config.json using `jq` instead of Python. If jq unavailable, provide fallback bash-only parser using simple string matching.

## Fragile Areas

**Install Script Bootstrapping Assumption:**
- Files: `scripts/install-runtime-support.sh`
- Why fragile: Script assumes `npx` is available globally (line 70), but doesn't verify until after printing multiple status messages. If npx is missing, script has already suggested next steps that won't work. Also assumes Node.js is the system's npm, but on some systems (especially corporate environments) multiple Node versions may be installed.
- Safe modification: (1) Check for npx before any substantive work (first step after arg parsing). (2) Detect multiple npm/node versions and let user choose. (3) Document nodejs version requirements at top of script and in README.
- Test coverage: No automated test for "npx missing" scenario. Manual test required.

**Hook File Write Permissions:**
- Files: `scripts/install-runtime-support.sh` (lines 190-195)
- Why fragile: Script copies hook files and sets `chmod +x`, but doesn't validate that `$HOOKS_DST` is actually writable beforehand. If directory exists but is read-only (corporate IT lock-down scenario), hooks fail silently with incomplete copies.
- Safe modification: Check write permissions on hooks destination before copying. Exit with helpful error if not writable.
- Test coverage: No test for "destination directory read-only" scenario.

**JSON Patching Without Validation:**
- Files: `scripts/install-runtime-support.sh` (lines 202-228)
- Why fragile: Python script reads, modifies, and writes settings.json, but never validates that the output is valid JSON before writing. If jq encoding fails or Python script has bugs, resulting file could be corrupted JSON, breaking Claude Code startup.
- Safe modification: (1) Validate output JSON before moving from temp file. (2) Add `jq empty` on the output to syntax-check. (3) Keep backup of original settings.json for at least 5 session starts so user can rollback.
- Test coverage: No automated test for invalid JSON generation.

**Restore Script rsync --delete Risk:**
- Files: `scripts/restore.sh` (lines 62, 66, 82, 90)
- Why fragile: Script uses `rsync -a --delete` which removes files in destination that don't exist in source. If backup is incomplete (missing files), restore will delete them from live config. Combined with dry-run support, user could accidentally run actual restore after reviewing wrong dry-run output (dry-run uses `--delete` too).
- Safe modification: (1) Separate dry-run implementation from actual restore — don't use rsync for both. (2) Log all deletions to a file before applying. (3) Require explicit `--force` flag to apply deletions, not just destination match.
- Test coverage: No automated test for partial backup scenario.

**Agent Path Assumptions in session-start.sh:**
- Files: `hooks/session-start.sh` (lines 30-37, 47-51)
- Why fragile: Script searches for project name in `.planning/config.json` and project type in `.claude/CLAUDE.md`, but paths are relative to current working directory. If user is in a subdirectory of project, relative paths fail silently and script shows defaults (empty project name, no project type).
- Safe modification: Detect project root by finding nearest `.planning/` or `CLAUDE.md` upwards from cwd. Store detected root in session and use for all subsequent relative path operations.
- Test coverage: No test for "cwd is project subdirectory" scenario.

## Scaling Limits

**Cron Update Check Doesn't Handle Large Changelogs:**
- Current capacity: `stack-update-watcher` agent can analyze changelogs up to ~1500 lines before context limits. If BMAD/GSD changelog is very long (major version upgrade with 50+ commits), agent cannot process full changelog in one pass.
- Limit: BMAD or GSD release with >2000 changelog lines will exceed agent context window when combined with all other analysis
- Scaling path: (1) Split changelog analysis into chunks (first 500 lines, middle 500 lines, final 500 lines). (2) Summarize intermediate results before next chunk. (3) Provide option to analyze specific version range rather than full history.

**Agent Deployment Doesn't Scale Beyond 20 Agents:**
- Current capacity: `install-runtime-support.sh` loops over all agents in `agents/` directory and copies them. With 11 agents, takes <1 second. But design assumes <20 agents total.
- Limit: If more than 20 agents are added to repository, installation time becomes noticeable and loop overhead increases. No grouping or categorization.
- Scaling path: (1) Organize agents into categories (entry, bridge, domain, maintenance) as separate install targets. (2) Allow selective installation (--entry-agents, --domain-agents). (3) Pre-package agents as tar archives instead of copying individually.

**Hook Log Files Unbounded Growth:**
- Current capacity: Log files at `~/.claude/logs/` are never rotated. Each session appends lines. With multiple sessions per day, logs grow ~1-2 KB per day, reaching 1 GB in ~2 years.
- Limit: After 1-2 years of use, logs directory could reach several GB, consuming disk space and slowing down directory operations.
- Scaling path: (1) Implement log rotation (monthly files, keep last 12 months). (2) Compress old logs to `.gz`. (3) Add cleanup flag to install script: `--cleanup-old-logs [days]`.

## Dependencies at Risk

**BMAD and GSD Tightly Coupled Without Compatibility Matrix:**
- Risk: Stack assumes compatible versions of BMAD and GSD, but no version constraints or compatibility matrix is documented. If BMAD updates breaking-changes its CLI or output format, GSD orchestration agents may fail.
- Impact: User upgrades BMAD, then tries to run `bmad-gsd-orchestrator` and it fails with unclear error (BMAD output format no longer matches expected schema)
- Migration plan: (1) Document tested version pairs (BMAD 1.2.x with GSD 3.4.x). (2) Add version constraint checks to orchestrator agents. (3) Create "version compatibility" section in stack-update-watcher output showing what needs updating together.

**NPM Package Registry Outage Risk:**
- Risk: `weekly-stack-check.sh` and `stack-update-banner.sh` background refresh depend on `npm view` calls to fetch latest versions. If npm registry is down, version checks fail and cache becomes stale.
- Impact: Users won't know about available updates for the duration of registry outage. If using 2-week-old cache, could miss critical security updates.
- Migration plan: (1) Add fallback to npm mirror (jsDelivr, unpkg) if primary registry fails. (2) Log registry timeouts to make outages visible. (3) Increase cache TTL from 7 days to 14 days to reduce dependency on frequent checks.

**Python 3 Availability Not Guaranteed:**
- Risk: Multiple scripts use Python 3 as subprocess but don't require it in installation prerequisites. Environments (e.g., legacy macOS, some corporate images) may not have Python 3.
- Impact: Installation completes successfully but hooks/scripts fail at runtime with `python3: command not found`
- Migration plan: (1) Make Python 3 an explicit prerequisite in README prerequisites section. (2) Provide fallback implementations in pure bash for JSON reading (use jq instead). (3) In install script, check for Python 3 availability before deployment.

**Hook Dependency on jq Without Fallback:**
- Risk: `post-write-check.sh` doesn't require jq but `stack-update-banner.sh` does (line 9). If jq is not installed, only stack-update-banner.sh warns; installation doesn't fail.
- Impact: Stack appears to install successfully, but banner hook is silently disabled (exits with status 0 after warning). User may think update notifications are working when they're not.
- Migration plan: (1) Add jq to explicit prerequisites. (2) Provide fallback JSON parsing using `grep` + `sed` for simple value extraction in banner hook (don't need full jq for this use case). (3) In install script, verify jq and give clear error if missing.

## Missing Critical Features

**No Backup/Restore for Agent Files Themselves:**
- Problem: `restore.sh` restores hooks and settings but not agent `.md` files. If agents are accidentally deleted from `~/.claude/agents/`, there's no recovery path except re-installing Keystone from scratch.
- Blocks: User cannot safely delete agents to clean up obsolete ones; they can only disable them in settings.

**No Dry-Run for Installation:**
- Problem: `install-runtime-support.sh` deploys agents, hooks, and patches settings.json with no way to preview changes first. Only `restore.sh` has `--dry-run` support.
- Blocks: First-time users cannot see what will be modified before running installer. High-risk scenarios (corporate/shared machines) require running without inspection capability.

**No Version Pinning for Locked Environments:**
- Problem: Stack always fetches latest BMAD/GSD versions, but no option to pin to specific versions for teams requiring reproducible environments.
- Blocks: Teams in corporate environments with change control boards cannot easily adopt stack without approval for "latest" versions.

**No Agent Update/Hotfix Mechanism:**
- Problem: If a bug is found in one agent (e.g., incorrect regex in domain agent), user must manually edit the agent file or re-run full installation to get fix.
- Blocks: Critical bug fixes cannot be deployed to existing installations without manual intervention.

## Test Coverage Gaps

**Shell Script Bash-isms Not Tested Across Shells:**
- What's not tested: Scripts use bash-specific syntax (e.g., `[[`, `+=`, `$()`) but shebang claims `/bin/bash`. On systems where `/bin/bash` doesn't exist or is linked to dash/ksh, scripts will fail at runtime.
- Files: All `.sh` scripts in `hooks/` and `scripts/`
- Risk: Installation on non-standard Linux systems or containers where bash is not available in expected location
- Priority: Medium — affects non-standard environments but not mainstream systems

**JSON Injection/Corruption in Patching:**
- What's not tested: Python script that patches `settings.json` doesn't test what happens if original file has syntax issues, duplicate keys, or trailing commas
- Files: `scripts/install-runtime-support.sh` (lines 202-228)
- Risk: If user has manually edited settings.json and introduced invalid JSON, installation script will fail to parse/modify it
- Priority: Medium — requires user to have manually edited config, but recovery is not obvious

**Hook Invocation Contract With Claude Code:**
- What's not tested: Hooks assume specific Claude Code environment variables (e.g., `CLAUDE_TOOL_INPUT_FILE_PATH`), but this contract is not documented or validated against actual Claude Code behavior. If Claude Code changes hook invocation format in future version, hooks will silently malfunction.
- Files: `hooks/post-write-check.sh` (line 12)
- Risk: Major Claude Code update could break all hooks with no warning
- Priority: High — affects critical safety checks and update notifications

**Restore Script With Incomplete Backups:**
- What's not tested: `restore.sh` validates that backup directories exist and are non-empty (lines 41-52), but doesn't test what happens if they exist but contain partial/corrupted files
- Files: `scripts/restore.sh`
- Risk: Restore could silently overwrite live config with incomplete backup
- Priority: Medium — affects restore scenario which is less common than install

**Cross-Runtime Agent Compatibility:**
- What's not tested: Agents are deployed to Claude Code, Pi, and OpenCode, but frontmatter stripping for Pi (lines 131-149) is not tested. If Python regex is incorrect, Pi agents could be deployed with invalid format.
- Files: `scripts/install-runtime-support.sh` (lines 131-149)
- Risk: Pi deployment appears successful but agents don't load at runtime
- Priority: Medium — affects secondary runtimes; most users target Claude Code

---

*Concerns audit: 2026-03-11*
