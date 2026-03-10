# Changelog

All notable changes to Keystone are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-03-14

### Added

- **Dynamic toolkit discovery** -- `toolkit-discovery.sh` scans installed agents (176), skills (28), hooks (24), and MCP servers with 1-hour TTL caching (~23ms cached lookups)
- Compact toolkit summary (~600B) wired into `wizard-state.json`, displayed on every `/wizard` invocation
- Trust classification and batched confirmation UX for capability injection at Agent/Task spawn sites
- Stage-filtered capability injection into GSD workflow files (plan-phase, execute-phase, research-phase)
- Dynamic registry-backed display replacing hardcoded catalog, with hardcoded fallback for fresh installs
- All 4 v1.1 skill files deployed globally with cross-project verification

### Known Issues

- GSD workflow files are global-only (`~/.claude/get-shit-done/workflows/`) -- re-cloning requires re-applying injection changes

## [1.0.0] - 2026-03-13

### Added

- **11 custom agents** across 4 categories: entry (2), bridge (4), domain (4), maintenance (1)
- **3 hooks**: session-start banner, stack-update-banner, post-write-check
- **3 scripts**: install-runtime-support, restore, weekly-stack-check
- **4 skills**: wizard router, wizard backing agent, wizard-detect, toolkit-discovery
- Smart router skill with 5-scenario detection from `wizard-state.json`
- Interactive wizard with 4-scenario menus, 2-turn max to recommendation
- Backing agent with bridge-to-GSD route including traceability assertions
- Validate-phase, drift-check, and on-demand traceability display routes
- Context-reset continuity, IT safety injection, and health-monitor prompts
- Multi-runtime support: Claude Code (primary), Pi and OpenCode (secondary)
- One-command installer (`install-runtime-support.sh`) for all runtimes
- Three-tier update system: cached banner, weekly cron, on-demand watcher
