# Phase 15: Dynamic Catalog Display - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the hardcoded Phase 7 "Discover tools" catalog in wizard.md with a dynamic, registry-backed display from `toolkit-registry.json`. Tools are grouped by stage relevance (research/planning/execution/review) then by type within each stage, with Keystone tools shown first. The hardcoded Phase 7 catalog remains as a fallback for fresh installs where the registry is absent or malformed.

</domain>

<decisions>
## Implementation Decisions

### Display grouping
- Primary axis: stage-first (Research / Planning / Execution / Review), not type-first
- Within each stage: Keystone tools shown first (flat sub-section), then Installed tools sub-grouped by type (Agents / Skills / MCP)
- Tools appearing in multiple stages show up in each relevant stage group
- Per-stage entry cap: Claude's discretion based on actual registry size at runtime
- Summary header at top with counts: `**N** agents · **N** skills · **N** hooks · **N** MCP servers`

### Entry format
- Uniform format for all tools: `- name — one-liner description` (no activation commands)
- Activation commands dropped from dynamic entries — registry doesn't carry them, and they add noise at scale
- MCP entries suffixed with `(configured)` — consistent with CONF-03 injection language
- Active domain agent marking preserved: domain agent matching `project_type` gets `(active)` appended

### Fallback behavior
- Show hardcoded Phase 7 catalog when `toolkit-registry.json` is missing OR fails JSON parse (covers fresh installs and corruption)
- Fallback uses Phase 7's original type-first format as-is — no re-grouping by stage
- Subtle footer note indicates data source:
  - Dynamic: `Source: toolkit-registry.json (scanned [timestamp])`
  - Fallback: `Showing built-in catalog. Run toolkit-discovery.sh for full scan.`
- Selecting "Discover tools" triggers `bash skills/toolkit-discovery.sh` if registry is stale (past TTL), refreshing before display

### Parity check
- Verification step in the execution plan (not runtime assertion): read hardcoded entries, read registry, assert all 18 Keystone tools (11 agents + 4 skills + 3 hooks) appear in dynamic output
- Hardcoded catalog text kept in wizard.md as the fallback — never removed (SC #3 requires it)
- Deduplicate: consolidate 4 duplicate catalog blocks into one shared "Display Catalog" instruction block
- All 4 Option 4 handlers reference the shared block instead of inlining catalog text

### Wizard.md structure
- New shared "Display Catalog" instruction block near bottom of wizard.md
- Logic sequence: run toolkit-discovery.sh (refreshes if stale) → read registry → if valid: render stage-first → if invalid: show hardcoded fallback → re-present calling menu
- All 4 menu variants' Option 4 handlers point to the shared block
- Hardcoded fallback lives inside the shared block (single copy)

### Claude's Discretion
- Per-stage entry cap threshold and "... and N more" wording
- Exact markdown formatting (spacing, separator lines, indentation depth)
- Ordering of tools within each sub-section (alphabetical vs registry order)
- How to handle stages with zero tools (skip the section vs show empty)
- Python3 vs bash for JSON parsing of toolkit-registry.json

</decisions>

<specifics>
## Specific Ideas

- The catalog should feel like a quick reference card — scan it, find what you need, get back to work (carried from Phase 7)
- Stage-first grouping answers "what helps me right now" better than type-first grouping
- The counts header provides instant orientation for users with large toolkits (160+ agents)
- Keystone-first within each stage gives built-in tools visibility without drowning them in user-installed noise

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/toolkit-discovery.sh`: Already handles TTL caching, `--force` rescan, and writes `toolkit-registry.json` with `name, type, description, stages, source` per entry
- `skills/wizard.md`: Has 4 Option 4 "Discover tools" handlers with identical hardcoded catalog blocks — consolidation target
- `wizard-state.json`: Carries `project_type` for active domain agent marking (already loaded in Step 2)
- `toolkit-registry.json` schema: `{ schema_version, scanned_at, counts: {agents, skills, hooks, mcp}, tools: [...entries] }` — ready for display consumption

### Established Patterns
- Post-status menu loop: secondary options re-present same menu after completion (Phase 5)
- Agent tool pass-through: wizard never summarizes or reformats agent output (Phase 5)
- wizard-state.json is the sole lightweight data source for startup; toolkit-registry.json is lazy-loaded only for "Discover tools" (PERF-03)
- Hardcoded allowlists for known Keystone tools (Phase 12, Phase 14)

### Integration Points
- `skills/wizard.md` Option 4 handlers (lines ~176, ~253, ~335, ~403): Replace inline catalog with shared block reference
- `toolkit-registry.json`: Read by wizard.md for dynamic display (this is the PERF-03 lazy-load moment)
- `skills/toolkit-discovery.sh`: Called by wizard.md to refresh stale registry before display
- `wizard-state.json` `project_type`: Read for active domain agent marking

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 15-dynamic-catalog-display*
*Context gathered: 2026-03-13*
