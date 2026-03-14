# Phase 12: Core Discovery Scanner - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Build `toolkit-discovery.sh` — a standalone bash script that scans the user's full installed toolkit (agents, skills, hooks, MCP servers), applies stage tagging (research/planning/execution/review), writes a complete registry to `toolkit-registry.json`, and emits a compact summary to stdout. TTL-gated caching prevents redundant rescans. The script runs independently — no wizard integration (Phase 13), no injection (Phase 14), no display (Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Scanning strategy
- **Agents:** Parse YAML frontmatter from `~/.claude/agents/*.md` — extract name, description, model, and tools fields using sed/awk (no external YAML parser)
- **MCP servers:** Scan both `~/.claude/settings.json` mcpServers section AND `~/.claude/installed_plugins.json` — covers manually configured and marketplace-installed MCPs
- **Skills:** Scan `~/.claude/skills/*.md` files — if a SKILL.md exists in the same directory, extract metadata from it; otherwise use filename as name and first lines for description
- **Hooks:** Parse settings.json hook registrations — extract event type, script path, and matcher. Only registered hooks count as "installed" (unregistered scripts in ~/.claude/hooks/ are ignored)

### Stage tagging logic
- **Method:** Hardcoded keyword arrays per stage, scanned against each tool's description field
  - research: "research", "explore", "analyze", "investigate", "scan", "discover"
  - planning: "plan", "design", "architect", "roadmap", "scaffold", "structure"
  - execution: "build", "implement", "execute", "write", "deploy", "create", "generate"
  - review: "review", "audit", "validate", "test", "verify", "check", "lint"
- **Keystone agents:** Hardcoded stage tags for all 11 known agents and 4 skills — keyword matching only for user-installed tools the scanner doesn't recognize
- **MCP servers:** Tagged as all stages (descriptions are too minimal for reliable keyword matching)
- **Zero-match fallback:** Tools matching no keywords are tagged as all stages — better to over-surface than miss a useful tool
- **Multi-match:** Tools can and should match multiple stages — a tool that matches both "research" and "review" gets both tags

### Registry format (toolkit-registry.json)
- **Location:** `.claude/toolkit-registry.json` (project-local, next to wizard-state.json, gitignored)
- **Schema version:** Include `"schema_version": 1` at top level for future compatibility
- **Entry fields:** `name`, `type` (agent|skill|hook|mcp), `description` (one-liner), `stages` (array of research/planning/execution/review), `source` (file path or config key)
- **Top-level structure:** `{ schema_version, scanned_at, counts: {agents, skills, hooks, mcp}, tools: [...entries] }`

### Compact summary (stdout)
- **Format:** JSON with counts (agents:N, skills:N, hooks:N, mcp:N) plus arrays of tool names grouped by stage: `{research:[...], planning:[...], execution:[...], review:[...]}`
- **Size target:** ~600 bytes max (per PERF-02 requirement — Phase 13 embeds this in wizard-state.json)
- **Always emitted:** Even on cache hit, the summary is emitted to stdout from cached registry data — wizard-detect.sh needs this output every invocation

### TTL caching
- **Duration:** 1 hour — toolkit changes are rare; 1h is fresh enough for any session
- **Staleness detection:** File mtime comparison using `stat` — no JSON parsing needed for the fast path
- **Force rescan:** `--force` flag bypasses TTL check and rescans everything
- **Cache hit behavior:** Skip scanning, read cached registry, emit compact summary to stdout
- **Empty state:** When `~/.claude/agents/` doesn't exist, produce valid empty-catalog JSON (zero counts, empty arrays) — no error exit code

### Claude's Discretion
- Exact keyword lists per stage (the categories above are guidelines — refine based on actual agent descriptions)
- sed/awk patterns for YAML frontmatter extraction (implementation detail)
- JSON generation approach (heredoc vs jq vs python3 one-liner — whatever is most robust)
- Exact compact summary format within the ~600 byte constraint
- Error handling for malformed YAML, missing fields, or permission issues
- stat command portability (macOS stat -f vs Linux stat -c)
- Order of operations within the scan

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/wizard-detect.sh`: 380-line bash script with same patterns needed here — JSON heredoc output, Python helpers for JSON manipulation, `stat`/`find`/`grep` patterns, `.claude/` directory conventions
- `scripts/weekly-stack-check.sh`: Uses `jq` for JSON cache management — established caching pattern
- `hooks/session-start.sh`: File detection patterns with `[ -f ]` and `find` — defensive coding style
- Python3 available for JSON manipulation (used in wizard-detect.sh for infra safety injection and is_reset detection)

### Established Patterns
- JSON output via bash heredoc (`cat > file << EOF`)
- Python3 one-liners for JSON manipulation when bash is insufficient
- `2>/dev/null` on all file reads for graceful degradation
- `set -euo pipefail` in production scripts
- `.claude/` for machine-specific state files (wizard-state.json precedent)
- Kebab-case filenames with `.sh` extension for scripts
- Error output to stderr, structured data to stdout
- Exit 0 always from scripts consumed by wizard (non-blocking)

### Integration Points
- `wizard-detect.sh` will call `toolkit-discovery.sh` and capture stdout (Phase 13)
- `.claude/toolkit-registry.json` will be read by wizard.md for catalog display (Phase 15)
- Compact summary format must be parseable by wizard-detect.sh's JSON write block (Phase 13)
- `--force` flag enables manual refresh from wizard UX if needed
- `~/.claude/agents/*.md` — YAML frontmatter source for agent scanning
- `~/.claude/settings.json` — mcpServers object + hook registrations
- `~/.claude/installed_plugins.json` — marketplace-installed MCP plugins
- `.gitignore` — must include toolkit-registry.json entry

</code_context>

<specifics>
## Specific Ideas

- Script should follow wizard-detect.sh's coding style — same bash patterns, same defensive programming
- The hardcoded Keystone agent stage tags serve as a test fixture — if the scanner's keyword matching would have gotten them wrong, that validates the hardcoding decision
- Registry file next to wizard-state.json creates a clean "wizard data" cluster in `.claude/`
- The 160-agent install is the real-world benchmark — it must handle that without slowdown
- Phase 7's hardcoded catalog used the format `name — one-liner — activation` — the registry's name + description fields should enable that same display downstream

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-core-discovery-scanner*
*Context gathered: 2026-03-13*
