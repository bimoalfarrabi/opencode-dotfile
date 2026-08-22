#!/usr/bin/env bash
# apply-patch.sh — apply (or re-apply) the Lerd Desktop dark title-bar patch.
# (aka lerd-dark-titlebar.sh — this is the canonical copy in this repo)
#
# Why: Lerd Desktop (Flatpak) is an Electron app whose Chromium frame renders a
# light title bar that ignores every theming signal (GTK_THEME, --force-dark-mode,
# gsettings, portal, nativeTheme) on WSLg. The patch removes the frame, injects a
# dark title band (drag + window controls) and shifts the dashboard below it.
# It also rewrites package.json "desktopName" → Lerd.desktop so the Wayland
# app_id matches the WSLg app-list key (see lerd/README.md).
#
# The patch lives inside the Flatpak's deployed files, so `flatpak update` wipes
# it. Run this script again after any Lerd update to re-apply. Idempotent.
# Install to ~/.local/bin:  ln -s "$REPO/lerd/apply-patch.sh" ~/.local/bin/lerd-dark-titlebar.sh
set -euo pipefail

SRC="$HOME/.local/share/flatpak/app/sh.lerd.Desktop/current/active/files/main"
MAIN="$SRC/src/main.js"
PRELOAD="$SRC/src/preload.js"
PKG="$SRC/package.json"

if [ ! -f "$MAIN" ] || [ ! -f "$PRELOAD" ] || [ ! -f "$PKG" ]; then
  echo "error: cannot find Lerd app files at $SRC" >&2
  exit 1
fi

if grep -q "TITLE_BAR_ENHANCER" "$MAIN" && grep -q '"Lerd.desktop"' "$PKG"; then
  echo "lerd-dark-titlebar: already patched, nothing to do."
  exit 0
fi

ts=$(date +%Y%m%d-%H%M%S)
cp "$MAIN" "$MAIN.bak-darktb-$ts"
cp "$PRELOAD" "$PRELOAD.bak-darktb-$ts"
cp "$PKG" "$PKG.bak-darktb-$ts"

python3 - "$MAIN" "$PRELOAD" "$PKG" <<'PY'
import sys
main, preload, pkg = sys.argv[1], sys.argv[2], sys.argv[3]

m = open(main).read()
m = m.replace(
  "const { app, BrowserWindow, Menu, shell, ipcMain, session } = require('electron')",
  "const { app, BrowserWindow, Menu, shell, ipcMain, session, nativeTheme } = require('electron')",
)
m = m.replace(
  "app.setName(process.env.FLATPAK_ID || 'Lerd')",
  "// Set the Wayland app_id / X11 WM_CLASS. Must match the desktop file key WSLg\n"
  "// derives from the .desktop filename (the segment after the last dot — see\n"
  "// microsoft/wslg#944), hence the flatpak id is deliberately NOT used: the\n"
  "// matching desktop file is \"Lerd.desktop\" → key \"Lerd\".\n"
  "app.setName('Lerd')\n\n"
  "// Dark theme: force the whole app dark. Chromium's own frame ignores this on\n"
  "// this stack (WSLg/Electron), so the frame is removed below and a dark title\n"
  "// band with window controls is injected instead.\n"
  "nativeTheme.themeSource = 'dark'\n\n"
  "// TITLE_BAR_ENHANCER runs in every loaded page (gate + dashboard). The dashboard\n"
  "// has no <header> element (Tailwind divs), so instead of overlaying controls on\n"
  "// its own top bar (which hides the search), this injects a real dark title band\n"
  "// at the top and shifts the whole app down below it.\n"
  "const TITLE_BAR_ENHANCER = `(() => {\n"
  "  const SHIFT = 40\n"
  "  const mkBtn = (glyph, hover, fn) => {\n"
  "    const b = document.createElement('button')\n"
  "    b.textContent = glyph\n"
  "    b.style.cssText = 'width:44px;height:40px;border:0;margin:0;padding:0;background:transparent;color:#cdd6f4;font:13px/40px sans-serif;text-align:center;cursor:default'\n"
  "    b.addEventListener('mouseenter', () => { b.style.background = hover })\n"
  "    b.addEventListener('mouseleave', () => { b.style.background = 'transparent' })\n"
  "    b.addEventListener('click', fn)\n"
  "    return b\n"
  "  }\n"
  "  const injectBand = () => {\n"
  "    if (document.getElementById('lerd-title-band')) return\n"
  "    const band = document.createElement('div')\n"
  "    band.id = 'lerd-title-band'\n"
  "    band.style.cssText = 'position:fixed;top:0;left:0;right:0;height:' + SHIFT + 'px;z-index:2147483646;display:flex;align-items:center;justify-content:space-between;background:#0b0f17;border-bottom:1px solid #1e1e2e;-webkit-app-region:drag;user-select:none'\n"
  "    const title = document.createElement('span')\n"
  "    title.textContent = 'Lerd'\n"
  "    title.style.cssText = 'padding-left:12px;font:600 13px/1 system-ui,sans-serif;color:rgba(205,214,244,.72);letter-spacing:.02em'\n"
  "    const bar = document.createElement('div')\n"
  "    bar.style.cssText = 'display:flex;align-items:center;height:100%;-webkit-app-region:no-drag'\n"
  "    bar.appendChild(mkBtn('\\\\u2013', 'rgba(255,255,255,.14)', () => window.lerdWin && window.lerdWin.minimize()))\n"
  "    bar.appendChild(mkBtn('\\\\u25A1', 'rgba(255,255,255,.14)', () => window.lerdWin && window.lerdWin.maximize()))\n"
  "    bar.appendChild(mkBtn('\\\\u2715', '#e81123', () => window.lerdWin && window.lerdWin.close()))\n"
  "    band.appendChild(title)\n"
  "    band.appendChild(bar)\n"
  "    document.body.appendChild(band)\n"
  "  }\n"
  "  const injectStyle = () => {\n"
  "    if (document.getElementById('lerd-title-style')) return\n"
  "    const st = document.createElement('style')\n"
  "    st.id = 'lerd-title-style'\n"
  "    // Shift the SPA mount (#app) below the fixed title band and shrink it to\n"
  "    // the remaining viewport; force the SPA's own fixed-100vh 'h-screen' layout\n"
  "    // root to track the shrunken mount (height:100%). Without that last rule\n"
  "    // the SPA root stays 100vh tall inside a (100vh - SHIFT) container, so its\n"
  "    // inner scroll viewport is SHIFT px too tall and the bottom SHIFT px of\n"
  "    // content is clipped/unreachable when scrolling to the bottom. CSS is used\n"
  "    // instead of JS DOM mutation so it applies automatically whenever the\n"
  "    // client-rendered SPA mounts (timing-safe).\n"
  "    st.textContent =\n"
  "      '#app{height:calc(100vh - ' + SHIFT + 'px);margin-top:' + SHIFT + 'px}' +\n"
  "      '#app > .h-screen{height:100%}'\n"
  "    document.head.appendChild(st)\n"
  "  }\n"
  "  injectBand()\n"
  "  injectStyle()\n"
  "})()`",
)
m = m.replace(
  "    icon: path.join(__dirname, '..', 'assets', 'icon.png'),\n    backgroundColor: '#0b0f17',",
  "    icon: path.join(__dirname, '..', 'assets', 'icon.png'),\n    frame: false,\n    backgroundColor: '#0b0f17',",
)
m = m.replace(
  "  return mainWindow\n}",
  "  // Inject the dark title-bar enhancer into every loaded page.\n"
  "  mainWindow.webContents.on('did-finish-load', () => {\n"
  "    mainWindow.webContents.executeJavaScript(TITLE_BAR_ENHANCER).catch(() => {})\n"
  "  })\n\n"
  "  return mainWindow\n}",
)
m = m.replace(
  "  ipcMain.handle('lerd:open-install', () => shell.openExternal('https://lerd.sh'))\n}",
  "  ipcMain.handle('lerd:open-install', () => shell.openExternal('https://lerd.sh'))\n"
  "  ipcMain.on('lerd:win-minimize', () => mainWindow && mainWindow.minimize())\n"
  "  ipcMain.on('lerd:win-maximize', () => {\n"
  "    if (!mainWindow) return\n"
  "    mainWindow.isMaximized() ? mainWindow.unmaximize() : mainWindow.maximize()\n"
  "  })\n"
  "  ipcMain.on('lerd:win-close', () => mainWindow && mainWindow.close())\n}",
)
open(main, "w").write(m)

p = open(preload).read()
p = p.replace(
  "  openInstall: () => ipcRenderer.invoke('lerd:open-install'),\n})",
  "  openInstall: () => ipcRenderer.invoke('lerd:open-install'),\n})\n\n"
  "// Window controls for the custom (frameless) dark title bar.\n"
  "contextBridge.exposeInMainWorld('lerdWin', {\n"
  "  minimize: () => ipcRenderer.send('lerd:win-minimize'),\n"
  "  maximize: () => ipcRenderer.send('lerd:win-maximize'),\n"
  "  close: () => ipcRenderer.send('lerd:win-close'),\n})",
)
open(preload, "w").write(p)

q = open(pkg).read()
q = q.replace(
  '"desktopName": "sh.lerd.Desktop.desktop"',
  '"desktopName": "Lerd.desktop"',
)
open(pkg, "w").write(q)
PY

if grep -q "TITLE_BAR_ENHANCER" "$MAIN" && grep -q '"Lerd.desktop"' "$PKG"; then
  echo "lerd-dark-titlebar: patch applied (backups: *.bak-darktb-$ts)."
else
  echo "lerd-dark-titlebar: FAILED — file layout changed, patch needs updating." >&2
  exit 1
fi
