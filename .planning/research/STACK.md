# Technology Stack

**Project:** Keystone — Wizard Orchestrator for Claude Code Stack
**Researched:** 2026-03-11
**Domain:** Claude Code skill + agent extension system

---

## Context

This is a brownfield milestone. The project file format (Markdown with YAML frontmatter),
deployment targets (~/.claude/skills/, ~/.claude/agents/, ~/.claude/commands/), and runtime
(Claude Code) are fixed. The research question is: how do skills, agents, and slash commands
work so we can build wizard/orchestrator components that fit the existing patterns precisely?

---

## The Claude Code Extension Model

Claude Code has three extension primitives. They are distinct and compose in a specific direction.

### 1. Skills

**Location:** `~/.claude/skills/<skill-name>/SKILL.md`

**Format:**
```yaml
---
name: skill-name
description: What it does and when to use it (third person, specific triggers).
user-invocable: true | false
model: haiku | sonnet | opus
disable-model-invocation: true | false
context: fork (optional — fresh context window)
allowed-tools: Read, Write, Edit, Bash, ...
---
```

**Body structure:** Pure XML tags. No markdown headings in the skill body. Content uses markdown within tags. Required tags: `<objective>`, `<quick_start>`, `<success_criteria>`. Optional: `<intake>`, `<routing>`, `<process>`, `<anti_patterns>`.

**File organization:** Router pattern for complex skills:
```
skill-name/
├── SKILL.md              # Router + essential principles (< 500 lines)
├── workflows/            # Step-by-step procedures (read on demand)
├── references/           # Domain knowledge (read on demand)
├── templates/            # Output structures to copy and fill
└── scripts/              # Executable code run as-is
```

**Two skill types:**
- `user-invocable: true` — user runs `/skill-name` as a slash command
- `user-invocable: false` — preloaded into every Claude session; always active domain knowledge (e.g., git-workflow, code-standards, project-scaffolder)

**`context: fork`:** When present, the skill runs in a fresh context window rather than inheriting the parent session. Use for isolated sub-tasks.

**`disable-model-invocation: true`:** Prevents the skill from spawning its own Claude completion. The SKILL.md content is injected as context into the calling agent/session instead.

**`skills:` field in agents:** When an agent's YAML lists skill names under `skills:`, Claude Code injects those skills' SKILL.md files into the agent's context at spawn time. This is the mechanism for preloading domain knowledge into a specific agent without polluting the orchestrator context.

**Confidence:** HIGH — verified against existing skills in `~/.claude/skills/` (code-standards, git-workflow, project-scaffolder, gen-test, create-agent-skills) and agent YAML in `~/.claude/agents/` (code-reviewer, gsd-executor, gsd-planner).

### 2. Agents

**Location:** `~/.claude/agents/<agent-name>.md`

**Format:**
```yaml
---
name: agent-name
description: >
  What this agent does and trigger phrases.
  Use WHEN: [condition]. Activate when: [phrases].
model: sonnet | opus | haiku
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
  - TodoWrite
  - WebSearch
  - WebFetch
  - mcp__context7__*
maxTurns: 20
color: blue | green | yellow | orange | red | purple | cyan | magenta | white
skills:
  - skill-name
memory: user
disallowedTools: Write, Edit
---
```

**Body:** The system prompt. Markdown formatting allowed. Contains the agent's role, workflow, and behavioral instructions. No YAML frontmatter conventions in the body.

**Model selection:**
- `haiku` — lightweight detection, classification, formatting tasks
- `sonnet` — standard implementation work (most agents use this)
- `opus` — complex reasoning, planning, orchestration (used sparingly)

**Tool access:** Agents only have the tools listed in their YAML. `Task` tool is required for spawning subagents. `AskUserQuestion` is required for interactive wizard-style flows.

**`maxTurns`:** Cap on how many turns the agent can take. Range observed: 15-40. Set higher for long-running orchestrators, lower for focused specialists.

**Spawning:** Two mechanisms:
1. Claude Code routes to an agent based on trigger phrases in the `description` field (automatic activation from conversation)
2. Explicit spawn via `Task(subagent_type="agent-name", model="...", prompt="...")` from an orchestrating agent or slash command

**Confidence:** HIGH — verified against all 11 agents in `~/.claude/agents/` and GSD workflow patterns.

### 3. Slash Commands

**Location:** `~/.claude/commands/<command-name>.md` or `~/.claude/commands/gsd/<command-name>.md`

**Format (inline):**
```yaml
---
name: namespace:command-name
description: One-line description
argument-hint: "[arg] [--flag]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---
```

**Format (delegate to agent):**
```yaml
---
name: namespace:command-name
description: One-line description
agent: agent-name
allowed-tools:
  - Read
  - Write
---
```

When `agent:` is set, the slash command delegates entirely to the named agent. The command's body provides context injected alongside the agent's system prompt.

**`@`-file references in command body:** The `<execution_context>` section can reference workflow files with `@/path/to/workflow.md`, which Claude Code auto-injects at invocation. This is the mechanism for keeping slash commands lean and loading heavy workflow logic on demand.

**`$ARGUMENTS`:** Variable for the user's arguments passed after the command name. Passed to the command body as a template variable.

**Confidence:** HIGH — verified against GSD command files in `~/.claude/commands/gsd/` including discuss-phase.md, execute-phase.md, plan-phase.md, new-project.md.

---

## Composition Patterns

### Pattern 1: Slash Command → Inline Orchestrator

**When to use:** The command itself handles orchestration logic (routing, state detection, spawning subagents). Most GSD commands use this pattern.

```
/wizard
  └── commands/wizard.md    (inline orchestrator)
        ├── reads STATE.md, .planning/config.json
        ├── presents numbered menu (AskUserQuestion)
        └── Task(subagent_type="wizard-backing-agent", ...)
```

**Why:** The slash command's allowed-tools list controls what the orchestrator can do. Task tool access is explicit. This is the pattern used by `/gsd:execute-phase`, `/gsd:new-project`.

**Confidence:** HIGH — directly observed in execute-phase.md and discuss-phase.md.

### Pattern 2: Slash Command → Named Agent (Delegation)

**When to use:** The agent has complex interactive behavior that doesn't fit a command body. Use `agent:` field.

```
/gsd:plan-phase
  └── commands/gsd/plan-phase.md  (uses agent: gsd-planner)
        └── gsd-planner agent takes over
```

**Why:** Cleaner separation. The command provides argument parsing and context injection; the agent provides the full workflow. Only one agent in the existing system uses this — `gsd-planner`.

**Confidence:** HIGH — directly observed in plan-phase.md.

### Pattern 3: Orchestrator → Specialist Subagents (Task Tool)

**When to use:** Heavy work that needs a fresh 200k context window per task. The orchestrator stays lean (10-15% context usage), spawning specialists with their full context budget.

```
Orchestrator command
  └── Task(subagent_type="gsd-executor", model="sonnet",
           prompt="<objective>...</objective><files_to_read>...</files_to_read>")
        └── gsd-executor agent runs with full fresh context
```

**Why:** Context isolation prevents quality degradation as the session grows. Each specialist reads relevant files directly rather than inheriting a polluted context from the orchestrator.

**Confidence:** HIGH — the foundational GSD pattern, directly verified in execute-phase workflow and observed across 12 subagent_type usages.

### Pattern 4: Agent with Preloaded Skills

**When to use:** An agent needs consistent domain knowledge (coding standards, git conventions) without consuming context reading reference files on every run.

```yaml
---
name: code-reviewer
skills:
  - code-standards
  - git-workflow
---
```

Claude Code injects the SKILL.md content of each listed skill into the agent's context at spawn time.

**Why:** Avoids the agent having to `Read` reference files every invocation. The skill content is in context before the first tool call.

**Confidence:** HIGH — verified in code-reviewer.md (skills: code-standards), gsd-executor.md (skills: gsd-executor-workflow), gsd-planner.md (skills: gsd-planner-workflow).

---

## Wizard-Specific Stack Decisions

### Entry Point: Slash Command, Not Agent

**Decision:** The `/wizard` entry point is a slash command (`commands/wizard.md`), not an agent.

**Why:** Slash commands are invoked explicitly by the user. Agents are triggered by conversation pattern matching, which can fire unexpectedly. A wizard entry point must be deterministic. The existing pattern-triggered entry agents (project-setup-wizard, project-setup-advisor) are useful as downstream components but not appropriate as the single `/wizard` entry.

**Confidence:** HIGH — confirmed by how GSD commands are structured vs how entry agents work.

### State Detection: Bash in the Slash Command

**Decision:** Run all state detection (BMAD/GSD presence, phase status, git state) via Bash in the slash command body before any user interaction. Never narrate the detection.

**Why:** This is exactly how project-setup-wizard works (Phase 1 — Silent Detection). The pattern is proven and can be reused. State detection via Bash is faster than spawning an agent for it.

**Confidence:** HIGH — directly verified in project-setup-wizard.md.

### User Interaction: AskUserQuestion Tool

**Decision:** Use `AskUserQuestion` for all wizard menu interactions.

**Why:** This tool is designed for structured user prompts with predefined choices. It appears in every interactive GSD command: new-project, new-milestone, settings, validate-phase. It is the standard mechanism.

**Confidence:** HIGH — verified across 8+ GSD commands using AskUserQuestion.

### Heavy Orchestration: Backing Agent via Task

**Decision:** Delegate complex routing and cross-framework orchestration to a dedicated `wizard-orchestrator` agent spawned via `Task(subagent_type="wizard-orchestrator")`.

**Why:** The slash command handles UI (state display, menu), then hands off to the backing agent for the heavy work (reading BMAD docs, determining next GSD command, writing state). This keeps the slash command lean and follows the Pattern 3 composition observed throughout GSD. The slash command's context is preserved for future wizard interactions; the agent gets fresh context.

**Confidence:** HIGH — mirrors the execute-phase → gsd-executor pattern.

### State Persistence: `.planning/` Directory

**Decision:** All wizard state persists to `.planning/wizard-state.md` (or extends `.planning/STATE.md`).

**Why:** `.planning/` is the GSD-managed persistent state directory, already present in any project running GSD. Writing state here survives context resets. The GSD tools binary (`gsd-tools.cjs`) provides state read/write utilities. The existing `state patch`, `state update`, and `frontmatter` commands in gsd-tools can be used directly.

**Confidence:** HIGH — confirmed by `.planning/STATE.md` usage throughout GSD, and gsd-tools.cjs state management commands.

### Context Budget: Router Skill Pattern

**Decision:** The wizard skill uses the router pattern (SKILL.md + workflows/ + references/) to keep the invocation footprint small.

**Why:** The "skills are progressive disclosure" principle from create-agent-skills: SKILL.md under 500 lines, heavy content in workflows/ loaded only when needed. A wizard has multiple distinct paths (new project, resume, bridge, continue), each needing different references. Loading everything upfront wastes context.

**Confidence:** HIGH — directly from create-agent-skills reference documentation and observed in create-agent-skills skill itself.

### Model Selection

**Decision:** Smart router skill runs with `sonnet` (detection + routing logic). Backing agent runs with `sonnet` (orchestration work). Delegated specialists (BMAD agents, GSD agents) use their own configured models.

**Why:** `opus` is not needed for state detection or routing — that is pattern matching and file reading, not complex reasoning. Sonnet handles it correctly. `haiku` is insufficient for orchestration decisions. The existing project uses sonnet for all bridge and entry agents.

**Confidence:** HIGH — consistent with observed model assignments across all 11 existing agents.

---

## Recommended Stack Components

### Core Framework

| Component | Type | Location | Purpose |
|-----------|------|----------|---------|
| Slash command `/wizard` | Slash command | `commands/wizard.md` | Single user-facing entry point |
| Smart router skill | Skill (user-invocable) | `skills/wizard-router/` | State detection, routing logic |
| Wizard orchestrator agent | Agent | `agents/wizard/wizard-orchestrator.md` | Heavy orchestration, cross-framework work |
| Wizard state file | File | `.planning/wizard-state.md` | Persistent state across context resets |

### Supporting Infrastructure (Already Exists — Wrap, Don't Replace)

| Component | Location | Role in Wizard |
|-----------|----------|----------------|
| `gsd-tools.cjs` | `~/.claude/get-shit-done/bin/` | State read/write, phase lookup |
| `.planning/STATE.md` | Project `.planning/` | Current GSD phase state |
| `.planning/config.json` | Project `.planning/` | GSD project config |
| `agents/bridge/bmad-gsd-orchestrator.md` | Project `agents/bridge/` | BMAD → GSD handoff |
| `agents/bridge/phase-gate-validator.md` | Project `agents/bridge/` | Phase completion gating |
| `agents/entry/project-setup-wizard.md` | Global `~/.claude/agents/` | Downstream wizard component |
| `agents/entry/project-setup-advisor.md` | Global `~/.claude/agents/` | Downstream advisor component |

### Tools Required

| Tool | Used By | Purpose |
|------|---------|---------|
| `Bash` | Slash command, orchestrator | State detection, gsd-tools CLI |
| `Read` | All components | Read STATE.md, config.json, BMAD docs |
| `Write` | Orchestrator | Write wizard-state.md |
| `Task` | Slash command | Spawn orchestrator agent |
| `AskUserQuestion` | Slash command | Interactive wizard menus |
| `Glob`, `Grep` | Orchestrator | Document discovery |

---

## Alternatives Considered

| Decision | Chosen | Alternative | Why Not |
|----------|--------|-------------|---------|
| Entry point type | Slash command | Pattern-triggered agent | Agents fire on conversation patterns, not explicit invocation — too unpredictable for a wizard entry point |
| State persistence | `.planning/wizard-state.md` | In-memory (conversation context) | Context resets lose state; `.planning/` survives resets |
| Orchestration model | Backing agent via Task | Inline in slash command | Slash command context fills as the session grows; Task gives each orchestration call a fresh 200k budget |
| Skill type | Router pattern | Single SKILL.md | Multiple wizard paths (new/resume/bridge/continue) need different references; loading all paths upfront wastes context |
| Heavy work model | Sonnet | Opus | Routing and state detection don't need complex reasoning; opus cost not justified |
| Existing entry agents | Downstream components | Replace with new agents | Entry agents work correctly and are well-tested; wrapping preserves modularity |

---

## Installation / Deployment

The wizard components install to the same locations as existing agents and skills:

```bash
# Skills (global — available in all projects)
cp -r skills/wizard-router ~/.claude/skills/

# Agents (global — available in all projects)
cp agents/wizard/wizard-orchestrator.md ~/.claude/agents/

# Slash command (global)
cp commands/wizard.md ~/.claude/commands/
```

All three components are added to the existing `install-runtime-support.sh` script alongside the current 11 agents.

---

## Sources

- Directly observed: `~/.claude/agents/*.md` — all 11 agent YAML frontmatter fields and body patterns (HIGH confidence)
- Directly observed: `~/.claude/skills/create-agent-skills/SKILL.md` and references — skill structure specification (HIGH confidence)
- Directly observed: `~/.claude/skills/code-standards/SKILL.md`, `git-workflow/SKILL.md` — preloaded skill pattern with `user-invocable: false` (HIGH confidence)
- Directly observed: `~/.claude/skills/gen-test/SKILL.md` — `context: fork`, `disable-model-invocation: true` patterns (HIGH confidence)
- Directly observed: `~/.claude/commands/gsd/*.md` — slash command YAML format, `agent:` delegation, `@`-file injection, `AskUserQuestion` usage (HIGH confidence)
- Directly observed: `~/.claude/get-shit-done/workflows/execute-phase.md` — Task spawning pattern with `subagent_type`, `model`, fresh context budget (HIGH confidence)
- Directly observed: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STACK.md` — existing project architecture and stack (HIGH confidence)
- Directly observed: `.planning/PROJECT.md` — wizard requirements and constraints (HIGH confidence)
