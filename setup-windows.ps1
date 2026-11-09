# ===========================================================================
# OpenCode dotfiles — Windows setup
#
# Mirrors setup-linux.sh for native Windows. Installs prerequisites, links
# skills + config into the OpenCode discovery dirs, renders opencode.json from
# the template, and builds the open-design daemon.
#
# Run from PowerShell:
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\setup-windows.ps1
#   .\setup-windows.ps1 -Secrets        # create/edit secrets.env
#   .\setup-windows.ps1 -Prereqs        # only prerequisites
#
# NOTE: On Windows the config dir is %USERPROFILE%\.config\opencode — the SAME
# logical location as Linux (~/.config/opencode). Skills discovery dirs:
#   %USERPROFILE%\.config\opencode\skills
#   %USERPROFILE%\.agents\skills
#   %USERPROFILE%\.claude\skills
# ===========================================================================
[CmdletBinding()]
param(
  [switch]$Secrets,
  [switch]$Prereqs,
  [switch]$Help
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$HomeDir = $env:USERPROFILE

$ConfigDir = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $HomeDir ".config\opencode" }
$AgentsDir = Join-Path $HomeDir ".agents\skills"
$ClaudeDir = Join-Path $HomeDir ".claude\skills"

function Write-Step($msg) { Write-Host "[setup] $msg" -ForegroundColor Green }

if ($Help) {
  Get-Content $MyInvocation.MyCommand.Path | Select-Object -First 30 | Where-Object { $_ -match '^#\s' } | ForEach-Object { $_ -replace '^#\s?','' }
  exit 0
}

# --- prerequisites ----------------------------------------------------------
function Test-Cmd([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { return $true }
  Write-Warning "missing: $name"
  return $false
}

function Invoke-Prereqs {
  Write-Step "Checking prerequisites..."
  $ok = $true
  if (-not (Test-Cmd opencode)) { Write-Warning "  install opencode: irm https://opencode.ai/install.ps1 | iex"; $ok = $false }
  if (-not (Test-Cmd bun))      { Write-Warning "  install bun:       irm bun.sh/install.ps1 | iex"; $ok = $false }
  if (-not (Test-Cmd node))     { Write-Warning "  install node:      https://nodejs.org"; $ok = $false }
  if (-not (Test-Cmd pnpm))     { Write-Warning "  install pnpm:      npm i -g pnpm"; $ok = $false }
  if (-not (Test-Cmd git))      { Write-Warning "  install git:       https://git-scm.com/download/win"; $ok = $false }
  if (-not (Test-Cmd codegraph)){ Write-Warning "  install codegraph (MCP server): see https://codegraph.dev"; $ok = $false }
  if ($ok) { Write-Step "All prerequisites present." } else { Write-Warning "Install missing items above, then re-run." }
}

# --- link assets into discovery dirs ----------------------------------------
function Invoke-LinkAssets {
  Write-Step "Linking skills into discovery dirs..."
  New-Item -ItemType Directory -Force -Path $ConfigDir, $AgentsDir, $ClaudeDir | Out-Null

  foreach ($pair in @(
    @{ Src = Join-Path $Repo "config\skills"; Dst = Join-Path $ConfigDir "skills" },
    @{ Src = Join-Path $Repo "agents-skills"; Dst = $AgentsDir },
    @{ Src = Join-Path $Repo "claude-skills"; Dst = $ClaudeDir }
  )) {
    New-Item -ItemType Directory -Force -Path $pair.Dst | Out-Null
    foreach ($srcDir in Get-ChildItem -Path $pair.Src -Directory) {
      $target = Join-Path $pair.Dst $srcDir.Name
      if (Test-Path $target) { Write-Warning "exists, skipping: $target"; continue }
      # Use a directory junction (works without admin for local paths)
      New-Item -ItemType Junction -Path $target -Target $srcDir.FullName | Out-Null
    }
  }

  Write-Step "Copying config files..."
  foreach ($f in @("AGENTS.md","oh-my-opencode-slim.json","tui.json","package.json")) {
    $target = Join-Path $ConfigDir $f
    if (-not (Test-Path $target)) { Copy-Item (Join-Path $Repo "config\$f") $target; Write-Step "  copied $f" }
  }
}

# --- render opencode.json ----------------------------------------------------
function Invoke-Render {
  Write-Step "Rendering opencode.json..."
  $env:OPENCODE_CONFIG_DIR = $ConfigDir
  node (Join-Path $Repo "scripts\render-config.mjs")
  Write-Step "Rendered: $(Join-Path $ConfigDir 'opencode.json')"
}

# --- secrets -----------------------------------------------------------------
function Invoke-Secrets {
  $secretsPath = Join-Path $Repo "secrets.env"
  if (-not (Test-Path $secretsPath)) {
    Copy-Item (Join-Path $Repo "secrets.env.example") $secretsPath
    Write-Warning "Created $secretsPath — edit it and fill in your API keys, then re-run."
    return $false
  }

  # opencode serve / the background service does not inherit your shell env, so
  # {env:VAR} placeholders only resolve for keys registered in service config.
  $opencode = Get-Command opencode -ErrorAction SilentlyContinue
  if (-not $opencode) {
    Write-Warning "opencode not on PATH — skipping service env registration."
    return $true
  }

  $registered = 0
  foreach ($line in Get-Content $secretsPath) {
    if ($line -notmatch '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.+)$') { continue }
    $key = $Matches[1]
    $value = $Matches[2].Trim()
    if (-not $value) { continue }
    & opencode service set env $key $value 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $registered++ } else { Write-Warning "  could not register $key in service config" }
  }
  Write-Step "Registered $registered key(s) in opencode service env (service.json)."
  return $true
}

# --- obscura (MCP browser engine) -------------------------------------------
# Obscura ships a Windows x86_64 zip (no C++ build tools). Fetched only when
# `obscura` is not already on PATH; unpacked to %LOCALAPPDATA%\obscura\bin and
# added to the user PATH so future shells (and OpenCode) resolve it.
# See docs/obscura.md.
$script:ObscuraVersion = if ($env:OBSCURA_VERSION) { $env:OBSCURA_VERSION } else { "0.2.6" }

function Invoke-Obscura {
  if (Get-Command obscura -ErrorAction SilentlyContinue) {
    Write-Step "obscura already installed: $((Get-Command obscura).Source)"
    return
  }

  $zip = "obscura-x86_64-windows-stealth.zip"
  $url = "https://github.com/h4ckf0r0day/obscura/releases/download/v$script:ObscuraVersion/$zip"
  $binDir = Join-Path $env:LOCALAPPDATA "obscura\bin"
  $tmp = Join-Path $env:TEMP "obscura-$([guid]::NewGuid().ToString('N'))"

  Write-Step "Downloading obscura v$script:ObscuraVersion (stealth)..."
  try {
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp $zip) -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path (Join-Path $tmp $zip) -DestinationPath $tmp -Force -ErrorAction Stop
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    # Keep obscura + obscura-worker side by side (parallel `scrape` needs the pair)
    Get-ChildItem -Path $tmp -Filter "obscura*.exe" | Copy-Item -Destination $binDir -Force
    # Fall back to extension-less binaries if the archive layout ever changes
    if (-not (Test-Path (Join-Path $binDir "obscura.exe"))) {
      Get-ChildItem -Path $tmp -Filter "obscura*" -File | Copy-Item -Destination $binDir -Force
    }
  } catch {
    Write-Warning "obscura: download/extract failed ($url) - the obscura MCP server will not start"
    Write-Warning "  grab it manually from https://github.com/h4ckf0r0day/obscura/releases"
  } finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  }

  if ((Test-Path (Join-Path $binDir "obscura.exe")) -or (Test-Path (Join-Path $binDir "obscura"))) {
    # Persist on the user PATH; also set it for this process so the render below sees it.
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$binDir*") {
      [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
      Write-Step "  added $binDir to the user PATH (restart your shell)"
    }
    $env:Path = "$env:Path;$binDir"
    Write-Step "obscura installed: $binDir"
  }
}

# --- open-design clone + daemon ------------------------------------------
function Invoke-OpenDesign {
  if (-not (Test-Path (Join-Path $Repo "open-design\apps\daemon"))) {
    Write-Step "Cloning open-design (shallow)..."
    git clone --depth 1 https://github.com/nexu-io/open-design.git (Join-Path $Repo "open-design")
  }
  if (-not (Test-Path (Join-Path $Repo "open-design\apps\daemon\dist\cli.js"))) {
    Write-Step "Building open-design daemon..."
    Push-Location (Join-Path $Repo "open-design")
    try { pnpm install; pnpm --filter @open-design/daemon run build } finally { Pop-Location }
  } else {
    Write-Step "open-design daemon already built."
  }
}

# --- run ----------------------------------------------------------------------
if ($Prereqs) { Invoke-Prereqs; exit 0 }
if ($Secrets) { Invoke-Secrets; exit 0 }

Invoke-Prereqs
Invoke-LinkAssets
Invoke-Obscura
Invoke-Render
Invoke-OpenDesign
Invoke-Secrets
Write-Step "Done. Verify: opencode (then /agents, /mcp to confirm)."
