---
name: customize-opencode
description: >
  Edit or create OpenCode's own configuration. Use ONLY when configuring
  OpenCode itself. Do NOT use for the user's application code.
version: 1.0.0
license: MIT
compatibility: all
allowed-tools: Read Bash Write Edit
tier: action-allowed
metadata:
  audience: all-engineers
  workflow: configure
---

# Customize OpenCode

**Configure OpenCode itself — not your application.**

Editing OpenCode's own config (`opencode.json`, `.opencode/`, `~/.config/opencode/`) requires care — a mistake can break the agent's ability to function.

## When to Use

- Creating or editing `opencode.json` / `opencode.jsonc`
- Adding, modifying, or removing MCP servers
- Changing agent permission rules
- Installing or disabling plugins
- Editing skill paths or agent definitions

## When NOT to Use

- Your application code (use the appropriate platform skill)
- Any project that is not configuring OpenCode itself

## Output Contract

| Artifact | Format | Location | Quality Criteria |
|---|---|---|---|
| Validated config | JSON | `opencode.json` | JSON valid, permission rules safe, MCP URLs reachable |

Always create a backup before editing: `cp opencode.json opencode.json.bak`

## Core Process

### Phase 1 — Assess

Read the current config. Identify exactly what needs to change:

```
Current: model: claude-sonnet-4 → Want: model: claude-sonnet-4-20250514
Change: one field in model
Risk: low — model string only
```

If multiple changes, do them one at a time. Verify after each.

### Phase 2 — Edit

Make surgical edits. One change per operation:

| What | How | Risk |
|---|---|---|
| Model/provider | Edit `model` or `provider.<name>.options` | Low |
| MCP server | Add/remove `mcp.<name>` block | Medium — verify URL/command |
| Permission rule | Edit `permission.<tool>` | High — can lock out tools |
| Plugin | Add/remove from `plugin` array | Low — npm installs silently |
| Agent definition | Edit `agent.<name>` | Low — only affects that agent |

**Danger zones (verify twice before committing):**
- API keys in `provider.options` or `mcp.<name>.headers` — use `{env:VAR}` substitution instead of plaintext
- Permission rules with `"deny"` — ensure essential tools (read, bash, write) remain accessible
- MCP server commands/URLs — a typo means the tool silently fails
- `"*": "deny"` in permissions — locks everything. Always pair with explicit allows.

### Phase 3 — Validate

Before restarting the agent:

```
☐ JSON is valid: python3 -c "import json; json.load(open('opencode.json'))"
☐ Permission rules don't deny essential tools (read, bash, write)
☐ MCP URLs are reachable (curl -I <url>)
☐ Backup exists: opencode.json.bak
☐ No plaintext API keys (all using {env:VAR} or {file:PATH})
```

## Anti-Patterns

1. **Plaintext secrets** — API keys in config instead of `{env:VAR}`. Exposed in logs and version control.
2. **Blind deny-all** — `"*": "deny"` without explicit allows. Agent can't read files or run commands.
3. **Silent MCP removal** — Removing an MCP server that other config sections depend on.
4. **Malformed JSON** — Missing comma or trailing comma in `opencode.json`. Use `--check` flag.
5. **Wrong scope** — Editing project `opencode.json` when intending to change global `~/.config/opencode/opencode.json`.

## Verification

- [ ] Backup created before edit
- [ ] JSON valid after edit
- [ ] Permission rules allow essential tools (read, bash, write)
- [ ] No plaintext API keys in committed config
- [ ] MCP URLs/commands verified reachable
- [ ] Only one config file changed (project or global, not both)
