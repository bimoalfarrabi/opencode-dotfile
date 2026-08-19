# OpenCode Plugin Patterns

> **Source:** OpenCode docs (opencode.ai) — plugin system, hooks, custom tools, and skills discovery.

## Plugin Discovery

OpenCode loads plugins from these locations (all merged):

| Location | Type | Description |
|---|---|---|
| `plugin` array in `opencode.json` | npm | Auto-installed via Bun |
| `.opencode/plugins/` | local | JS/TS files loaded automatically |
| `~/.config/opencode/plugins/` | local | Global user plugins |
| `.opencode/tools/` | custom tool | Filename becomes tool name |

## npm Plugins

List package names in `opencode.json`:

```jsonc
{
  "plugin": [
    "opencode-helicone-session",
    "@my-org/custom-plugin"
  ]
}
```

OpenCode auto-installs them. The `plugin` field only accepts npm package names (with optional `file:` prefix for local paths).

## Hook Events

Plugins can hook into 20+ lifecycle events:

| Event | Fires When | Use Case |
|---|---|---|
| `tool.execute.before` | Before any tool call | Logging, rate limiting |
| `tool.execute.after` | After tool returns | Response transformation |
| `session.created` | New session starts | Context initialization |
| `session.compacted` | Context window compacts | Token tracking |
| `file.edited` | File write/apply_patch completes | Audit logging |
| `permission.asked` | User is asked for permission | Custom approval flow |
| `shell.env` | Shell environment is set up | Adding env vars |
| `lsp.client.diagnostics` | LSP diagnostics received | Custom linting |

## Custom Tools

Create a JS/TS file in `.opencode/tools/`:

```javascript
// .opencode/tools/hello-world.js
import { tool } from "@opencode-ai/plugin";

export default tool({
  name: "hello-world",
  description: "A custom tool example",
  parameters: { name: { type: "string" } },
  execute: async ({ name }) => `Hello, ${name}!`
});
```

The filename becomes the tool name. Tools are invocable like built-in tools.

## Skills Discovery

Skills are `SKILL.md` files discovered from:
- `.opencode/skills/<name>/SKILL.md`
- `~/.config/opencode/skills/<name>/SKILL.md`
- `.claude/skills/<name>/SKILL.md`
- `.agents/skills/<name>/SKILL.md`

Additional paths via `opencode.json`:

```jsonc
{
  "skills": {
    "paths": ["/path/to/more/skills"],
    "urls": ["https://example.com/.well-known/skills/"]
  }
}
```

Skills are controlled by `permission.skill` — set to `"allow"` to load, `"deny"` to block.

## Agent Definitions

Create `.md` files with frontmatter in `.opencode/agents/`:

```markdown
---
name: code-reviewer
description: Reviews code for best practices
model: anthropic/claude-sonnet-4-5
temperature: 0.1
permission:
  edit: deny
---
```
