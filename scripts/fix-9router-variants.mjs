#!/usr/bin/env node
/**
 * fix-9router-variants.mjs — keep 9router's reasoning-effort ladder complete
 *
 * WHY THIS EXISTS
 * ---------------
 * OpenCode v2 derives reasoning levels from a per-provider resolver. Providers on
 * a generic `openai-compatible` package (a local 9router gateway, say) fall back
 * to a generic resolver whose default ladder stops at "high", while the upstream
 * endpoint accepts "max"/"xhigh". Levels beyond that ladder only exist in
 * provider-specific resolvers, which a custom gateway never reaches — so OpenCode
 * silently caps the model.
 *
 * The fix is to declare the ladder explicitly on each model under
 * `capabilities.reasoning.effort`. That field lives in OpenCode v2's `providers`
 * block (Config.ModelEncoded); the older `provider` block is deprecated in v2 and
 * does not accept it.
 *
 * USAGE
 * -----
 *   node fix-9router-variants.mjs                 # patch (with timestamped backup)
 *   node fix-9router-variants.mjs --dry-run       # show what would change
 *   node fix-9router-variants.mjs --provider 9router --levels low,medium,high,max
 *   node fix-9router-variants.mjs --config /path/to/opencode.json
 *
 * Idempotent: safe to re-run. Only models the upstream reports as reasoning-capable
 * are touched; a model already declaring the full ladder is left alone.
 */
import { readFileSync, writeFileSync, copyFileSync, existsSync } from "node:fs";
import { join } from "node:path";

// ---- args -----------------------------------------------------------------
const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (f, d) => {
  const i = argv.indexOf(f);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : d;
};

const DRY_RUN = has("--dry-run");
const PROVIDER = val("--provider", "9router");
const LEVELS = val("--levels", "low,medium,high,max")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const HOME = process.env.HOME || process.env.USERPROFILE;
const CONFIG = val(
  "--config",
  process.env.OPENCODE_CONFIG ||
    join(process.env.OPENCODE_CONFIG_DIR || join(HOME, ".config", "opencode"), "opencode.json"),
);

// ---- load -----------------------------------------------------------------
if (!existsSync(CONFIG)) {
  console.error(`ERROR: config not found: ${CONFIG}`);
  process.exit(1);
}
const cfg = JSON.parse(readFileSync(CONFIG, "utf8"));

// v2 only. The v1 `provider` block is deprecated and has no capabilities.reasoning.
const provider = cfg?.providers?.[PROVIDER];
if (!provider) {
  const hint = cfg?.provider?.[PROVIDER]
    ? `\n       "${PROVIDER}" is still under the deprecated "provider" block — move it to "providers" first (OpenCode v2 shape).`
    : "";
  console.error(`ERROR: providers.${PROVIDER} not present in ${CONFIG}${hint}`);
  process.exit(1);
}

const { baseURL, apiKey } = provider.settings ?? {};
if (!baseURL) {
  console.error(`ERROR: providers.${PROVIDER}.settings.baseURL is missing`);
  process.exit(1);
}

const models = provider.models ?? {};
const modelIds = Object.keys(models);
if (modelIds.length === 0) {
  console.error(`ERROR: providers.${PROVIDER}.models is empty`);
  process.exit(1);
}

// ---- fetch capabilities ---------------------------------------------------
// Resolve {env:VAR} / {file:PATH} placeholders OpenCode supports in config.
function resolveSecret(v) {
  if (typeof v !== "string") return v;
  const env = v.match(/^\{env:([^}]+)\}$/);
  if (env) return process.env[env[1]] ?? "";
  const file = v.match(/^\{file:(.+)\}$/);
  if (file) return readFileSync(file[1], "utf8").trim();
  return v;
}

const url = baseURL.replace(/\/+$/, "") + "/models";
let caps = {};
try {
  const res = await fetch(url, {
    headers: apiKey ? { Authorization: `Bearer ${resolveSecret(apiKey)}` } : {},
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const body = await res.json();
  for (const m of body.data ?? []) caps[m.id] = m.capabilities ?? {};
} catch (e) {
  console.warn(`WARN: could not read capabilities from ${url} (${e.message}).`);
  console.warn(`      Falling back to: patch every reasoning-capable model in the provider block.`);
  caps = null; // null => unknown, patch every model that already claims reasoning
}

// ---- patch ----------------------------------------------------------------
let changed = 0;
const report = [];

for (const id of modelIds) {
  const model = models[id];
  const reasoning = model.capabilities?.reasoning;

  // Upstream is authoritative when reachable: only reasoning-capable models get a ladder.
  // When it is not, fall back to what the config already claims.
  const upstream = caps?.[id];
  const reasoningCapable = upstream
    ? upstream.reasoning === true
    : reasoning?.supported === true;

  if (!reasoningCapable) continue;

  // A non-reasoning declaration (supported:false) must not gain an effort ladder.
  if (reasoning && reasoning.supported === false) continue;

  const current = Array.isArray(reasoning?.effort) ? reasoning.effort : [];
  const missing = LEVELS.filter((l) => !current.includes(l));
  if (missing.length === 0) continue;

  // Supply the COMPLETE ladder, not just the missing levels: OpenCode uses the
  // declared list as-is, so a partial list silently drops the levels it omits.
  const next = [...new Set([...current, ...LEVELS])];
  model.capabilities ??= {};
  model.capabilities.reasoning = { ...(reasoning ?? { supported: true }), effort: next };
  changed++;
  report.push(`  ${id}  +[${missing.join(",")}]  → ${next.join(",")}`);
}

// ---- write ----------------------------------------------------------------
if (changed === 0) {
  console.log(`No changes: every reasoning-capable model in providers.${PROVIDER} already declares ${LEVELS.join(",")}.`);
  process.exit(0);
}

console.log(`${DRY_RUN ? "DRY RUN — would update" : "Updating"} ${changed} model(s) in providers.${PROVIDER}:`);
console.log(report.join("\n"));

if (DRY_RUN) {
  console.log(`\nWould write: ${CONFIG}`);
  process.exit(0);
}

const backup = `${CONFIG}.bak.9router-variants.${Date.now()}`;
copyFileSync(CONFIG, backup);
writeFileSync(CONFIG, JSON.stringify(cfg, null, 4) + "\n");
console.log(`\nBackup: ${backup}`);
console.log(`Wrote : ${CONFIG}`);
