#!/usr/bin/env bash
# toolkit-discovery.sh — Scan installed toolkit (agents, skills, hooks, MCP servers)
# Writes .claude/toolkit-registry.json and emits compact summary to stdout
# Usage: bash skills/toolkit-discovery.sh [--force]
#
# Exit code is always 0 (consumed by wizard pipeline)

set -euo pipefail

REGISTRY_PATH=".claude/toolkit-registry.json"
FORCE_SCAN=false

# -- ARG PARSING --------------------------------------------------------
for arg in "$@"; do
    [ "$arg" = "--force" ] && FORCE_SCAN=true
done

# -- TTL CACHE CHECK (PERF-01) ------------------------------------------
if [ "$FORCE_SCAN" = "false" ] && [ -f "$REGISTRY_PATH" ]; then
    # Try macOS stat first, fall back to Linux stat
    FILE_MTIME=$(stat -f %m "$REGISTRY_PATH" 2>/dev/null || stat -c %Y "$REGISTRY_PATH" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    ELAPSED=$((NOW_EPOCH - FILE_MTIME))

    if [ "$ELAPSED" -lt 3600 ]; then
        # Cache is fresh — emit compact summary from cached registry and exit
        python3 -c "
import json, sys

try:
    with open('$REGISTRY_PATH') as f:
        registry = json.load(f)
except Exception as e:
    print(json.dumps({'version': 1, 'counts': {}, 'by_stage': {}, 'error': str(e)}))
    sys.exit(0)

tools = registry.get('tools', [])
counts = registry.get('counts', {})

STAGES = ['research', 'planning', 'execution', 'review']
KEYSTONE_NAMES = {
    'wizard', 'bmad-gsd-orchestrator', 'context-health-monitor',
    'phase-gate-validator', 'doc-shard-bridge', 'project-setup-wizard',
    'project-setup-advisor', 'it-infra-agent', 'godot-dev-agent',
    'open-source-agent', 'admin-docs-agent', 'stack-update-watcher'
}
GSD_NAMES = {'gsd', 'execute', 'plan', 'phase'}

def sort_key(name):
    n = name.lower()
    if n in KEYSTONE_NAMES or any(k in n for k in KEYSTONE_NAMES):
        return (0, name)
    if any(g in n for g in GSD_NAMES):
        return (1, name)
    return (2, name)

by_stage = {}
for stage in STAGES:
    names = [t['name'] for t in tools if stage in t.get('stages', [])]
    names.sort(key=sort_key)
    by_stage[stage] = names[:6]

summary = {'version': 1, 'counts': counts, 'by_stage': by_stage}
print(json.dumps(summary, separators=(',', ':')))
" 2>/dev/null
        exit 0
    fi
fi

# -- FULL SCAN ----------------------------------------------------------
mkdir -p ".claude"

python3 -c "
import json, os, re, sys
from pathlib import Path
from datetime import datetime, timezone

CLAUDE_DIR = Path.home() / '.claude'
AGENTS_DIR = CLAUDE_DIR / 'agents'
SKILLS_DIR = CLAUDE_DIR / 'skills'
SETTINGS_FILE = CLAUDE_DIR / 'settings.json'
PLUGINS_FILE = CLAUDE_DIR / 'installed_plugins.json'
REGISTRY_PATH = Path('.claude/toolkit-registry.json')

STAGES = ['research', 'planning', 'execution', 'review']

STAGE_KEYWORDS = {
    'research':  r'research|investigate|analyze|explore|scan|audit|inspect|fetch|crawl',
    'planning':  r'plan|design|architect|strategy|roadmap|scope|requirement|scaffold',
    'execution': r'execute|implement|build|write|deploy|create|generate|fix|develop',
    'review':    r'review|test|validate|verify|check|lint|quality|security',
}

KEYSTONE_NAMES = {
    'wizard', 'bmad-gsd-orchestrator', 'context-health-monitor',
    'phase-gate-validator', 'doc-shard-bridge', 'project-setup-wizard',
    'project-setup-advisor', 'it-infra-agent', 'godot-dev-agent',
    'open-source-agent', 'admin-docs-agent', 'stack-update-watcher'
}
GSD_NAMES = {'gsd', 'execute', 'plan', 'phase'}


def assign_stages(name, description):
    '''Keyword-match name+description to stages. Return all four if no match.'''
    text = (name + ' ' + (description or '')).lower()
    matched = []
    for stage, pattern in STAGE_KEYWORDS.items():
        if re.search(pattern, text):
            matched.append(stage)
    return matched if matched else STAGES[:]


def parse_agent_frontmatter(path):
    '''Parse YAML frontmatter from an agent .md file. Returns dict (possibly empty) or None on read error.'''
    try:
        content = path.read_text(encoding='utf-8', errors='replace')
    except Exception:
        return None

    # Extract between first --- and second ---
    m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if not m:
        # No frontmatter -- return empty dict so file still gets included
        return {}

    fm = m.group(1)
    result = {}

    # Parse line by line
    lines = fm.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]

        # Skip empty lines
        if not line.strip():
            i += 1
            continue

        # Check for key: value
        if ':' not in line:
            i += 1
            continue

        key, _, rest = line.partition(':')
        key = key.strip()
        rest = rest.strip()

        # Handle multi-line description (> or |)
        if key == 'description' and rest in ('>', '|', '>-', '|-'):
            desc_lines = []
            i += 1
            while i < len(lines):
                l = lines[i]
                # Continuation lines start with whitespace
                if l and (l[0] == ' ' or l[0] == '\t'):
                    desc_lines.append(l.strip())
                    i += 1
                else:
                    break
            result['description'] = ' '.join(desc_lines)
        elif key == 'description':
            result['description'] = rest
            i += 1
        elif key in ('name', 'model'):
            result[key] = rest
            i += 1
        elif key == 'maxTurns':
            try:
                result['maxTurns'] = int(rest)
            except ValueError:
                pass
            i += 1
        elif key == 'tools':
            # Could be inline: 'tools: Read, Write, Bash'
            # or a YAML list on subsequent lines
            if rest:
                # Inline list (comma-separated)
                result['tools'] = [t.strip() for t in rest.split(',') if t.strip()]
                i += 1
            else:
                # Multi-line YAML list
                tool_list = []
                i += 1
                while i < len(lines):
                    l = lines[i].strip()
                    if l.startswith('- '):
                        tool_list.append(l[2:].strip())
                        i += 1
                    elif not l:
                        i += 1
                        break
                    else:
                        break
                result['tools'] = tool_list
        else:
            i += 1

    return result


def parse_skill_frontmatter(path):
    '''Parse YAML frontmatter from SKILL.md. Returns dict or None.'''
    try:
        content = path.read_text(encoding='utf-8', errors='replace')
    except Exception:
        return None

    m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if not m:
        return None

    fm = m.group(1)
    result = {}
    lines = fm.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        if ':' not in line or not line.strip():
            i += 1
            continue
        key, _, rest = line.partition(':')
        key = key.strip()
        rest = rest.strip()
        if key == 'name':
            result['name'] = rest
            i += 1
        elif key == 'description':
            if rest in ('>', '|', '>-', '|-'):
                desc_lines = []
                i += 1
                while i < len(lines):
                    l = lines[i]
                    if l and (l[0] == ' ' or l[0] == '\t'):
                        desc_lines.append(l.strip())
                        i += 1
                    else:
                        break
                result['description'] = ' '.join(desc_lines)
            else:
                result['description'] = rest
                i += 1
        else:
            i += 1
    return result


# -----------------------------------------------------------------------
# 1. AGENT SCANNING (DISC-01)
# -----------------------------------------------------------------------
agents = []
if AGENTS_DIR.is_dir():
    for md_file in sorted(AGENTS_DIR.glob('*.md')):
        fm = parse_agent_frontmatter(md_file)
        if fm is None:
            # File could not be read at all — skip
            print(f'WARNING: Could not read agent file {md_file.name}', file=sys.stderr)
            continue

        name = fm.get('name', md_file.stem)
        desc = fm.get('description', '')
        model = fm.get('model', '')
        tools_list = fm.get('tools', [])
        max_turns = fm.get('maxTurns', None)

        # Truncate description to first sentence/line for compactness
        desc_short = desc.split('\n')[0].strip()
        if len(desc_short) > 200:
            desc_short = desc_short[:200]

        entry = {
            'name': name,
            'type': 'agent',
            'description': desc_short,
            'stages': [],  # filled below
            'source': f'~/.claude/agents/{md_file.name}',
            'model': model,
            'tools': tools_list,
        }
        if max_turns is not None:
            entry['maxTurns'] = max_turns

        entry['stages'] = assign_stages(name, desc_short)
        agents.append(entry)


# -----------------------------------------------------------------------
# 2. SKILL SCANNING (DISC-03)
# -----------------------------------------------------------------------
skills = []
if SKILLS_DIR.is_dir():
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        skill_md = skill_dir / 'SKILL.md'
        if not skill_dir.is_dir() or not skill_md.exists():
            continue

        fm = parse_skill_frontmatter(skill_md)
        if fm is None:
            print(f'WARNING: Could not parse frontmatter from {skill_md}', file=sys.stderr)
            continue

        name = fm.get('name', skill_dir.name)
        desc = fm.get('description', '')

        entry = {
            'name': name,
            'type': 'skill',
            'description': desc,
            'stages': assign_stages(name, desc),
            'source': f'~/.claude/skills/{skill_dir.name}/SKILL.md',
            'trigger': name,
        }
        skills.append(entry)


# -----------------------------------------------------------------------
# 3. HOOK SCANNING (DISC-04) — from settings.json registrations only
# -----------------------------------------------------------------------
hooks = []
if SETTINGS_FILE.exists():
    try:
        with open(SETTINGS_FILE) as f:
            settings = json.load(f)

        hooks_config = settings.get('hooks', {})
        # Track seen commands to avoid duplicates
        seen_commands = set()

        for event_type, entries in hooks_config.items():
            if not isinstance(entries, list):
                entries = [entries]
            for entry in entries:
                # Each entry has {matcher?, hooks: [{type, command, ...}]}
                inner_hooks = entry.get('hooks', [])
                for h in inner_hooks:
                    cmd = h.get('command', '')
                    if not cmd or cmd in seen_commands:
                        continue
                    seen_commands.add(cmd)

                    # Derive name from script filename
                    # e.g. 'bash ~/.claude/hooks/session-start.sh' -> 'session-start'
                    # e.g. node /path/to/gsd-context-monitor.js -> gsd-context-monitor
                    parts = cmd.split()
                    script_path = parts[-1] if parts else cmd
                    # Strip surrounding quotes (single or double)
                    script_path = script_path.strip(chr(39)).strip(chr(34))
                    hook_name = os.path.basename(script_path)
                    # Remove extension
                    hook_name = re.sub(r'\.(sh|js|py|rb)$', '', hook_name)

                    hook_entry = {
                        'name': hook_name,
                        'type': 'hook',
                        'description': f'{event_type} hook',
                        'stages': STAGES[:],  # hooks get all stages (zero-match fallback)
                        'source': '~/.claude/settings.json#hooks',
                        'event': event_type,
                    }
                    # Apply stage tagging on hook name+description
                    matched = assign_stages(hook_name, event_type + ' hook')
                    hook_entry['stages'] = matched
                    hooks.append(hook_entry)

    except Exception as e:
        print(f'WARNING: Could not read hooks from settings.json: {e}', file=sys.stderr)


# -----------------------------------------------------------------------
# 4. MCP SERVER SCANNING (DISC-02)
# -----------------------------------------------------------------------
mcp_servers = {}  # name -> source

# Source A: mcpServers from settings.json
if SETTINGS_FILE.exists():
    try:
        with open(SETTINGS_FILE) as f:
            settings = json.load(f)
        mcp_map = settings.get('mcpServers', {})
        for server_name in mcp_map.keys():
            mcp_servers[server_name] = 'mcpServers'
    except Exception as e:
        print(f'WARNING: Could not read mcpServers from settings.json: {e}', file=sys.stderr)

# Source B: installed_plugins.json
if PLUGINS_FILE.exists():
    try:
        with open(PLUGINS_FILE) as f:
            plugins_data = json.load(f)

        if isinstance(plugins_data, list):
            for item in plugins_data:
                if isinstance(item, dict):
                    # Try common name fields
                    name = item.get('name') or item.get('id') or item.get('pluginName', '')
                    if name:
                        if name not in mcp_servers:
                            mcp_servers[name] = 'installed_plugins.json'
                        # If already in mcpServers, keep 'mcpServers' as source
        elif isinstance(plugins_data, dict):
            for name in plugins_data.keys():
                if name not in mcp_servers:
                    mcp_servers[name] = 'installed_plugins.json'
    except Exception as e:
        print(f'WARNING: Could not read installed_plugins.json: {e}', file=sys.stderr)

# Build MCP entries — ALL get all four stages (per locked decision)
mcp_entries = []
for server_name, source in sorted(mcp_servers.items()):
    mcp_entries.append({
        'name': server_name,
        'type': 'mcp',
        'description': f'{server_name} MCP server',
        'stages': STAGES[:],  # ALL four stages, unconditionally
        'source': source,
    })


# -----------------------------------------------------------------------
# 5. BUILD REGISTRY (DISC-05)
# -----------------------------------------------------------------------
all_tools = agents + skills + hooks + mcp_entries

counts = {
    'agents': len(agents),
    'skills': len(skills),
    'hooks': len(hooks),
    'mcp': len(mcp_entries),
}

registry = {
    'schema_version': 1,
    'scanned_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'counts': counts,
    'tools': all_tools,
}

REGISTRY_PATH.write_text(json.dumps(registry, indent=2, ensure_ascii=False))


# -----------------------------------------------------------------------
# 6. COMPACT SUMMARY (MATCH-02)
# -----------------------------------------------------------------------
def sort_key(name):
    n = name.lower()
    if n in KEYSTONE_NAMES:
        return (0, name)
    if any(k in n for k in KEYSTONE_NAMES):
        return (1, name)
    if any(g in n for g in GSD_NAMES):
        return (2, name)
    return (3, name)

by_stage = {}
for stage in STAGES:
    names = [t['name'] for t in all_tools if stage in t.get('stages', [])]
    names.sort(key=sort_key)
    by_stage[stage] = names[:6]

summary = {
    'version': 1,
    'counts': counts,
    'by_stage': by_stage,
}

print(json.dumps(summary, separators=(',', ':')))
" 2>/dev/null

exit 0
