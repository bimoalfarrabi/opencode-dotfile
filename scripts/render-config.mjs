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
 *   {{REA_GHIDRA_DIR}}   -> Ghidra install dir for the rea MCP server
 *   {{REA_JAVA_HOME}}    -> JDK home for the rea MCP server
 *   {{WEB_SEARCH_MCP_DIR}} -> web-search MCP checkout (dist/index.js)
 *
 * {env:VAR} placeholders are passed through unchanged — OpenCode resolves them
 * from the environment at runtime, which the setup scripts populate from
 * secrets.env.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from "node:fs";
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

// rea (reverse-engineering) MCP: Ghidra + a JDK, both optional. Empty string
// keeps the JSON valid; the server starts without them and just loses the
// Ghidra-backed tools.
//
// Auto-detect rather than demanding env vars: Ghidra installs as
// <tools dir>/ghidra_<version>_PUBLIC (or ~/ghidra_<version>_PUBLIC), and JDK
// homes are often in ~/.jdks/temurin-* or under SDKMAN. Sort descending so the
// newest version wins when several are present.
function detectVersionedDir(parents, prefix) {
  const found = [];
  for (const parent of parents) {
    if (!existsSync(parent)) continue;
    for (const name of readdirSync(parent)) {
      if (!name.startsWith(prefix)) continue;
      const full = join(parent, name);
      try {
        if (statSync(full).isDirectory()) found.push(full);
      } catch {
        // unreadable entry — skip it rather than fail the render
      }
    }
  }
  return found.sort().pop() || "";
}

const REA_GHIDRA_DIR = process.env.REA_GHIDRA_DIR
  || detectVersionedDir([join(HOME, "tools"), HOME], "ghidra_");

const REA_JAVA_HOME = process.env.REA_JAVA_HOME
  || detectVersionedDir([join(HOME, ".jdks"), join(HOME, ".sdkman", "candidates", "java")], "temurin-")
  || detectVersionedDir([join(HOME, ".sdkman", "candidates", "java")], "");

// web-search MCP: a local checkout. Default to <repo>/mcp-servers/web-search-mcp
const WEB_SEARCH_MCP_DIR = process.env.WEB_SEARCH_MCP_DIR
  || join(REPO, "mcp-servers", "web-search-mcp");

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
  .replaceAll("{{HEADROOM_BIN}}", escapeJsonPath(HEADROOM_BIN))
  .replaceAll("{{REA_GHIDRA_DIR}}", escapeJsonPath(REA_GHIDRA_DIR))
  .replaceAll("{{REA_JAVA_HOME}}", escapeJsonPath(REA_JAVA_HOME))
  .replaceAll("{{WEB_SEARCH_MCP_DIR}}", escapeJsonPath(WEB_SEARCH_MCP_DIR));

// Validate final JSON is well-formed (template is JSON with {{}} tokens only)
JSON.parse(rendered);

mkdirSync(CONFIG_DIR, { recursive: true });
const out = join(CONFIG_DIR, "opencode.json");
writeFileSync(out, rendered);

console.log(`Rendered config -> ${out}`);
console.log(`  OPEN_DESIGN_DIR = ${OPEN_DESIGN_DIR}`);
console.log(`  AGENTS_SKILLS   = ${AGENTS_SKILLS}`);
console.log(`  HEADROOM_BIN    = ${HEADROOM_BIN}`);
console.log(`  REA_GHIDRA_DIR  = ${REA_GHIDRA_DIR || "(unset — rea Ghidra tools disabled)"}`);
console.log(`  REA_JAVA_HOME   = ${REA_JAVA_HOME || "(unset)"}`);
console.log(`  WEB_SEARCH_DIR  = ${WEB_SEARCH_MCP_DIR}`);
console.log(`  OPENCODE_CONFIG = ${out}`);
if (!existsSync(OPEN_DESIGN_DIR)) {
  console.warn(`WARN: OPEN_DESIGN_DIR does not exist: ${OPEN_DESIGN_DIR}`);
}
if (!existsSync(join(WEB_SEARCH_MCP_DIR, "dist", "index.js"))) {
  console.warn(`WARN: web-search MCP not built: ${join(WEB_SEARCH_MCP_DIR, "dist", "index.js")}`);
}
if (REA_GHIDRA_DIR && !existsSync(REA_GHIDRA_DIR)) {
  console.warn(`WARN: REA_GHIDRA_DIR does not exist: ${REA_GHIDRA_DIR}`);
}
