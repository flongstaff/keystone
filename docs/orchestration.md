# Orchestration Workflows

All four project scenarios across Claude Code, OpenCode, and Pi.

---

## Runtime Comparison

| Capability            | Claude Code          | OpenCode             | Pi                     |
|-----------------------|----------------------|----------------------|------------------------|
| Agent system          | ~/.claude/agents/    | Built-in             | ~/.pi/agent/ AGENTS.md |
| Slash commands        | Yes (/gsd:*, /bmad-*)| Yes                  | Prompt templates (/name)|
| Sub-agents            | Yes (native)         | Yes                  | Via tmux / extensions  |
| Hooks                 | SessionStart, etc.   | Limited              | Extensions (TypeScript)|
| GSD native support    | ✓ full               | ✓ full               | ⚠ manual workflow only  |
| BMAD native support   | ✓ full               | ✓ full               | ⚠ via AGENTS.md        |
| Best for              | Complex, multi-phase | Routine tasks        | Custom/exploratory      |

**Recommendation:**
- Use **Claude Code** for: BMAD planning, bridge operations, complex GSD phases
- Use **OpenCode** for: dependency upgrades, routine scripting, quick fixes
- Use **Pi** for: exploratory work, custom tooling, offline/local LLM sessions

---

## SCENARIO A — New Project

**Use when:** Starting from scratch with no existing code or framework.

### Decision: GSD only vs BMAD+GSD

```
Duration < 3 days + scope < feature + risk = low     → GSD only
Duration > 1 week OR scope = system OR risk > low    → BMAD + GSD
Multi-team OR unclear requirements OR complex        → BMAD + GSD (mandatory)
```

### Path 1: GSD Only (small/focused projects)

**Claude Code or OpenCode:**
```bash
# Install
npx get-shit-done-cc --claude --global    # Claude Code
npx get-shit-done-cc --opencode --global  # OpenCode

# Restart runtime, then:
/gsd:new-project
# Fill in: name, description, tech stack, constraints
# System generates: ROADMAP.md, REQUIREMENTS.md, PROJECT.md

# Execute loop (repeat per phase):
/gsd:discuss-phase 1
/gsd:plan-phase 1
/gsd:execute-phase 1
/gsd:verify-work 1
# → Run: phase-gate-validator for phase 1
# → Run: /gsd:discuss-phase 2 to continue

# Quick tasks (no planning needed):
/gsd:quick "describe what you want"
/gsd:quick --full "task needing verification"
/gsd:quick --discuss "task needing context first"
```

**Pi:**
```bash
# Install Pi
npm install -g @mariozechner/pi-coding-agent

# Create project plan manually (Pi has no plan mode)
cat > .planning/pi-plan.md << 'EOF'
# Project Plan
## Phase 1: [name]
### Objective: [goal]
### Tasks:
- [ ] Task 1
- [ ] Task 2
### Done when: [acceptance criteria]
EOF

# In Pi session: "Read .planning/pi-plan.md and implement Phase 1.
#  Work through tasks sequentially, commit after each one."
```

### Path 2: BMAD + GSD (medium/large projects)

#### Step 1: Install (all runtimes)

```bash
npx bmad-method install
npx get-shit-done-cc --claude --global    # Claude Code
npx get-shit-done-cc --opencode --global  # OpenCode
npm install -g @mariozechner/pi-coding-agent  # Pi
```

#### Step 2: Create project context file

**Claude Code:** Create `.claude/CLAUDE.md`
**Pi:** Create `AGENTS.md` in project root
**OpenCode:** Create `CLAUDE.md` in project root

Minimum content:
```markdown
# [Project Name]

## What This Is
[One paragraph describing the project]

## Tech Stack
[Languages, frameworks, tools]

## Key Conventions
[Naming, structure, patterns]

## Project Type
[infra / web / game / docs]
```

#### Step 3: BMAD Planning Phase

Run in Claude Code (highest context window):

```
/product-brief
```
Answer all analyst questions. Output: product brief doc.

```
/prd
```
PM produces requirements with acceptance criteria per epic.

```
/architecture
```
Architect designs: stack, structure, data model, conventions.

```
/workflow-status
```
Verify all three docs are complete. Do not proceed until green.

#### Step 4: Bridge (Claude Code)

Say: `"initialise GSD from these BMAD docs"`

The `bmad-gsd-orchestrator` agent:
1. Validates PRD and Architecture exist and are complete
2. Creates `.planning/config.json` (BMAD epics → GSD phases)
3. Creates `.planning/CONTEXT.md` (master context)
4. Creates `.planning/context/phase-N-context.md` (per-phase shards)
5. Creates `bmad-outputs/STATUS.md` (progress tracking)

Then the `doc-shard-bridge` agent runs to trim shards to <800 lines each.

#### Step 5: GSD Build Loop

Run in Claude Code or OpenCode:

```
# For each phase N = 1, 2, 3...:
/gsd:discuss-phase N      # Lock decisions — loads BMAD context automatically
/gsd:plan-phase N         # Research + atomic task plans
/gsd:execute-phase N      # Fresh 200k context per task, atomic commits
/gsd:verify-work N        # Goal-backward verification
```

After execute-phase, before verify-work:
- Say: `"run context-health-monitor"` → advisory drift check

After verify-work passes:
- Say: `"is phase N done?"` → phase-gate-validator runs all 5 gates
- Only advance when gate returns ADVANCE verdict

Between phases:
- `doc-shard-bridge` syncs GSD phase completion → BMAD story status

When all phases complete:
```
/gsd:complete-milestone
/gsd:new-milestone        # For next feature batch
```

---

## SCENARIO B — GSD Only (add BMAD)

**Use when:** Project has GSD (.planning/) but no BMAD planning docs.

### Step 1: Map existing codebase (Claude Code)

```
/gsd:map-codebase
```
Spawns 4 parallel agents: ARCHITECTURE.md, CONVENTIONS.md, CONCERNS.md, DEPENDENCIES.md

Then: `"run context-health-monitor"` → check current state vs original intent.

### Step 2: Install and add BMAD docs

```bash
npx bmad-method install
```

In Claude Code:
```
/product-brief
```
Document what the project **actually is** (as-built, not aspirational).

```
/architecture
```
Architect reads the actual codebase and documents real patterns.

> **Skip /prd** unless you're planning a new milestone.
> The PRD is for future work, not retroactive documentation.

### Step 3: Bridge existing state

Say: `"run doc-shard-bridge on existing docs"`

This shards the new BMAD docs into GSD phase context files.
GSD subagents now load architecture constraints automatically at spawn.

### Step 4: Continue with enhanced GSD

```
/gsd:new-milestone
```
Start next feature batch. Now pre-loaded with BMAD architecture context.

Resume normal GSD loop:
```
/gsd:discuss-phase N
/gsd:plan-phase N
/gsd:execute-phase N
/gsd:verify-work N
```

---

## SCENARIO C — BMAD Only (add GSD)

**Use when:** Project has BMAD docs (PRD, architecture) but no GSD execution setup.

### Step 1: Verify BMAD docs are complete

```
/workflow-status
```

Check: PRD ✓, Architecture ✓, at minimum.

If missing:
```
/prd          # if PRD missing or incomplete
/architecture # if Architecture missing
```

Do not proceed until both are present.

### Step 2: Install GSD

```bash
npx get-shit-done-cc --claude --global    # Claude Code
npx get-shit-done-cc --opencode --global  # OpenCode (if using)
npm install -g @mariozechner/pi-coding-agent  # Pi (if using)
```

### Step 3: Bridge BMAD → GSD

Say: `"initialise GSD from existing BMAD docs"`

`bmad-gsd-orchestrator` reads `docs/` and `bmad-outputs/` and creates:
- `.planning/config.json` — BMAD epics mapped to GSD phases
- `.planning/CONTEXT.md` — master context
- `.planning/context/phase-N-context.md` — per-phase shards

> **Do NOT run `/gsd:new-project`** — orchestrator already set up `.planning/`.
> Running new-project would overwrite the BMAD-derived configuration.

### Step 4: Begin execution

```
/gsd:discuss-phase 1      # Pre-loaded with BMAD architecture context
/gsd:plan-phase 1         # Plans align with BMAD stories automatically
/gsd:execute-phase 1      # Executors respect BMAD constraints via CONTEXT.md
/gsd:verify-work 1        # Checks against BMAD acceptance criteria
```

Gate check:
```
"is phase 1 done?"        # phase-gate-validator checks BMAD criteria
```

BMAD story files updated automatically by `doc-shard-bridge` after each gate pass.

---

## SCENARIO D — No Framework (bare project)

**Use when:** Code exists but neither BMAD nor GSD is set up. Or starting fresh with no preference.

### Step 1: Assess complexity

| Situation | Path |
|-----------|------|
| Quick script or task (<1 day) | `/gsd:quick "describe it"` — no install needed |
| Small project (1–3 days) | GSD only |
| Medium project (1–4 weeks) | BMAD + GSD |
| Complex / multi-component | BMAD + GSD (mandatory) |

### Step 2: Install

```bash
# GSD only:
npx get-shit-done-cc --claude --global

# BMAD + GSD (install BMAD first):
npx bmad-method install
npx get-shit-done-cc --claude --global
```

### Step 3: Create context file first

Before running any framework command, create the project context:

**Claude Code** — `.claude/CLAUDE.md`:
```markdown
# [Project Name]
[description, tech stack, conventions, project type]
```

**Pi** — `AGENTS.md` in project root:
```markdown
# [Project Name]
[same content as above]
```

### Step 4: Kick off

**GSD only path:**
```
/gsd:new-project
```
Fill in the questions. System generates ROADMAP.md + REQUIREMENTS.md.
Then start the build loop from Step 5 of Scenario A.

**BMAD + GSD path:**
Follow Scenario A from Step 3.

---

## Pi-Specific Workflow Notes

Pi has no native GSD or BMAD commands. Adapt the workflow as follows:

### BMAD in Pi

Pi can run BMAD if installed via BMAD's installer (generates prompt templates).
Access as prompt templates: type `/product-brief` to expand in Pi.

Or run BMAD in Claude Code first, then switch to Pi for execution.

### GSD-style execution in Pi

Pi's philosophy: "no plan mode — write plans to files."

```bash
# After BMAD planning or manual planning, create:
cat > .planning/pi-phase-1-plan.md << 'EOF'
# Phase 1 Plan
## Objective: [from BMAD epic]
## Tasks (atomic, sequential):
- [ ] Task 1: [specific, testable]
- [ ] Task 2: [specific, testable]
## Done when: [acceptance criteria from BMAD]
## Constraints: [from architecture doc]
EOF

# In Pi session:
# "Read .planning/pi-phase-1-plan.md and CONTEXT.md.
#  Implement tasks sequentially. Commit after each task.
#  Do not proceed to the next task until current one is done and verified."
```

### Pi parallel work (tmux)

For tasks that benefit from parallelism:
```bash
tmux new-session -d -s phase1-task1 'pi "implement task 1 from .planning/pi-phase-1-plan.md"'
tmux new-session -d -s phase1-task2 'pi "implement task 2 from .planning/pi-phase-1-plan.md"'
tmux attach -t phase1-task1
```

### Pi agent loading

Global agents: deploy to `~/.pi/agent/`
Project agents: create `AGENTS.md` in project root

Pi loads in order: `~/.pi/agent/` → parent dirs → current dir.
Later files can extend or override earlier ones.

---

## Quick Reference — Command Cheat Sheet

### BMAD Commands
| Command | Agent | Purpose |
|---------|-------|---------|
| `/product-brief` | Analyst | Discover scope, users, constraints |
| `/prd` | PM | Write requirements + acceptance criteria |
| `/architecture` | Architect | Design tech stack and structure |
| `/workflow-status` | Master | Check completion of all agents |
| `/sprint-planning` | Scrum Master | Break epics into implementable stories |
| `/bmad-help` | Master | AI guidance on next steps |

### GSD Commands
| Command | Purpose |
|---------|---------|
| `/gsd:new-project` | Init new project — full questioning + roadmap |
| `/gsd:map-codebase` | 4 parallel agents map existing codebase |
| `/gsd:discuss-phase N` | Lock decisions before planning |
| `/gsd:plan-phase N` | Research + atomic XML task plans |
| `/gsd:execute-phase N` | Build with fresh 200k context per task |
| `/gsd:verify-work N` | Goal-backward verification |
| `/gsd:quick "task"` | Fast lane — no heavy planning |
| `/gsd:quick --full "task"` | Fast lane + verification gate |
| `/gsd:quick --discuss "task"` | Gather context first, then execute |
| `/gsd:complete-milestone` | Archive milestone, tag release |
| `/gsd:new-milestone` | Start next feature batch |
| `/gsd:settings` | Configure project settings |
| `/gsd:update` | Check for and install GSD updates |

### Bridge Agent Trigger Phrases
| Agent | Say this to trigger |
|-------|---------------------|
| project-setup-advisor | "set up this project" / "where do I start" |
| bmad-gsd-orchestrator | "initialise GSD from BMAD docs" / "hand off to GSD" |
| doc-shard-bridge | "shard documents" / "create phase context" / "sync phase N" |
| phase-gate-validator | "is phase N done?" / "can we advance?" / "gate check" |
| context-health-monitor | "check drift" / "health check" / "are we on track" |
| stack-update-watcher | "check for updates" / "stack health" / "any updates to BMAD" |
| it-infra-agent | auto-triggers on infra-related files and keywords |

---

## config.json Reference

Key settings in `.planning/config.json`:

```json
{
  "project_name": "...",
  "gsd_settings": {
    "auto_advance": false,        // ALWAYS false — never change
    "granularity": "standard",    // coarse / standard / fine
    "nyquist_validation": true,   // extra quality checks
    "model_overrides": {
      "planner": "claude-opus-4-5",
      "executor": "claude-sonnet-4-6",
      "verifier": "claude-sonnet-4-6"
    }
  },
  "runtime": "claude-code"        // claude-code / opencode / pi
}
```

---

*BMAD v6.0.4 · GSD v1.22.4 · Pi latest · March 2026*
