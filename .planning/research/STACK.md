# Stack Research

**Domain:** Claude Code extension system — dynamic toolkit discovery and subagent capability injection
**Researched:** 2026-03-13
**Confidence:** HIGH

---

## Context

This is a brownfield milestone. The runtime (Claude Code), file formats, and deployment targets are frozen from v1.0. The question is specifically: what techniques enable dynamic scanning of user-installed agents, skills, hooks, and MCP servers, followed by capability-to-stage matching and lightweight injection into GSD/BMAD subagent prompts?

**What already exists (DO NOT re-research):**
- Skills as `.md` files or directories in `~/.claude/skills/`
- Agents as `.md` files with YAML frontmatter in `~/.claude/agents/`
- Hooks registered in `~/.claude/settings.json` under `hooks:` keyed by event type
- MCP servers from two sources: plugin `.mcp.json` files and `mcpServers` field in settings files
- wizard-detect.sh as the established pattern for bash-based project scanning
- Existing hardcoded catalog in `skills/wizard.md` (the 11 Keystone agents, 3 skills, 3 hooks)

---

## The Discovery Landscape

### Scale Problem

The user's actual `~/.claude/agents/` directory contains **160 agents**. Showing all of them is counterproductive. The v1.0 catalog hardcodes only the 11 Keystone-authored agents. The v1.1 challenge is: discover what else exists without overwhelming the wizard or subagent prompts with irrelevant capability references.

**Observed counts (this installation):**
- Agents: 160 global `.md` files
- Skills: 30 skill directories + 2 flat `.md` files (wizard.md, wizard-backing-agent.md) + 1 `.sh` file
- Hooks: 21 `.sh` and `.js` files in `~/.claude/hooks/`; 24 registered events in `settings.json`
- MCP servers: 2 active (context7, chrome-devtools) from plugins; 2 additional from permissions (MCP_DOCKER, mcpjungle); project-level `.mcp.json` files add more per-project

This means naive "list everything" approaches produce noise, not signal.

---

## Discovery Mechanisms

### Mechanism 1: Agent Scanning (Bash, already proven in wizard-detect.sh)

**Source:** `~/.claude/agents/*.md`

**How it works:**

```bash
# List all agent names + descriptions in one pass
for agent_file in ~/.claude/agents/*.md; do
    agent_name=$(grep "^name:" "$agent_file" | head -1 | sed 's/^name: *//')
    desc=$(grep "^description:" "$agent_file" | head -1 | sed 's/^description: *//' | cut -c1-80)
    echo "$agent_name|$desc"
done
```

**What to extract:** `name:` (for Task/Agent invocation), `description:` (for capability matching keywords), `tools:` (to identify MCP-using agents).

**Pattern:** wizard-detect.sh already does similar frontmatter extraction (e.g., reading `project_type` from CLAUDE.md with `grep -qi`). This is the same pattern.

**Confidence:** HIGH — directly verified in existing agents YAML structure across 160 agents.

### Mechanism 2: Skill Scanning (Bash)

**Source:** `~/.claude/skills/` — skills are directories (most) or flat `.md` files (rare; wizard uses flat `.md` files).

```bash
# Scan skill directories
for skill_dir in ~/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    skill_md="$skill_dir/SKILL.md"
    if [ -f "$skill_md" ]; then
        invocable=$(grep "^user-invocable:" "$skill_md" | head -1 | sed 's/^user-invocable: *//')
        desc=$(grep "^description:" "$skill_md" | head -1 | sed 's/^description: *//' | cut -c1-80)
        echo "$skill_name|$invocable|$desc"
    fi
done

# Scan flat .md skill files (like wizard.md, wizard-backing-agent.md)
for skill_file in ~/.claude/skills/*.md; do
    skill_name=$(basename "$skill_file" .md)
    desc=$(grep "^description:" "$skill_file" | head -1 | sed 's/^description: *//' | cut -c1-80)
    echo "$skill_name|user-invocable|$desc"
done
```

**What to extract:** `name:`, `user-invocable:` (true = slash command, false/missing = ambient context), `description:`.

**Confidence:** HIGH — skill directory structure directly observed across 30+ installed skills.

### Mechanism 3: Hook Discovery (settings.json parsing)

**Source:** `~/.claude/settings.json` → `hooks:` object + `~/.claude/hooks/*.sh`

Two approaches:

**Option A: Parse settings.json (authoritative — only registered hooks):**
```bash
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    d = json.load(f)
hooks = d.get('hooks', {})
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            cmd = h.get('command', '')
            print(f'{event}|{cmd}')
" 2>/dev/null
```

**Option B: List hook scripts (broader — includes unregistered):**
```bash
ls ~/.claude/hooks/*.sh 2>/dev/null | xargs -I{} basename {}
```

**Use Option A** because it shows what Claude Code actually activates (registered hooks only). Unregistered scripts in `~/.claude/hooks/` are not active hooks.

**Observed hook events:** SessionStart, Stop, PreToolUse, PostToolUse, PostToolUseFailure, PreCompact, SubagentStop, SubagentStart, SessionEnd, ConfigChange, WorktreeCreate, WorktreeRemove, UserPromptSubmit, Notification.

**Confidence:** HIGH — settings.json hook structure directly verified.

### Mechanism 4: MCP Server Discovery (settings.json + plugins)

MCP servers come from three sources, in priority order:

**Source A: Plugin `.mcp.json` files (most common)**

```bash
python3 -c "
import json, os
plugins_file = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
settings_file = os.path.expanduser('~/.claude/settings.json')

with open(settings_file) as f:
    settings = json.load(f)
enabled_plugins = settings.get('enabledPlugins', {})

with open(plugins_file) as f:
    installed = json.load(f)

for plugin_id, versions in installed.get('plugins', {}).items():
    if not enabled_plugins.get(plugin_id, False):
        continue  # Skip disabled plugins
    if not versions:
        continue
    mcp_file = os.path.join(versions[0].get('installPath', ''), '.mcp.json')
    if os.path.exists(mcp_file):
        with open(mcp_file) as f:
            mcp = json.load(f)
        for server_name in mcp.keys():
            print(f'mcp__{server_name}__*|{plugin_id}')
" 2>/dev/null
```

**Active servers on this installation:** `mcp__context7__*` (Context7 docs), `mcp__chrome-devtools__*` (Chrome DevTools).

**Source B: `mcpServers` in settings.json (explicit configuration)**

```bash
python3 -c "
import json, os
with open(os.path.expanduser('~/.claude/settings.json')) as f:
    d = json.load(f)
for name, config in d.get('mcpServers', {}).items():
    print(f'mcp__{name}__*|settings.json')
" 2>/dev/null
```

**Source C: Project `.mcp.json` file (project-level)**

```bash
if [ -f ".mcp.json" ]; then
    python3 -c "
import json
with open('.mcp.json') as f:
    d = json.load(f)
for name in d.get('mcpServers', {}).keys():
    print(f'mcp__{name}__*|.mcp.json')
" 2>/dev/null
fi
```

**Naming convention (verified):** The `name` key inside `.mcp.json` maps directly to the `mcp__<name>__*` tool prefix. `"context7" -> mcp__context7__*`. This is how agents reference MCP tools in their `tools:` field.

**Confidence:** HIGH — directly verified by reading plugin `.mcp.json` files and cross-referencing with agent tool declarations.

---

## Capability-to-Stage Matching

### The Problem

160 agents exist. Only ~8-12 are relevant at any workflow stage. The matching must work without requiring manual tagging of existing agents. Every existing agent was written before this capability-matching feature existed — there are no tags to parse.

### Recommended Approach: Keyword Matching on Description Field

The `description:` field in agent frontmatter is written for Claude Code's auto-routing, which means it contains trigger phrases and workflow context. Use it for capability matching.

**Stage-to-keyword mapping:**

```bash
# This is a lookup table embedded in wizard-detect.sh or a new capability-scan.sh

# Research stage keywords
RESEARCH_KEYWORDS="research|investigate|analyze|explore|discover|study|documentation|docs|library"

# Planning stage keywords
PLANNING_KEYWORDS="plan|roadmap|architecture|design|structure|requirements|specification"

# Execution stage keywords
EXECUTION_KEYWORDS="execute|implement|build|code|develop|deploy|write|create|generate"

# Review/validation stage keywords
REVIEW_KEYWORDS="review|validate|verify|check|audit|test|qa|quality|drift|health"
```

For each discovered agent, grep its description against stage keywords to assign it to one or more stages.

**Why this works:** Agent descriptions like "Detects architectural drift... Trigger phrases: check drift, health check, validate output" contain enough signal for keyword matching without needing new metadata.

**Confidence:** MEDIUM — keyword approach is pragmatic and extensible, but description field content quality varies across 160 agents.

### Filtering for Relevance

Do NOT show all matched agents at once. Apply relevance filters:

1. **Stage filter:** Match only agents relevant to the current wizard scenario and GSD phase position
2. **Source filter:** Prefer Keystone-authored agents (known categories: entry, bridge, domain, maintenance) + GSD framework agents (gsd-*) over the 100+ uncategorized agents
3. **Active filter:** For domain agents, check `project_type` from wizard-state.json — only surface the matching domain agent

**Rule:** Surface at most 5-8 capability references per injection. More is noise.

---

## Subagent Prompt Injection

### Where to Inject

Three injection points in the existing system:

**Injection Point A: gsd-phase-researcher spawn (plan-phase workflow)**

The researcher prompt already has an `<additional_context>` block:
```
**Project skills:** Check .claude/skills/ or .agents/skills/ directory (if either exists) —
read SKILL.md files, research should account for project skill patterns
```

This can be extended to include discovered MCP tools:
```
**Available MCP tools:** {comma-separated list of active mcp__server__* prefixes}
Use mcp__context7__* for current library documentation before asserting version-specific claims.
```

**Injection Point B: wizard.md status display (Discover tools option)**

The existing "Discover tools" option (Option 4 in all menus) shows the hardcoded catalog. Extend to include dynamically discovered non-Keystone agents when relevant (e.g., code-reviewer, gsd-executor).

**Injection Point C: Task() prompt for wizard-backing-agent**

When spawning the backing agent via `Task(subagent_type="wizard-backing-agent", prompt="...")`, the prompt can include a `<available_tools>` section listing MCP tools discovered for the current project.

### Injection Format (Token-Efficient)

Do NOT inject full agent prompts. Inject pointers — name, one-liner, activation phrase.

**Format for wizard menu display:**
```
- **context7** (MCP) — Current library docs — use via mcp__context7__resolve-library-id
- **chrome-devtools** (MCP) — Browser debugging — use via mcp__chrome-devtools__*
- **code-reviewer** (agent) — Code review against project standards — say "review this code"
```

**Format for subagent prompt injection:**
```xml
<available_tools>
MCP servers: mcp__context7__* (library docs), mcp__chrome-devtools__* (browser debug)
Relevant agents: code-reviewer (quality), gsd-debugger (debugging)
</available_tools>
```

**Token budget:** A filtered 5-8 capability pointer block costs ~160-320 tokens — acceptable inside a 200k context subagent. Full agent body injection (avg 9,400 chars = ~2,350 tokens per agent) is NOT acceptable.

**Confidence:** HIGH — token costs calculated from actual agent file sizes and confirmed against 10% context budget constraint.

---

## Integration with wizard-detect.sh

### What to Add to wizard-detect.sh

wizard-detect.sh is the proven mechanism for writing structured data to wizard-state.json. Extend it with a capabilities section.

**Add to wizard-state.json schema:**

```json
{
  "capabilities": {
    "mcp_servers": ["mcp__context7__*", "mcp__chrome-devtools__*"],
    "gsd_agents": ["gsd-executor", "gsd-planner", "gsd-phase-researcher", "gsd-debugger"],
    "domain_agents_available": ["it-infra-agent", "godot-dev-agent"],
    "active_domain_agent": "it-infra-agent",
    "hooks_registered": ["SessionStart", "PostToolUse", "Stop"]
  }
}
```

**Why wizard-detect.sh, not a new file:** wizard-detect.sh already runs as the first step of every `/wizard` invocation. Adding capability scanning here costs one more bash block — it does not add a new file, a new invocation, or a new read step. The wizard.md already reads wizard-state.json in Step 2; capabilities would be in the same read.

**What NOT to add to wizard-detect.sh:**
- Full agent content parsing (too slow for 160 agents at startup)
- MCP server availability testing (can't test MCP connectivity from bash)
- Skill body parsing (the skill description in SKILL.md frontmatter is enough)

**Confidence:** HIGH — wizard-detect.sh pattern is well-understood; adding a `capabilities` block to the JSON output follows the existing schema extension pattern.

---

## User Confirmation Flow

### When Confirmation is Needed

The PROJECT.md requirement "ask before using discovered tools when intent is ambiguous" applies in one scenario: when the wizard considers surfacing a non-Keystone, non-GSD agent (e.g., a user-installed code-reviewer or blockchain-security-auditor) that matches a capability keyword.

**Rule:** Never ask for confirmation for:
- Keystone-authored agents (always safe to surface)
- GSD framework agents (gsd-executor, gsd-planner, etc.)
- MCP servers already in the agent's `tools:` field

**Ask for confirmation for:**
- User-installed agents with keyword matches but no explicit Keystone/GSD affiliation
- Any agent not in the wizard's known catalog

**Implementation:** Add a confirmation step inside the "Discover tools" flow in wizard.md, not in wizard-detect.sh. wizard-detect.sh runs silently; interactive confirmation belongs in the wizard UI layer.

**Confidence:** HIGH — consistent with the existing wizard architecture (wizard-detect.sh = silent, wizard.md = interactive).

---

## Recommended Stack Components for v1.1

### Core Components

| Component | Type | Location | Purpose |
|-----------|------|----------|---------|
| Extended wizard-detect.sh | Bash script | `skills/wizard-detect.sh` | Add `capabilities` block to JSON output |
| Updated wizard-state.json schema | JSON schema | `.claude/wizard-state.json` | New `capabilities` object |
| Updated wizard.md | Skill | `skills/wizard.md` | Read capabilities, inject into menus |
| Updated wizard-backing-agent.md | Skill | `skills/wizard-backing-agent.md` | Include `<available_tools>` in Task() prompts |

### No New Files Needed

The discovery pipeline fits entirely in:
1. **wizard-detect.sh** — scanning + JSON write
2. **wizard.md** — reading + menu display
3. **wizard-backing-agent.md** — subagent prompt injection

Do not create a separate `capability-scan.sh` or `discovery-agent.md`. The pattern in v1.0 (detect → write JSON → read → act) already handles this.

### Supporting Tools (Already Installed)

| Tool | Used By | Purpose |
|------|---------|---------|
| `Bash` | wizard-detect.sh | File system scanning |
| `python3` | wizard-detect.sh | JSON parsing for settings.json, installed_plugins.json |
| `grep -qi` | wizard-detect.sh | Keyword matching on description fields |
| `find` | wizard-detect.sh | Agent/skill file enumeration |

python3 is already used in wizard-detect.sh for JSON parsing (IS_RESET detection) and infra safety injection. This is not a new dependency.

---

## Alternatives Considered

| Decision | Chosen | Alternative | Why Not |
|----------|--------|-------------|---------|
| Discovery timing | At wizard startup (wizard-detect.sh) | On-demand when "Discover tools" selected | On-demand requires a separate bash call inside the interactive wizard, which breaks the "wizard.md does not run bash" constraint in Context Budget Discipline |
| Agent filtering | Keyword matching on description | Explicit capability tags in agent frontmatter | 160 existing agents have no tags; adding tags requires modifying all existing agents — not feasible. Keyword matching works on unmodified agent files. |
| MCP discovery | Parse settings.json + installed_plugins.json | Read from live MCP tool list | No bash-accessible live MCP tool inventory exists; settings.json is the authoritative source |
| Injection depth | Capability pointers (name + one-liner) | Inject full agent SKILL.md into subagent prompt | Full injection: ~2,350 tokens per agent, 10k tokens for 4 agents — violates 10% context budget. Pointers: ~40 tokens each — negligible. |
| Confirmation trigger | User-installed non-Keystone agents only | All discovered agents | Excessive confirmation for known Keystone/GSD agents creates friction without safety benefit |
| Capabilities in wizard-state.json | Single JSON object | Separate capabilities.json file | wizard.md already reads wizard-state.json in Step 2; adding capabilities here costs zero extra file reads |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Full agent body loading for matching | 9,400 chars avg × 160 agents = context overflow | Parse only frontmatter (first ~20 lines) |
| MCP connectivity testing | Can't test MCP servers from bash in detect script | Trust settings.json as authoritative |
| Dynamic capability tags in agent frontmatter | Requires modifying 160 existing agents | Keyword match on existing description field |
| A new `capability-discovery` agent | Adds agent spawn overhead to detection path | Extend wizard-detect.sh (already runs at startup) |
| Showing all 160 agents to user | Creates noise, not signal | Filter to ≤8 relevant capabilities per stage |
| Injecting agent body content into subagent prompts | Destroys context budget | Inject name + one-liner pointer only |
| Trying to discover project-level `.claude/agents/` | Projects may have local agents — pattern is unverified and out-of-scope for v1.1 | Scan global `~/.claude/agents/` only |

---

## Version Compatibility

| Component | Requirement | Notes |
|-----------|-------------|-------|
| `~/.claude/settings.json` | Must exist (Claude Code ≥ 1.0) | Always present for any Claude Code installation |
| `~/.claude/plugins/installed_plugins.json` | Present if any plugins installed | Fallback gracefully when absent |
| `python3` | Already used in wizard-detect.sh | No new dependency |
| Agent YAML frontmatter | `name:` + `description:` fields | All 160 observed agents have both; safe to parse |
| Skill SKILL.md frontmatter | `name:` + `description:` + `user-invocable:` | Present in all observed skill directories |

---

## Sources

- Directly observed: `~/.claude/agents/` — 160 agents with YAML frontmatter, description fields, and tool lists (HIGH confidence)
- Directly observed: `~/.claude/skills/` — 30 skill directories + 2 flat `.md` files + 1 `.sh` file; SKILL.md structure (HIGH confidence)
- Directly observed: `~/.claude/settings.json` — hooks schema (14 event types, 24 registered hooks), enabledPlugins dict, permissions (HIGH confidence)
- Directly observed: `~/.claude/plugins/installed_plugins.json` — plugin registry; 27 plugins installed, 6 with `.mcp.json` MCP servers (HIGH confidence)
- Directly observed: `~/.claude/plugins/cache/claude-plugins-official/context7/*/mcp.json` — `.mcp.json` server naming convention: `{"context7": {...}}` → `mcp__context7__*` (HIGH confidence)
- Directly observed: `skills/wizard-detect.sh` — established pattern for bash scanning, JSON write, python3 usage (HIGH confidence)
- Directly observed: `~/.claude/get-shit-done/workflows/plan-phase.md` — `<additional_context>` injection point in gsd-phase-researcher spawn prompt (HIGH confidence)
- Directly observed: `~/.claude/get-shit-done/workflows/execute-phase.md` — Task() prompt structure for gsd-executor; `<objective>` + `<execution_context>` pattern (HIGH confidence)
- Directly observed: `.planning/PROJECT.md` — v1.1 requirements for dynamic discovery (HIGH confidence)
- Token cost calculation: avg agent file size 9,417 chars × 6 observed samples; pointer estimate 80 chars each (MEDIUM confidence — sample size limited)

---
*Stack research for: Dynamic toolkit discovery and subagent capability injection*
*Researched: 2026-03-13*
