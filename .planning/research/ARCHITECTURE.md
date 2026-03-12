# Architecture Research

**Domain:** Wizard orchestrator for Claude Code skill/agent ecosystem
**Researched:** 2026-03-11
**Confidence:** HIGH (derived entirely from first-party codebase analysis — no external sources needed)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Entry Point                            │
│                   /wizard  (slash command)                          │
└─────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SMART ROUTER SKILL                               │
│              ~/.claude/skills/wizard-router                         │
│                                                                     │
│  1. Read .planning/ markers (GSD state)                             │
│  2. Read _bmad/ / .bmad/ markers (BMAD state)                       │
│  3. Read git state (branch, uncommitted)                            │
│  4. Determine scenario (A/B/C/D)                                    │
│  5. Load wizard-state.json if it exists                             │
│  6. Delegate to WIZARD SKILL with detected context                  │
└─────────────────────────┬───────────────────────────────────────────┘
                           │  (context blob passed via file write)
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       WIZARD SKILL                                  │
│             ~/.claude/skills/wizard-interactive                     │
│                                                                     │
│  1. Receives: scenario, project state, last wizard-state            │
│  2. Presents: state banner + numbered menu choices                  │
│  3. Collects: user intent (choice 1-N)                              │
│  4. Persists: choice to .planning/wizard-state.json                 │
│  5. Delegates: to BACKING AGENT via Task() with intent              │
└─────────────────────────┬───────────────────────────────────────────┘
                           │  (Task() spawn with full intent context)
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      BACKING AGENT                                  │
│         ~/.claude/agents/wizard/wizard-orchestrator.md              │
│                                                                     │
│  1. Reads: wizard-state.json (intent, scenario, phase)              │
│  2. Routes to appropriate existing agent:                           │
│     ├── bmad-gsd-orchestrator       (BMAD→GSD handoff)             │
│     ├── doc-shard-bridge            (context sharding)              │
│     ├── phase-gate-validator        (phase gates)                   │
│     ├── context-health-monitor      (drift detection)               │
│     ├── project-setup-wizard        (new project setup)             │
│     └── project-setup-advisor       (advisory only)                 │
│  3. Executes: orchestration work using existing agents as tools      │
│  4. Updates: wizard-state.json with new position                    │
│  5. Returns: result summary + next recommended action                │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Lives At | Size Target |
|-----------|----------------|----------|-------------|
| Smart router skill | State detection, scenario classification, context handoff | `~/.claude/skills/wizard-router` | < 100 lines |
| Wizard skill | Interactive UI, menu presentation, intent capture, state persistence | `~/.claude/skills/wizard-interactive` | < 200 lines |
| Backing agent | Heavy orchestration, agent routing, work execution | `~/.claude/agents/wizard/wizard-orchestrator.md` | < 400 lines |
| wizard-state.json | Cross-context persistence, wizard position memory | `.planning/wizard-state.json` | Schema-bounded |

## Recommended Project Structure

```
claude-code-stack/
├── agents/
│   ├── entry/                         # existing — unchanged
│   ├── bridge/                        # existing — unchanged
│   ├── domain/                        # existing — unchanged
│   ├── maintenance/                   # existing — unchanged
│   └── wizard/                        # NEW category
│       └── wizard-orchestrator.md     # NEW backing agent
├── skills/                            # NEW top-level directory
│   ├── wizard-router                  # NEW skill (no extension — Claude Code skill format)
│   └── wizard-interactive             # NEW skill
├── .planning/
│   └── wizard-state.json              # NEW state file (generated at runtime)
└── scripts/
    └── install-runtime-support.sh     # MODIFIED to deploy skills
```

### Structure Rationale

- **agents/wizard/:** New agent category, not bridge or entry. The orchestrator is its own category because it wraps both. Keeps existing agent categories clean and unchanged.
- **skills/:** Claude Code skills live separately from agents. Skills are loaded as context snippets (descriptions only), full content loads on invocation. This is the context-budget mechanism.
- **.planning/wizard-state.json:** Colocated with other GSD state (config.json, STATE.md). Survives context resets because it's a file, not memory. Consistent with the project's existing state management convention.

## Architectural Patterns

### Pattern 1: Skill as Thin Delegation Layer

**What:** Skills in Claude Code are read as description text on load; full content loads only when invoked. The wizard skills exploit this: the router detects state and writes context to a file, then the wizard skill reads that file and delegates to the backing agent. No logic lives in skills beyond detection and delegation.

**When to use:** When context budget matters. The entire wizard overhead (two skills + state file read) consumes < 10% of context window. The heavy work runs in the backing agent which has a clean context.

**Trade-offs:** Adding a file I/O round-trip between skills. This is negligible for file system reads but must be explicit in the design — skills cannot directly pass objects to agents, they communicate through files.

**Invocation chain:**
```
/wizard
  → router skill (reads project state → writes .planning/wizard-state.json)
  → wizard skill (reads wizard-state.json → presents menu → writes user intent)
  → Task(wizard-orchestrator agent, reads wizard-state.json → executes → updates state)
```

### Pattern 2: Scenario-Based Menu Routing

**What:** The wizard presents different menus based on detected project state. Four scenarios (A: neither installed, B: GSD only, C: BMAD only, D: both active) map to four menu sets. The router detects scenario; the wizard skill contains all four menus.

**When to use:** When users can arrive at the same entry point from multiple positions in the lifecycle.

**Trade-offs:** The wizard skill must contain all four menu variants. At ~50 lines each, this totals ~200 lines — within target. If menus grow beyond 4 scenarios, consider splitting into scenario-specific sub-skills.

**Scenario detection logic (router skill):**
```bash
HAS_GSD=false; HAS_BMAD=false
[ -d ".planning" ] && [ -f ".planning/config.json" ] && HAS_GSD=true
{ [ -d "_bmad" ] || [ -d ".bmad" ]; } && HAS_BMAD=true

# Scenario assignment
if $HAS_GSD && $HAS_BMAD; then SCENARIO="D"
elif $HAS_GSD; then          SCENARIO="B"
elif $HAS_BMAD; then         SCENARIO="C"
else                          SCENARIO="A"; fi
```

### Pattern 3: State-File-Mediated Agent Communication

**What:** wizard-state.json is the communication channel between all three components. It is written by the router, enriched by the wizard skill, and consumed + updated by the backing agent. Its schema is the interface contract.

**When to use:** When components run in separate contexts (different skill invocations, Task() spawned agents). Files are the only reliable cross-context communication in Claude Code.

**Trade-offs:** Schema must be stable. Any change to wizard-state.json format is a breaking change for all three components. Pin the schema in Phase 1 and treat changes as migrations.

**Schema (initial):**
```json
{
  "schema_version": 1,
  "scenario": "D",
  "project_name": "my-project",
  "bmad_state": {
    "has_bmad": true,
    "prd_found": true,
    "arch_found": true,
    "stories_total": 5,
    "stories_approved": 3,
    "stories_done": 1
  },
  "gsd_state": {
    "has_gsd": true,
    "phase": "Phase 2",
    "milestone": "v1.0",
    "next_command": "/gsd:execute-phase 2"
  },
  "git_state": {
    "branch": "main",
    "uncommitted": 0
  },
  "user_intent": "resume",
  "last_updated": "2026-03-11T10:00:00Z",
  "wizard_position": "post-menu"
}
```

### Pattern 4: Wrapper-Not-Replacer Agent Routing

**What:** The backing agent routes to existing agents by invoking them via explicit agent delegation, not by reimplementing their logic. It acts as a dispatcher — it reads the user intent and translates it to the appropriate existing agent invocation.

**When to use:** This is the core constraint from PROJECT.md: "wrap existing agents, not replace them." Preserves modularity and means existing agents can be tested and improved independently.

**Routing table (intent → agent):**
```
"start-new-project"     → project-setup-wizard (entry)
"continue-bmad"         → project-setup-advisor (entry) + BMAD commands
"bridge-to-gsd"         → bmad-gsd-orchestrator (bridge)
"resume-gsd"            → detect phase state → emit /gsd: command directly
"validate-phase"        → phase-gate-validator (bridge)
"check-drift"           → context-health-monitor (bridge)
"shard-docs"            → doc-shard-bridge (bridge)
"new-milestone"         → /gsd:new-milestone command
```

## Data Flow

### Request Flow (Happy Path — Resume GSD)

```
1. User types: /wizard
2. Router skill runs:
   - Reads .planning/config.json → GSD active, phase 2
   - Reads _bmad/ → BMAD also present
   - Reads git status → clean working tree
   - Writes .planning/wizard-state.json (scenario=D, gsd_state, bmad_state)

3. Wizard skill runs:
   - Reads .planning/wizard-state.json
   - Presents STATE D banner (FULL STACK)
   - Shows menu: 1=Resume, 2=New phase, 3=New milestone, 4=Back to BMAD, 5=Explain
   - User types: 1
   - Writes user_intent="resume" to wizard-state.json
   - Calls Task(wizard-orchestrator, "execute resume intent")

4. Backing agent runs:
   - Reads wizard-state.json (intent=resume, phase=2, next_command="/gsd:execute-phase 2")
   - Emits: "Run /gsd:execute-phase 2 — plans are ready."
   - Updates wizard-state.json (wizard_position="dispatched")
```

### Request Flow (Context Reset Recovery)

```
1. User had stopped mid-phase; new Claude session started
2. User types: /wizard
3. Router skill:
   - Reads .planning/wizard-state.json (exists from last session)
   - Detects wizard_position="post-execute-phase-2"
   - Passes prior_state to wizard skill
4. Wizard skill:
   - Notes: "Resuming from last session"
   - Shows what happened last, then current menu
   - User can continue without re-detecting from scratch
```

### State Lifecycle

```
New project (no files):
  wizard-state.json does not exist
  → Router creates it with scenario=A, no prior state

Mid-project (GSD active):
  wizard-state.json exists from previous invocation
  → Router re-reads project state, updates bmad_state + gsd_state
  → Preserves: user_intent history, wizard_position

Context reset:
  wizard-state.json survives (it's a file)
  → Wizard skill reads it to understand last position
  → Provides continuity message: "Last session: Phase 2 execution"
```

## Component Boundaries

### What Each Component Must Not Do

| Component | Must NOT do |
|-----------|-------------|
| Smart router skill | Present UI, ask questions, run heavy work |
| Wizard skill | Detect project state (reads router's output only), execute orchestration |
| Backing agent | Present interactive menus, collect user input |
| wizard-state.json | Contain implementation logic, grow unboundedly (cap at 50 fields) |

### Interface Contracts

**Router → Wizard skill:**
- Router writes: `wizard-state.json` with detected scenario + state
- Wizard reads: `wizard-state.json` to render correct menu

**Wizard skill → Backing agent:**
- Wizard writes: `user_intent` field in `wizard-state.json`
- Wizard spawns: `Task(prompt="wizard-orchestrator: execute intent from .planning/wizard-state.json")`
- Agent reads: full `wizard-state.json`

**Backing agent → Existing agents:**
- Agent invokes: existing agents by name (not by spawning Task — by describing them in the `description` field which triggers Claude Code agent routing)
- Or emits: exact slash commands for user to run (e.g., `/gsd:execute-phase 2`)
- Updates: `wizard-state.json` with outcome

## Integration Points with Existing Agents

### project-setup-wizard (entry)
- **Called by:** Backing agent for Scenario A (clean slate) and when user chooses "Explain first"
- **Overlap risk:** project-setup-wizard already detects state and presents menus. This creates potential duplication.
- **Resolution:** For Scenario A, the wizard-orchestrator backing agent delegates entirely to project-setup-wizard — it does not recreate its menus. The smart router is the differentiator: it detects state before the project-setup-wizard runs and can short-circuit to the right scenario menu directly.

### bmad-gsd-orchestrator (bridge)
- **Called by:** Backing agent for intent "bridge-to-gsd" (Scenario C, choice 1)
- **Integration:** Agent invokes bmad-gsd-orchestrator and surfaces its confirmation output to user

### doc-shard-bridge (bridge)
- **Called by:** Backing agent as post-phase completion step (after phase-gate-validator passes)
- **Integration:** Automatic — user does not explicitly invoke it; wizard wraps it into the "complete phase" flow

### phase-gate-validator (bridge)
- **Called by:** Backing agent for intent "validate-phase"
- **Integration:** Wizard surfaces gate results and, if PASS, automatically invokes doc-shard-bridge

### context-health-monitor (bridge)
- **Called by:** Backing agent for intent "check-drift" or after execute-phase
- **Integration:** Advisory only — backing agent surfaces the report without blocking

## Build Order and Phase Dependencies

### Phase 1: State Persistence Foundation (Build First)

**Deliverable:** `wizard-state.json` schema + router skill detection logic

**Why first:** Everything depends on the state file. The schema is the contract between all three components. If you build the wizard skill before the schema is stable, you will rebuild it.

**Blocking for:** Phase 2 (wizard skill reads state), Phase 3 (backing agent reads state)

**What to build:**
- Define and freeze wizard-state.json schema (v1)
- Implement smart router skill (reads project state, writes wizard-state.json)
- Test: invoke /wizard in all four scenarios (A/B/C/D), verify correct JSON written

### Phase 2: Wizard Skill UI (Build Second)

**Deliverable:** Interactive menu skill that reads state and captures intent

**Why second:** Depends on Phase 1 schema. Can be built and tested without the backing agent — in isolation, wizard skill can verify menus render correctly and intent is written to state file.

**Blocking for:** Phase 3 (backing agent is only useful when wizard can invoke it)

**What to build:**
- Wizard skill with all four scenario menus
- Intent capture and wizard-state.json update
- Task() invocation pattern to backing agent
- Stub backing agent (just confirms it received intent) for testing

### Phase 3: Backing Agent Routing (Build Third)

**Deliverable:** wizard-orchestrator agent that dispatches to existing agents

**Why third:** Depends on Phases 1 and 2. Should be built agent-by-agent: implement one intent route at a time, verify it works end-to-end before adding the next.

**Suggested route order:**
1. "resume" (simplest — emits a command string, no agent invocation)
2. "bridge-to-gsd" (invokes bmad-gsd-orchestrator — most common new-user flow)
3. "validate-phase" (invokes phase-gate-validator)
4. "check-drift" (invokes context-health-monitor)
5. "start-new-project" (delegates to project-setup-wizard)

### Phase 4: Context Reset Recovery (Polish)

**Deliverable:** Router reads prior wizard-state.json and surfaces continuity message

**Why last:** Non-blocking feature. State file survives context resets from Phase 1 onwards. Phase 4 adds the UX layer — detecting and presenting the prior session context in the wizard menu.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Reimplementing Existing Agent Logic in Wizard

**What:** Building detection, menu, or orchestration logic in wizard-orchestrator that already exists in project-setup-wizard, bmad-gsd-orchestrator, etc.

**Why bad:** Creates two code paths for the same logic. When the existing agent is updated, the wizard does not get the update. Breaks the "wrap, don't replace" constraint from PROJECT.md.

**Instead:** Wizard skill presents menus, backing agent dispatches to existing agents. If existing agent behavior needs to change, change the existing agent.

### Anti-Pattern 2: Heavy Work in Skills

**What:** Putting significant bash detection, file parsing, or orchestration logic in the router or wizard skills (not the backing agent).

**Why bad:** Skills are loaded as context on every session start. Heavy skills consume context budget even when not used. The 10% overhead constraint from PROJECT.md is violated.

**Instead:** Router skill does only the minimum detection needed to identify scenario (5 bash checks, < 50 lines). All heavy work goes to the backing agent which only runs when explicitly invoked.

### Anti-Pattern 3: Chatty State File Writes

**What:** Router and wizard skill updating wizard-state.json on every session start even when user hasn't invoked /wizard.

**Why bad:** The session-start hook already writes project state to a banner. Duplicating this in wizard-state.json on every session start adds write overhead and creates potential conflicts with the existing session-start.sh hook.

**Instead:** Router only writes wizard-state.json when /wizard is explicitly invoked. Read project state markers (the ones session-start.sh already checks) but don't persist to wizard-state.json during passive session hooks.

### Anti-Pattern 4: Wizard as Entry for Every Scenario

**What:** Routing all project state decisions through /wizard, replacing the existing session-start.sh banner and project-setup-advisor.

**Why bad:** The session-start.sh hook and project-setup-advisor serve different use cases (passive/informational vs. active/guided). Replacing them breaks existing users who rely on the banner.

**Instead:** /wizard is an opt-in command. Session-start.sh continues running independently. Wizard coexists with, does not replace, the hook.

### Anti-Pattern 5: Unstable wizard-state.json Schema

**What:** Adding fields to wizard-state.json incrementally across phases without a versioned schema.

**Why bad:** wizard-state.json is the contract between all three components. If the backing agent expects a field that the router doesn't write yet, it fails silently. This is particularly bad because the failure may only appear after a context reset.

**Instead:** Define the full schema in Phase 1. Mark optional fields as such in comments. Add `schema_version` field and check it in all consumers.

## Scalability Considerations

| Concern | Current State | At 10 wizard users | Risk |
|---------|---------------|--------------------|------|
| Context budget | 3 components loaded per /wizard invocation | Scales linearly with skill size, not users | LOW — keep skills thin |
| State file growth | wizard-state.json bounded by schema | Does not grow with usage | LOW |
| Menu complexity | 4 scenarios, 5 choices each | Cap at 4 scenarios; add new entries, not new scenarios | MEDIUM — scenarios drive complexity |
| Agent routing table | 5 intents in backing agent | Each new intent = new routing case | LOW — adding cases is isolated |
| Overlap with project-setup-wizard | Both detect project state | Risk of diverging detection logic | HIGH — router must reuse same detection shell as project-setup-wizard |

## Sources

All findings are derived from first-party source code analysis of the Claude Code Stack repository. Confidence is HIGH because:
- All components are fully readable (agents/**, hooks/**, skills/, .planning/)
- Claude Code skill/agent system is used by existing agents (project-setup-wizard, phase-gate-validator, etc.)
- State management pattern (file-based, .planning/ directory) is proven by existing GSD workflows
- The three-component architecture (router skill + wizard skill + backing agent) is described explicitly in .planning/PROJECT.md

No external sources were required. The design question is architectural (how to compose existing components) not ecosystem discovery (what exists).
