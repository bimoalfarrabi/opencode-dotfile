#!/usr/bin/env node
/**
 * OpenCode dotfiles — config renderer (cross-platform)
 *
 * Reads config/opencode.json.template, substitutes path tokens and env-var
 * placeholders, writes the final opencode.json into the target config dir.
 *
 * Path tokens substituted:
 *   {{OPEN_DESIGN_DIR}}  -> absolute path to the open-design repo (open-design/skills,
 *                           design-systems, apps/daemon MCP server)
 *   {{AGENTS_SKILLS}}    -> agents skills dir
 *   {{HEADROOM_BIN}}     -> headroom binary path (MCP server; disabled by default)
 *
 * {env:VAR} placeholders are passed through unchanged — OpenCode resolves them
 * from the environment at runtime, which the setup scripts populate from
 * secrets.env.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(__dirname, "..");

// ---- Resolve tokens -------------------------------------------------------
const HOME = process.env.HOME
  || process.env.USERPROFILE
  || process.env.HOMEDRIVE + process.env.HOMEPATH;

// open-design location: default to <repo>/open-design; override via env OPEN_DESIGN_DIR
const OPEN_DESIGN_DIR = process.env.OPEN_DESIGN_DIR
  || join(REPO, "open-design");

const AGENTS_SKILLS = join(HOME, ".agents", "skills");

// headroom binary: default to ~/.local/bin/headroom; override via env
const HEADROOM_BIN = process.env.HEADROOM_BIN
  || join(HOME, ".local", "bin", "headroom");

// ---- Which config dir? ----------------------------------------------------
// Windows: %USERPROFILE%\.config\opencode  (same logical location as Linux ~/.config/opencode)
const CONFIG_DIR = process.env.OPENCODE_CONFIG_DIR
  || join(HOME, ".config", "opencode");

// ---- Render ---------------------------------------------------------------
const template = readFileSync(join(REPO, "config", "opencode.json.template"), "utf8");

// Token values become JSON string contents: escape backslashes (Windows paths
// use `\`, which must be `\\` inside a JSON string) so the output stays valid
// on native Windows. Forward-slash Linux paths are unaffected.
const escapeJsonPath = (p) => p.replaceAll("\\", "\\\\");

const rendered = template
  .replaceAll("{{OPEN_DESIGN_DIR}}", escapeJsonPath(OPEN_DESIGN_DIR))
  .replaceAll("{{AGENTS_SKILLS}}", escapeJsonPath(AGENTS_SKILLS))
  .replaceAll("{{HEADROOM_BIN}}", escapeJsonPath(HEADROOM_BIN));

// Validate final JSON is well-formed (template is JSON with {{}} tokens only)
JSON.parse(rendered);

mkdirSync(CONFIG_DIR, { recursive: true });
const out = join(CONFIG_DIR, "opencode.json");
writeFileSync(out, rendered);

console.log(`Rendered config -> ${out}`);
console.log(`  OPEN_DESIGN_DIR = ${OPEN_DESIGN_DIR}`);
console.log(`  AGENTS_SKILLS   = ${AGENTS_SKILLS}`);
console.log(`  HEADROOM_BIN    = ${HEADROOM_BIN}`);
console.log(`  OPENCODE_CONFIG = ${out}`);
if (!existsSync(OPEN_DESIGN_DIR)) {
  console.warn(`WARN: OPEN_DESIGN_DIR does not exist: ${OPEN_DESIGN_DIR}`);
}
