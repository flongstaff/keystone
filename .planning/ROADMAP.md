# Roadmap: Keystone

## Milestones

- ✅ **v1.0 Wizard Orchestrator** - Phases 1-11 (shipped 2026-03-13)
- 🚧 **v1.1 Dynamic Toolkit Discovery** - Phases 12-16 (in progress)

## Phases

<details>
<summary>✅ v1.0 Wizard Orchestrator (Phases 1-11) — SHIPPED 2026-03-13</summary>

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Schema and State Detection** - Freeze wizard-state.json schema and build smart router skill that classifies all four project scenarios (completed 2026-03-12)
- [x] **Phase 2: Wizard UI Layer** - Build interactive wizard skill with 4-scenario menus, 2-turn max to recommendation, and intent capture (completed 2026-03-12)
- [x] **Phase 3: New Project Routing** - Add complexity-based path recommendation and domain agent suggestions for fresh projects (completed 2026-03-12)
- [x] **Phase 4: Core Backing Agent Routes** - Build backing agent with resume and bridge-to-GSD routes, including traceability assertions (completed 2026-03-12)
- [x] **Phase 4.1: Rewire Backing Agent** - INSERTED — Fix backing agent orphaned by fix commit; restore bridge flow with traceability assertion, update scenario labels, clean tech debt (Gap closure from audit) (completed 2026-03-12)
- [x] **Phase 5: Full Agent Routing** - Add validate-phase, drift-check, and on-demand traceability display routes (completed 2026-03-12)
- [x] **Phase 6: Recovery, Safety, and Polish** - Add context-reset continuity, IT safety injection, health-monitor prompt, and budget validation (completed 2026-03-12)
- [x] **Phase 7: Agent, Skill, Tool and Hook Discovery** - Add on-demand Discover tools option to wizard post-status menus with hardcoded catalog of all Keystone agents, skills, and hooks (completed 2026-03-12)
- [x] **Phase 8: Bridge Path Fix & Infrastructure Cleanup** - Fix orchestrator path mismatch, clean orphaned files, stale labels, and false-negative validation (Gap closure from audit) (completed 2026-03-13)
- [x] **Phase 9: Global Deployment Sync** - Redeploy project-local skill files to ~/.claude/skills/ and delete orphaned wizard-router directory (Gap closure from audit) (completed 2026-03-13)
- [x] **Phase 10: Code & Documentation Tech Debt** - Fix Route C ladder divergence, orchestrator Operation B path hardcoding, and ROADMAP staleness (Gap closure from audit) (completed 2026-03-13)
- [x] **Phase 11: Final Global Deployment Sync** - Fix Option 3 label, redeploy 3 skill files to ~/.claude/skills/, verify zero diff (Gap closure from audit) (completed 2026-03-13)

### Phase 1: Schema and State Detection
**Goal**: Users invoking `/wizard` get a correctly classified project state in under one bash block, with the result persisted to wizard-state.json
**Depends on**: Nothing (first phase)
**Requirements**: DETECT-01, DETECT-02, DETECT-03, DETECT-04, DETECT-05, ROUTE-01
**Success Criteria** (what must be TRUE):
  1. Running `/wizard` against a project with no BMAD or GSD files produces scenario A in wizard-state.json
  2. Running `/wizard` against a project with a non-empty `_bmad/docs/` produces scenario C (BMAD-only)
  3. Running `/wizard` against a project with only an empty `_bmad/` directory produces STATE.AMBIGUOUS, not scenario C
  4. Running `/wizard` reads at most 3 files and runs at most 1 bash block before writing wizard-state.json
  5. Running `/wizard` cold against a project with an existing wizard-state.json reads state from disk, not memory
**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md -- Create wizard-router skill with 5-scenario detection
- [x] 01-02-PLAN.md -- Verify frozen schema against all scenarios

### Phase 2: Wizard UI Layer
**Goal**: Users reach an actionable, unambiguous recommendation within 2 turns of invoking `/wizard`, with inline explanation available at any branch
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-04, ROUTE-02
**Success Criteria** (what must be TRUE):
  1. A user in scenario A sees a menu appropriate to starting fresh (not GSD resume options)
  2. A user in scenario D (full-stack) sees their exact next GSD command stated literally, e.g., "Run `/gsd:discuss-phase 3`"
  3. A user reaches a concrete recommendation within at most 2 questions from initial `/wizard` invocation
  4. Wizard component overhead consumes less than 10% of context window before delegating to backing agent
  5. A user can type "explain" at any menu prompt and receive context without the wizard restarting
**Plans:** 1/1 plans complete

Plans:
- [x] 02-01-PLAN.md -- Create interactive wizard skill with 5-scenario menus and rebind /wizard entry point

### Phase 3: New Project Routing
**Goal**: Users starting a fresh project receive a path recommendation (BMAD+GSD vs GSD-only vs quick-task) based on detectable project complexity signals, with relevant domain agents surfaced at the right moment
**Depends on**: Phase 2
**Requirements**: ROUTE-03, ORCH-05
**Success Criteria** (what must be TRUE):
  1. A user with a new project containing a large PRD is recommended the BMAD+GSD path, not GSD-only
  2. A user describing a single-file task is recommended quick-task execution, not full BMAD planning
  3. When a user is at the bridge step for an IT infrastructure project, wizard surfaces the Godot/IT infra domain agent suggestion before proceeding
**Plans:** 1/1 plans complete

Plans:
- [x] 03-01-PLAN.md -- Add complexity detection, recommendation tags, and domain agent banner

### Phase 4: Core Backing Agent Routes
**Goal**: The backing agent handles the two highest-value intents — resuming GSD work and bridging from completed BMAD planning to GSD — with every BMAD acceptance criterion verified present in GSD phase context files at bridge time
**Depends on**: Phase 2
**Requirements**: ORCH-01, ORCH-02, ORCH-03, TRACE-01, TRACE-02
**Success Criteria** (what must be TRUE):
  1. Selecting "resume" in the wizard causes the backing agent to emit the exact next GSD command (e.g., "Run `/gsd:discuss-phase 3`") without the user having to specify a phase number
  2. Selecting "bridge to GSD" invokes bmad-gsd-orchestrator in a fresh Task() context, not inline
  3. After the bridge completes, every BMAD acceptance criterion from every story appears in at least one GSD phase context file — wizard asserts this and fails loudly if any are missing
  4. The backing agent delegates to existing agents (bmad-gsd-orchestrator, phase-gate-validator) rather than reimplementing their logic
**Plans:** 2/2 plans complete

Plans:
- [x] 04-01-PLAN.md -- Create wizard-backing-agent.md with Route A (resume) and Route B (bridge + traceability)
- [x] 04-02-PLAN.md -- Wire wizard.md to invoke backing agent and deploy globally

### Phase 4.1: Rewire Backing Agent
**Goal**: The backing agent is reachable in all live user flows — bridge path runs traceability assertion, resume path uses coordinator, and all scenario labels match current detection output
**Depends on**: Phase 4
**Requirements**: ORCH-01, ORCH-02, ORCH-03, TRACE-01, TRACE-02
**Gap Closure:** Closes gaps from v1.0 milestone audit — backing agent orphaned by fix commit 357e5af
**Success Criteria** (what must be TRUE):
  1. Selecting "bridge to GSD" in the wizard reaches wizard-backing-agent Route B, which prompts for confirmation, delegates via Task(bmad-gsd-orchestrator), and runs the traceability assertion
  2. The backing agent's Route Dispatch matches on `bmad-ready` and `bmad-incomplete` (not the superseded `bmad-only`)
  3. wizard-backing-agent.md YAML frontmatter includes `Task` in the tools list
  4. The model reliably follows the backing agent instructions without shortcutting (the mechanism that caused the original removal must be addressed)
  5. wizard.md Context Budget Discipline block and YAML description reference current files (wizard-detect.sh, not wizard-router.md)
**Plans:** 1/1 plans complete

Plans:
- [x] 04.1-01-PLAN.md -- Rewire backing agent: remove Route A, fix scenario labels, add Task tool, rewire wizard.md bridge to Task(), deploy globally

### Phase 5: Full Agent Routing
**Goal**: The backing agent handles phase validation, architectural drift detection, and on-demand traceability status display, completing the full intent routing surface
**Depends on**: Phase 4.1
**Requirements**: ORCH-04, TRACE-03
**Success Criteria** (what must be TRUE):
  1. When UAT or phase-gate checks show failures, wizard surfaces the specific failure details and the exact repair command (e.g., "Run `/gsd:fix-issue plan-02`"), not a generic error message
  2. A user can invoke "show traceability" from the wizard and see which BMAD acceptance criteria map to which GSD phases with their current completion status
  3. Selecting "check drift" invokes context-health-monitor and presents its output without reimplementing its logic
**Plans:** 2/2 plans complete

Plans:
- [x] 05-01-PLAN.md -- Add post-status menus to wizard + Route C traceability display to backing agent
- [x] 05-02-PLAN.md -- Fix broken Continue option: replace Route A invocation with direct next_command dispatch (gap closure)

### Phase 6: Recovery, Safety, and Polish
**Goal**: The wizard survives context resets with continuity messaging, automatically injects safety constraints for infrastructure projects, and is validated against a worst-case large project within the 10% context budget
**Depends on**: Phase 4
**Requirements**: RECOV-01, RECOV-02, RECOV-03
**Success Criteria** (what must be TRUE):
  1. After a context reset, the next `/wizard` invocation reads wizard-state.json and opens with a continuity message showing the user's last position before asking for the next action
  2. When the wizard detects an IT infrastructure project, it automatically sets auto_advance to false and requires dry-run confirmation before any destructive operation — without the user having to configure this
  3. After a phase execution completes, wizard prompts the user to run context-health-monitor before proceeding to the next phase
  4. Running the full router + wizard + backing agent chain against a project with a PRD over 500 lines and 8+ phases consumes less than 20k tokens (10% of a 200k window)
**Plans:** 2/2 plans complete

Plans:
- [x] 06-01-PLAN.md -- Add context-reset continuity, IT safety injection, and uat-passing health-check menus
- [x] 06-02-PLAN.md -- Token budget audit and conditional trim

### Phase 7: Agent, Skill, Tool and Hook Discovery
**Goal**: Users can browse a complete catalog of all Keystone-authored agents, skills, and hooks on-demand from the wizard's post-status menu, with the active domain agent clearly marked
**Depends on**: Phase 6
**Requirements**: None (additive functionality beyond v1 requirements)
**Success Criteria** (what must be TRUE):
  1. Selecting "Discover tools" from any post-status menu (full-stack or gsd-only, uat-passing or not) displays the complete catalog
  2. The catalog shows all 11 agents (grouped by entry/bridge/domain/maintenance), 4 skills, and 3 hooks with name, one-liner, and activation command
  3. The domain agent matching the current project_type is marked "(active)"
  4. After viewing the catalog, the wizard returns to the same post-status menu the user came from
**Plans:** 1/1 plans complete

Plans:
- [x] 07-01-PLAN.md -- Add Discover tools option and inline catalog to all post-status menus, deploy globally

### Phase 8: Bridge Path Fix & Infrastructure Cleanup
**Goal**: The orchestrator correctly scans all BMAD output paths, all stale references and orphaned files are removed, and false-negative validation commands are fixed
**Depends on**: Phase 4.1
**Requirements**: None (bug fix + tech debt — protects ORCH-01, TRACE-01 from regression)
**Gap Closure:** Closes integration breaks, flow break, and tech debt from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. `bmad-gsd-orchestrator.md` Operation A scans both `docs/` and `_bmad-output/planning-artifacts/` for BMAD planning documents
  2. `wizard-backing-agent.md` Step 4 fallback message references a valid command (not non-existent `/bmad-gsd-orchestrator`)
  3. Orphaned `skills/wizard-router.md` is deleted
  4. `settings.local.json` inline bash snippets use current scenario labels (not superseded `bmad-only`)
  5. `wizard-detect.sh` line 2 comment no longer references orphaned `wizard-router.md`
  6. Phase 4 `VALIDATION.md` quick-run command produces a valid result (not permanently false-negative)
  7. Duplicate global path `~/.claude/skills/wizard-router/wizard-detect.sh` is removed
**Plans:** 2/2 plans complete

Plans:
- [x] 08-01-PLAN.md -- Fix orchestrator dual-path scanning, backing agent fallback, and delete orphaned wizard-router.md
- [x] 08-02-PLAN.md -- Clean stale settings.local.json entries and fix Phase 4 VALIDATION.md false-negative

### Phase 9: Global Deployment Sync
**Goal**: Global skill files in ~/.claude/skills/ match project-local versions, and orphaned files are removed — users invoking /wizard from any project context get current behavior
**Depends on**: Phase 8
**Requirements**: None (deployment sync — protects UI-01, ORCH-01, TRACE-01 from regression in global context)
**Gap Closure:** Closes 2 integration gaps + 3 tech debt items from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. `~/.claude/skills/wizard.md` matches project-local `skills/wizard.md` (no stale wizard-router catalog entries)
  2. `~/.claude/skills/wizard-backing-agent.md` matches project-local `skills/wizard-backing-agent.md` (no stale `/bmad-gsd-orchestrator` fallback)
  3. `~/.claude/skills/wizard-router/` directory (SKILL.md + wizard-detect.sh) is deleted
  4. Diff between global and project-local skill files shows zero differences
**Plans:** 1/1 plans complete

Plans:
- [x] 09-01-PLAN.md -- Delete orphaned wizard-router/ directory and redeploy all skill files from project-local to global

### Phase 10: Code & Documentation Tech Debt
**Goal**: Fix code-level tech debt items — Route C ladder alignment, orchestrator dual-path support in Operation B, and ROADMAP accuracy
**Depends on**: Phase 9
**Requirements**: None (tech debt — improves correctness for _bmad-output/ projects and documentation accuracy)
**Gap Closure:** Closes 4 tech debt items from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. Route C file-state ladder in wizard-backing-agent.md aligns with wizard-detect.sh (VERIFICATION.md condition either added to detection or removed from ladder)
  2. bmad-gsd-orchestrator.md Operation B Step 2 scans both `docs/stories/` and `_bmad-output/` paths
  3. bmad-gsd-orchestrator.md config.json template uses dynamic bmad_source paths (not hardcoded `docs/`)
  4. ROADMAP.md Phase 1 and Phase 7 checkboxes and progress table reflect completed status; all plan checkboxes for completed phases are checked
**Plans:** 1/1 plans complete

Plans:
- [x] 10-01-PLAN.md -- Fix Route C ladder alignment, Operation B dual-path, config.json dynamic paths, and ROADMAP checkboxes

### Phase 11: Final Global Deployment Sync
**Goal**: Global skill files in ~/.claude/skills/ match project-local versions after Phase 10 changes, and the stale Option 3 cross-reference label is fixed
**Depends on**: Phase 10
**Requirements**: None (deployment sync — closes integration gap #14 and flow gap from v1.0 final audit)
**Gap Closure:** Closes 1 integration gap + 1 flow gap + 1 tech debt item from v1.0 final audit
**Success Criteria** (what must be TRUE):
  1. `wizard.md` gsd-only non-uat-passing Option 3 cross-reference says "Option 3" (not "Option 4")
  2. `~/.claude/skills/wizard-detect.sh` matches project-local `skills/wizard-detect.sh` (includes VERIFICATION.md ladder step)
  3. `~/.claude/skills/wizard.md` matches project-local `skills/wizard.md` (includes Option 3 fix + complete status handling)
  4. `~/.claude/skills/wizard-backing-agent.md` matches project-local `skills/wizard-backing-agent.md`
  5. Diff between global and project-local skill files shows zero differences
**Plans:** 1/1 plans complete

Plans:
- [x] 11-01-PLAN.md -- Fix Option 3 label in wizard.md and redeploy all 3 skill files to ~/.claude/skills/

</details>

---

### 🚧 v1.1 Dynamic Toolkit Discovery (In Progress)

**Milestone Goal:** Make the wizard and all subagents aware of the user's full toolkit — agents, skills, tools, hooks, and MCP servers — so every workflow stage leverages the best available capabilities with user confirmation when ambiguous.

- [x] **Phase 12: Core Discovery Scanner** - Build toolkit-discovery.sh to scan all installed agents, skills, hooks, and MCP servers; apply stage tagging; write full registry and emit compact summary with TTL caching (completed 2026-03-13)
- [x] **Phase 13: State Integration** - Wire toolkit-discovery.sh into wizard-detect.sh so every wizard startup embeds a compact toolkit summary in wizard-state.json (completed 2026-03-13)
- [x] **Phase 14: Subagent Injection and Confirmation UX** - Inject stage-filtered capability pointers into GSD and BMAD subagent Task() spawns; add batched confirmation flow for unknown tools; implement lazy full-registry loading (completed 2026-03-13)
- [ ] **Phase 15: Dynamic Catalog Display** - Replace hardcoded Phase 7 catalog with dynamic registry-backed display grouped by stage and category, with hardcoded fallback when registry is absent
- [ ] **Phase 16: Global Deployment Sync** - Sync verified toolkit-discovery.sh, wizard-detect.sh, and wizard.md to ~/.claude/skills/; confirm toolkit-registry.json is gitignored

## Phase Details

### Phase 12: Core Discovery Scanner
**Goal**: A standalone script scans the user's full installed toolkit and produces a well-formed registry that all downstream injection and display logic can depend on
**Depends on**: Phase 11 (v1.0 complete)
**Requirements**: DISC-01, DISC-02, DISC-03, DISC-04, DISC-05, MATCH-01, MATCH-02, PERF-01
**Research flag**: SKIP — patterns fully documented in STACK.md and ARCHITECTURE.md; build from those specs
**Success Criteria** (what must be TRUE):
  1. Running `bash skills/toolkit-discovery.sh` produces valid JSON (passes `python3 -m json.tool`) with non-empty agent/skill/hook/mcp counts matching `ls ~/.claude/agents/ | wc -l`
  2. Every discovered tool entry carries a `stages` array containing at least one of research/planning/execution/review, derived from keyword matching on its description field
  3. `toolkit-registry.json` is written to disk and contains the full catalog; compact summary JSON is emitted to stdout with all counts and stage-relevant pointers
  4. Re-running the script within the TTL window skips rescan and returns the cached registry (observable: second run completes in under 0.1 seconds)
  5. Running the script when `~/.claude/agents/` does not exist produces a valid empty-catalog JSON (no error exit code)
**Plans:** 1/1 plans complete

Plans:
- [ ] 12-01-PLAN.md -- Create toolkit-discovery.sh with full scanning, stage tagging, registry write, compact summary, and TTL caching

### Phase 13: State Integration
**Goal**: Every `/wizard` invocation automatically carries a compact toolkit summary so the wizard has stage-relevant tool awareness from the first line of execution, with no startup latency increase
**Depends on**: Phase 12
**Requirements**: PERF-02
**Research flag**: SKIP — integration is mechanical; exact insertion point documented in ARCHITECTURE.md
**Success Criteria** (what must be TRUE):
  1. After running `bash skills/wizard-detect.sh`, the resulting `wizard-state.json` contains a `toolkit` object with discovery counts and stage-relevant pointer arrays
  2. The `toolkit` section adds no more than ~600 bytes to `wizard-state.json` (measure with `wc -c`)
  3. All existing wizard-state.json fields (scenario, project_type, next_command, etc.) are unchanged — the `toolkit` addition is purely additive
  4. Running wizard-detect.sh on a machine where toolkit-discovery.sh has never run produces a valid wizard-state.json with an empty `toolkit` object (no crash, no missing fields)
**Plans**: 1 plan

Plans:
- [ ] 13-01-PLAN.md -- Wire toolkit-discovery.sh into wizard-detect.sh with compact summary in wizard-state.json and status box display

### Phase 14: Subagent Injection and Confirmation UX
**Goal**: GSD and BMAD subagents spawned via Task() receive a compact, stage-filtered block of capability pointers so they can leverage the user's installed toolkit without the user having to manually reference tools
**Depends on**: Phase 13
**Requirements**: INJ-01, INJ-02, INJ-03, INJ-04, CONF-01, CONF-02, CONF-03, PERF-03
**Research flag**: NEEDS — read `~/.claude/get-shit-done/workflows/` GSD Task() prompt templates before writing any injection code; injection format must not break GSD subagent first-tool-call behavior
**Success Criteria** (what must be TRUE):
  1. Running `/wizard` mid-execution and selecting "Check drift" causes context-health-monitor to receive a capability suffix; the suffix does not appear as user-visible output in the wizard turn
  2. The injected capability block contains at most 5-8 pointers and totals no more than ~200 tokens (verify with token count before/after)
  3. Keystone/GSD agents and read-only MCPs (e.g., context7) inject without triggering a confirmation prompt; at most one batched confirmation question appears per `/wizard` invocation for unknown tools
  4. Capability pointers are appended only to Task()/Agent() spawn calls — Skill() invocations receive no injection (verify by text search)
  5. MCP recommendations in the injected block use conditional language ("configured — availability may vary"), not definitive language ("available")
  6. "Discover tools" is not selected (not triggered by a menu action) — the full registry is not loaded; wizard startup token cost is unchanged (verify by measuring context window before/after injection is added)
**Plans**: 2 plans

Plans:
- [ ] 14-01-PLAN.md -- Wizard-side injection: Step 2.5 confirmation UX, trust classification, capability injection for Agent()/Task() spawns in wizard.md and wizard-backing-agent.md
- [ ] 14-02-PLAN.md -- GSD workflow injection: capability injection for Task() spawns in plan-phase.md, execute-phase.md, and research-phase.md
### Phase 15: Dynamic Catalog Display
**Goal**: "Discover tools" shows the user's actual installed toolkit from the live registry rather than a hardcoded snapshot, grouped by stage relevance and category, with the hardcoded Phase 7 catalog as a fallback for fresh installs
**Depends on**: Phase 12
**Requirements**: CAT-01, CAT-02, CAT-03
**Research flag**: SKIP — grouping and display format specified in FEATURES.md; fallback pattern is standard
**Success Criteria** (what must be TRUE):
  1. Selecting "Discover tools" and having a valid `toolkit-registry.json` present displays tool count matching `ls ~/.claude/agents/ | wc -l` — not the hardcoded 11-agent count
  2. Tools are grouped first by stage relevance (research / planning / execution / review) and then by category within each stage
  3. On a fresh install where `toolkit-registry.json` does not exist, "Discover tools" shows the hardcoded Phase 7 catalog without errors or missing sections
  4. Every tool entry in the hardcoded Phase 7 catalog appears in the dynamic output when the registry is present (parity check passes before hardcoded text can be removed)
**Plans**: TBD
### Phase 16: Global Deployment Sync
**Goal**: Verified v1.1 skill files are live for all projects and machine-specific toolkit data is confirmed gitignored before closing the milestone
**Depends on**: Phase 15
**Requirements**: None (deployment sync — makes all v1.1 changes available globally and closes machine-specific data leak risk)
**Success Criteria** (what must be TRUE):
  1. `~/.claude/skills/toolkit-discovery.sh` exists and matches project-local `skills/toolkit-discovery.sh`
  2. `~/.claude/skills/wizard-detect.sh` matches project-local `skills/wizard-detect.sh` (includes toolkit discovery call and `toolkit{}` JSON write)
  3. `~/.claude/skills/wizard.md` matches project-local `skills/wizard.md` (includes Step 2.5 injection block and dynamic catalog read)
  4. Running `/wizard` from a project outside the Keystone directory correctly discovers tools from `~/.claude/agents/` (global path, not project-local path)
  5. `toolkit-registry.json` appears in `.gitignore` and does not appear in `git status` output
**Plans**: TBD
## Progress

**Execution Order:**
Phases execute in numeric order: 12 → 13 → 14 → 15 → 16

Note: Phase 14 and Phase 15 both depend on Phase 12 and could be built in parallel, but Phase 14 (injection) is the core value proposition of v1.1 and should be completed and validated before Phase 15 (display). Phase 16 executes last after both are verified.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 12. Core Discovery Scanner | 1/1 | Complete    | 2026-03-13 | - |
| 13. State Integration | 1/1 | Complete    | 2026-03-13 | - |
| 14. Subagent Injection and Confirmation UX | 2/2 | Complete   | 2026-03-13 | - |
| 15. Dynamic Catalog Display | v1.1 | 0/? | Not started | - |
| 16. Global Deployment Sync | v1.1 | 0/? | Not started | - |
