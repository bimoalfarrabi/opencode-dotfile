# Shell — kustomisasi (Windows Terminal + WSL Ubuntu)

Dokumentasi kustomisasi shell di kedua sisi: **PowerShell 7** (Windows) dan **zsh**
(WSL Ubuntu), termasuk file konfigurasinya — agar mudah direplikasi ke mesin baru.
Tema warna menyeluruh **Catppuccin Mocha** (senada dengan Windows Terminal
[`docs/windows-terminal.md`](windows-terminal.md) dan opencode
[`config/themes/`](../config/themes/)).

## Arsitektur

```
Windows Terminal
├── PowerShell 7 (default profile)   → oh-my-posh (zen.toml) + bridge coreutils
└── Ubuntu (WSL)                     → zsh: prompt custom + plugin zsh-users + Catppuccin
```

## File & lokasi

| File di repo | Lokasi target | Shell |
|--------------|---------------|-------|
| `shell/zsh/.zshrc` | `~/.config/zsh/.zshrc` (+ symlink `~/.zshrc` → sana) | zsh (WSL) |
| `shell/powershell/Microsoft.PowerShell_profile.ps1` | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` | PowerShell 7 |
| `shell/oh-my-posh/zen.toml` | `E:\Koding\zen.toml` (path di-profile; ubah bila beda) | oh-my-posh |
| plugin zsh (bukan di repo — clone saat setup) | `~/.config/zsh/{completions,syntax-highlighting,autosuggestions,history-substring-search}` | zsh |

## Kustomisasi zsh (WSL Ubuntu)

Diadaptasi dari default shell CachyOS (tanpa oh-my-zsh):

- **Prompt PowerShell-style** (`prompt_powershell`): `dir WSL [git]` / `❯`, warna
  Catppuccin Mocha truecolor (path `#89b4fa`, WSL `#cba6f7`, git `#fab387`, prompt `#94e2d5`).
- **Syntax highlighting Catppuccin Mocha** — peta lengkap `ZSH_HIGHLIGHT_STYLES`
  (builtin/command biru, string kuning, path hijau underline, error merah, komentar abu italic).
- **Autosuggestion** `fg=#6c7086`; **history** 100k dengan substring-search
  (`bindkey` ↑/↓), share antar sesi, ignore dups.
- **Navigation**: `AUTO_CD`, `AUTO_PUSHD`, koreksi salah ketik, completion fuzzy
  (`compinit` + matcher + menu select + `LS_COLORS`).
- **Plugin** (semua dari `zsh-users/*`, di-clone oleh `shell/setup-zsh.sh`):
  zsh-completions, zsh-syntax-highlighting, zsh-autosuggestions, zsh-history-substring-search.
- **LS_COLORS Catppuccin Mocha** (truecolor penuh) + utilitas umum + `lerd()` /
  `lerd-dns` (lihat modul `lerd/`).
- Catatan: powerlevel10k tersedia (`~/.config/zsh/p10k`) tapi **tidak di-source** oleh
  `.zshrc` saat ini.

## Kustomisasi PowerShell 7 (Windows)

- **oh-my-posh** dengan tema `zen.toml` (baris pertama profile:
  `oh-my-posh init pwsh --config 'E:\Koding\zen.toml' | Invoke-Expression`).
- **Bridge GNU coreutils** (blok `DO NOT MODIFY -- coreutils`): menulis ulang perintah
  coreutils (`ls`, `grep`, `cat`, dll) ke `.cmd`-equivalent saat mengetik
  (via override `PSConsoleHostReadLine` + analisis AST), supaya `ls --color=auto` dll
  berfungsi dengan quoting MSVCRT yang benar. **Jangan diedit** — di-generate alat.
  Butuh GNU coreutils terpasang di `C:\Program Files\coreutils\cmd\` (mis. via
  [winutils](https://github.com/lukesampson/psutils) / scoop `coreutils`).

## Cara migrasi

### WSL Ubuntu (zsh)

```sh
cd opencode-dotfile
./shell/setup-zsh.sh        # idempotent: .zshrc + symlink + clone plugin zsh-users
./shell/setup-zsh.sh --p10k # opsional: + powerlevel10k (tidak di-source default)
```

Lalu buka zsh baru. Bila username beda dari `/home/viasco`, sesuaikan path
(`$HOME/.local/bin`, bun, lerd, nvm) di `~/.config/zsh/.zshrc`.

### Windows (PowerShell 7)

1. Install **PowerShell 7** + **oh-my-posh** (`winget install JanDeDobbeleer.OhMyPosh`)
   + **GNU coreutils** (untuk bridge — `C:\Program Files\coreutils\cmd\`).
2. Salin `shell/powershell/Microsoft.PowerShell_profile.ps1` →
   `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`.
3. Salin `shell/oh-my-posh/zen.toml` → lokasi sesuai baris pertama profile
   (default `E:\Koding\zen.toml` — buat folder `E:\Koding` bila perlu, atau ubah path di profile).
4. Buka PowerShell baru. Font wajib: **FiraCode Nerd Font** (lihat docs/windows-terminal.md).

## Struktur modul

```
shell/
├── setup-zsh.sh                # instalasi zsh WSL (idempotent)
├── zsh/.zshrc                  # konfigurasi zsh (source of truth)
├── powershell/Microsoft.PowerShell_profile.ps1
└── oh-my-posh/zen.toml         # tema oh-my-posh
```
