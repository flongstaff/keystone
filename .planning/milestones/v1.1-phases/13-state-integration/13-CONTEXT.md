# Phase 13: State Integration - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire toolkit-discovery.sh into wizard-detect.sh so every `/wizard` invocation embeds a compact toolkit summary in wizard-state.json. The toolkit data enables downstream subagent injection (Phase 14) and dynamic catalog display (Phase 15). No new scanning logic — this phase only integrates Phase 12's existing output.

</domain>

<decisions>
## Implementation Decisions

### Status box display
- Add one line showing toolkit counts: `Tools: 176 agents, 4 skills, 24 hooks, 5 MCP`
- Line appears after the Phase line and before the Last line
- Hide the line entirely when all counts are zero (fresh install with no discovered tools)
- Counts come from the compact summary captured from toolkit-discovery.sh stdout

### Discovery call strategy
- Call `toolkit-discovery.sh` inline every time wizard-detect.sh runs
- TTL cache in toolkit-discovery.sh keeps repeat calls under 0.1s — no latency concern
- First cold scan (~1-2s) happens once per hour — acceptable tradeoff for always-fresh data
- If toolkit-discovery.sh does not exist (pre-Phase 12 install or path issue), silently fall back to an empty toolkit object — no warning, no stderr noise

### wizard-state.json integration
- Add a `toolkit` key containing the compact summary object (counts + by_stage arrays)
- Purely additive — all existing fields (scenario, project_type, next_command, etc.) unchanged
- ~600 byte budget for the toolkit section (PERF-02 requirement)
- Empty state: `"toolkit": {}` when discovery script is missing or returns no tools

### Claude's Discretion
- Exact insertion point in wizard-detect.sh (where to call toolkit-discovery.sh and where to write the toolkit JSON)
- How to capture and parse the compact summary stdout (variable capture, temp file, etc.)
- Exact printf formatting for the status box toolkit line
- How to extract individual counts from the summary for the conditional display check
- Whether to resolve toolkit-discovery.sh path relative to the script or use an absolute path

</decisions>

<specifics>
## Specific Ideas

- The compact summary from toolkit-discovery.sh is already JSON: `{"version":1,"counts":{"agents":N,...},"by_stage":{...}}` — capture stdout and embed directly as the `toolkit` value in the heredoc
- Follow wizard-detect.sh's established pattern of using Python3 one-liners for JSON manipulation when bash is insufficient
- The status box line should use the same `printf "│  Tools: %-49s│\n"` pattern as other lines in the box

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/toolkit-discovery.sh`: Already built in Phase 12 — emits compact JSON summary to stdout, handles TTL caching, produces valid empty JSON on missing dirs
- `skills/wizard-detect.sh`: 380-line detection script with heredoc JSON write, Python3 helpers, status box printf block — this is the file being modified

### Established Patterns
- JSON heredoc write: wizard-detect.sh uses `cat > ".claude/wizard-state.json" << EOF` with variable interpolation (line 286)
- Python3 for JSON: Used for is_reset detection (line 263) and infra safety injection (line 163) — precedent for inline Python
- Status box: printf-based box drawing with conditional lines (project_type, infra safety, phase name, stopped_at — all conditionally shown)
- Variable capture: `VARIABLE=$(command)` pattern used throughout for subshell output

### Integration Points
- wizard-detect.sh line ~286: JSON heredoc — add `"toolkit": $TOOLKIT_JSON` field
- wizard-detect.sh line ~338-378: Status box printf block — add conditional toolkit counts line
- toolkit-discovery.sh stdout: Compact summary JSON to capture
- `.claude/wizard-state.json`: Downstream consumer for Phase 14 injection and Phase 15 display

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-state-integration*
*Context gathered: 2026-03-13*
