# Windows Terminal — kustomisasi (Catppuccin Mocha)

Dokumentasi setup Windows Terminal pada mesin ini, agar mudah direplikasi ke
mesin baru. Semua pengaturan berada di **satu file JSON** — cukup salin ke mesin
baru (atau tempel bagian yang relevan).

## Lokasi file

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

Di WSL: `/mnt/c/Users/<user>/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`

> Versi unpackaged (tanpa Store) memakai path berbeda:
> `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json`.

## Prasyarat

- **Windows Terminal** (Microsoft Store / winget: `winget install Microsoft.WindowsTerminal`)
- **FiraCode Nerd Font** — dipakai `profiles.defaults.font.face`; install dari
  [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts/releases) (font family: `FiraCode Nerd Font`).
  Font ini juga yang membuat ikon/simbol prompt (mis. `❯`) di zsh tampil benar.

## Yang dikustomisasi

### 1. Defaults semua profil

```json
"defaults": {
    "colorScheme": "Catppuccin Mocha",
    "cursorShape": "filledBox",
    "experimental.retroTerminalEffect": false,
    "font": { "face": "FiraCode Nerd Font" },
    "opacity": 85,
    "useAcrylic": true
}
```

### 2. Skema warna "Catppuccin Mocha" (16 warna + cursor)

```json
"schemes": [{
    "name": "Catppuccin Mocha",
    "background": "#1E1E2E",  "foreground": "#CDD6F4",
    "cursorColor": "#F5E0DC", "selectionBackground": "#585B70",
    "black": "#45475A", "red": "#F38BA8", "green": "#A6E3A1",
    "yellow": "#F9E2AF", "blue": "#89B4FA", "purple": "#F5C2E7",
    "cyan": "#94E2D5", "white": "#BAC2DE",
    "brightBlack": "#585B70", "brightRed": "#F38BA8", "brightGreen": "#A6E3A1",
    "brightYellow": "#F9E2AF", "brightBlue": "#89B4FA", "brightPurple": "#F5C2E7",
    "brightCyan": "#94E2D5", "brightWhite": "#A6ADC8"
}]
```

### 3. Tema aplikasi "Catppuccin Mocha"

```json
"theme": "Catppuccin Mocha",
"themes": [{
    "name": "Catppuccin Mocha",
    "tab": { "background": "#1E1E2EFF", "iconStyle": "default", "showCloseButton": "always", "unfocusedBackground": null },
    "tabRow": { "background": "terminalBackground", "unfocusedBackground": "terminalBackground" },
    "window": { "applicationTheme": "dark", "experimental.rainbowFrame": false, "frame": null, "unfocusedFrame": null, "useMica": false }
}]
```

### 4. Keybindings + perilaku salin

```json
"copyFormatting": "none",
"copyOnSelect": false,
"keybindings": [
    { "command": { "action": "copy", "singleLine": false }, "keys": "ctrl+c" },
    { "command": "paste", "keys": "ctrl+v" },
    { "command": "find", "keys": "ctrl+shift+f" },
    { "command": { "action": "splitPane", "split": "auto", "splitMode": "duplicate" }, "keys": "alt+shift+d" }
]
```

### 5. Profil penting

| Profil | GUID | Catatan |
|--------|------|---------|
| **PowerShell** (default) | `{574e775e-...}` | `defaultProfile` — shell utama |
| **Ubuntu** (WSL) | `{8ccffa95-...}` | sumber `Microsoft.WSL`; mewarisi defaults Catppuccin — senada dengan prompt zsh (`prompt_powershell`) & LS_COLORS Catppuccin Mocha di `~/.zshrc` |
| **Laragon** | `{396817ac-...}` | `powershell -NoExit -ExecutionPolicy Bypass -File C:/laragon/usr/laragon.ps1`, startingDirectory `C:\laragon\www`, icon khusus |

## Cara migrasi ke mesin baru

1. Install Windows Terminal + FiraCode Nerd Font (lihat prasyarat).
2. Salin `settings.json` lama ke path di atas (GUID profil PowerShell/Ubuntu/Laragon
   boleh beda di mesin baru — sesuaikan `defaultProfile`).
   Atau tempel manual: defaults → skema → tema → keybindings (potongan di atas).
3. Buka Windows Terminal — skema/tema langsung aktif tanpa restart.

## Catatan

- **Catatan WSL**: profil Ubuntu memakai warna skema yang sama dengan zsh; kalau prompt
  zsh tampak "putus" (ikon `❯` kotak), berarti FiraCode Nerd Font belum terpasang.
- `useAcrylic: true` + `opacity: 85` memberi efek transparan; matikan (`false` / opacity 100)
  bila performa render dirasa lambat.
- Skema/tema Catppuccin Mocha ini senada dengan tema opencode
  (`config/themes/catppuccin-mocha-transparent.json`) — lihat bagian kustomisasi opencode
  di README utama.
