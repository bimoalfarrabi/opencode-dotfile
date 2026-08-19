# OpenCode Configuration Schema

> **Source:** OpenCode docs (opencode.ai) — `opencode.json` and `tui.json` schema references.

## Config Priority Chain

Configs are merged in order (later overrides earlier):

| Priority | Source |
|---|---|
| 1 (lowest) | Remote `.well-known/opencode` (org defaults) |
| 2 | `~/.config/opencode/opencode.json` (global user config) |
| 3 | `$OPENCODE_CONFIG` env var (custom path) |
| 4 | `opencode.json` or `opencode.jsonc` (project root) |
| 5 | `.opencode/` directory (per-project agents, commands, plugins, skills, tools, themes) |
| 6 | `$OPENCODE_CONFIG_CONTENT` env var (inline JSON) |
| 7 | Managed config (`/etc/opencode/`, `%ProgramData%/opencode`, MDM plist) |

## Top-Level Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `$schema` | string | — | Schema URL for validation |
| `model` | string | — | Primary model ID |
| `small_model` | string | — | Lightweight model for simple tasks |
| `provider` | object | — | Per-provider config with `options` and `models` |
| `mcp` | object | `{}` | MCP server definitions |
| `permission` | object | `{"*": "ask"}` | Tool access rules |
| `agent` | object | `{}` | Custom agent definitions |
| `plugin` | string[] | `[]` | npm plugin package names |
| `command` | object | `{}` | Custom command templates |
| `skills` | object | `{}` | Extra skill paths and URLs |
| `instructions` | string[] | `[]` | Additional rules file paths |
| `server` | object | — | Web server config (port, hostname, CORS) |
| `shell` | string | OS default | Shell for bash commands |
| `formatter` | boolean/object | `true` | Formatting configuration |
| `lsp` | boolean/object | `true` | LSP server configuration |
| `references` | object | `{}` | External directory and repo references |

## Permission Rules

Each tool can be `"allow"`, `"ask"`, or `"deny"`:

```jsonc
{
  "permission": {
    "*": "ask",                          // global default
    "read": { "*": "allow" },
    "bash": { "*": "ask", "git *": "allow", "rm *": "deny" },
    "skill": { "*": "allow" },
    "external_directory": { "~/projects/**": "allow" }
  }
}
```

Per-agent overrides in `agent.<name>.permission`.

## Variable Substitution

Config values support `{env:VAR_NAME}` and `{file:/path/to/file}`:

```jsonc
{
  "provider": {
    "anthropic": { "options": { "apiKey": "{env:ANTHROPIC_API_KEY}" } }
  },
  "mcp": {
    "my-server": {
      "headers": { "Authorization": "Bearer {env:MY_TOKEN}" }
    }
  }
}
```

## TUI Config

`tui.json` (project root or `~/.config/opencode/tui.json`):

```jsonc
{
  "$schema": "https://opencode.ai/tui.json",
  "theme": "tokyonight",
  "scroll_speed": 3,
  "mouse": true,
  "keybinds": { /* 100+ keybind options */ }
}
```
