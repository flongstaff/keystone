# Keystone — Wizard Orchestrator

## What This Is

A unified wizard system for Keystone that makes BMAD planning and GSD execution feel like one continuous workflow. Users interact with a single guided wizard that detects project state, discovers the full installed toolkit, injects relevant capabilities into subagent spawns, and drives from idea to working code with minimal typing.

## Core Value

At any point in a project, one command (`/wizard`) tells the user exactly where they are and does the next right thing — whether that's starting BMAD planning, bridging to GSD, or continuing execution — with awareness of the user's full toolkit.

## Requirements

### Validated

- ✓ Smart router skill that detects project state and routes to the right action — v1.0
- ✓ Guided wizard skill with step-by-step choices and smart defaults — v1.0
- ✓ Backing agent for heavy orchestration work behind the scenes — v1.0
- ✓ Requirement traceability from BMAD docs through GSD phases — v1.0
- ✓ Context-efficient orchestration (< 10% context budget) — v1.0
- ✓ Flexible entry — start fresh, resume mid-BMAD, bridge to GSD, or continue GSD phases — v1.0
- ✓ Full lifecycle support — idea → BMAD planning → bridge → GSD execution → completion — v1.0
- ✓ State persistence across context resets — v1.0
- ✓ Dynamic discovery of all user-installed agents, skills, hooks, and MCP servers — v1.1
- ✓ Capability-to-stage matching (research/planning/execution/review) — v1.1
- ✓ Subagent context injection with stage-filtered capability pointers — v1.1
- ✓ Trust classification with batched confirmation for unknown tools — v1.1
- ✓ Token-efficient injection (~200 tokens per spawn) — v1.1
- ✓ Dynamic catalog display with hardcoded fallback — v1.1
- ✓ TTL-gated caching for toolkit discovery — v1.1

### Active

(None — next milestone not yet defined)

### Out of Scope

- Replacing existing BMAD or GSD agents — wizard wraps them, doesn't replace
- Changing BMAD or GSD internals — work with their existing APIs and outputs
- Domain-specific logic (infra, game dev, etc.) — domain agents handle that separately
- Multi-project orchestration — one project at a time
- Semantic capability matching via LLM — keyword matching is sufficient
- BMAD internal agent modification — v1.1 injects at spawn time, never modifies internals

## Context

Shipped v1.1 with 1,864 LOC across skills/*.sh and skills/*.md.
Tech stack: Bash (detection + discovery scripts), Markdown (skill/agent definitions), Python3 (JSON processing in shell).
Three-component architecture: smart router (wizard-detect.sh) → wizard UI (wizard.md) → backing agent (wizard-backing-agent.md).
Discovery layer: toolkit-discovery.sh scans 176 agents, 28 skills, 24 hooks, and MCP servers with 1h TTL cache.
All skill files deployed globally to ~/.claude/skills/ for cross-project access.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrap existing agents, don't replace | Preserves modularity, avoids rewriting working code | ✓ Good |
| Three-component architecture (router + wizard + agent) | Router handles detection, wizard handles UI, agent handles work — clean separation | ✓ Good |
| Single `/wizard` entry point | Reduces cognitive load — one command to remember | ✓ Good |
| State persisted to `.planning/` | Survives context resets, consistent with GSD conventions | ✓ Good |
| Two-level discovery (full registry + compact summary) | Keeps startup token cost flat while enabling detailed catalog display | ✓ Good |
| TTL-gated caching (1h) | Cached discovery completes in ~23ms; prevents rescan on every invocation | ✓ Good |
| wizard-state.json as sole injection data source | PERF-03 compliance — full registry only loaded for catalog display | ✓ Good |
| `<capabilities>` XML tag for injection | Matches existing GSD prompt conventions; consistent format across agents | ✓ Good |
| Hardcoded KNOWN_SAFE allowlist | Keystone/GSD agents auto-inject; unknown tools get batched confirmation | ✓ Good |
| Hardcoded Phase 7 catalog as fallback | Fresh installs show useful catalog even without toolkit-discovery.sh | ✓ Good |
| Stage cap at 6 per stage (not 8) | Satisfies <800B summary constraint with real-world 176-agent toolkit | ✓ Good |
| GSD workflow files are global-only | Phase 14-02 modifies ~/.claude/get-shit-done/workflows/ directly — re-clone needs reapply | ⚠️ Revisit |

## Constraints

- **Architecture**: Must wrap existing agents, not replace them — preserves modularity
- **Context budget**: Wizard overhead must be < 10% of context window — the whole point is less overhead
- **Compatibility**: Must work with current BMAD (`bmad-method`) and GSD (`get-shit-done-cc`) npm packages
- **Runtime**: Claude Code primary target (skills + agents system)
- **File conventions**: Skills as `.md` in skills directory, agents as `.md` with YAML frontmatter in `agents/`
- **Discovery**: toolkit-registry.json is machine-specific (gitignored) — never committed

---
*Last updated: 2026-03-14 after v1.1 milestone*
