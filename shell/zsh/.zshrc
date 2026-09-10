# ============================== CACHYOS-STYLE ZSH ==============================
# Pengaturan & gaya diadaptasi dari default shell CachyOS (Zsh + powerlevel10k
# + autosuggestion + syntax highlighting + fuzzy completion).
#
# File ini dipakai via symlink ~/.zshrc -> ~/.config/zsh/.zshrc
# Prompt dikustomisasi dengan: p10k configure

# ---- Histori (tinggal ketik sebagian, substring search) ----
export HISTFILE=~/.config/zsh/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# ---- Navigation ----
setopt AUTO_CD                    # cd tanpa perintah cd
setopt AUTO_PUSHD                 # history direktori
setopt PUSHD_IGNORE_DUPS
setopt CORRECT                   # saran koreksi salah ketik
setopt CORRECT_ALL
setopt AUTO_LIST                 # tab list otomatis saat ambigu
setopt AUTO_MENU                 # tab siklus saat ambigu

# ---- Completion ----
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu no          # REQUIRED oleh fzf-tab: biarkan ia menangkap prefix
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' file-sort modification

# ---- Plugins ----
source ~/.config/zsh/completions/zsh-completions.plugin.zsh

# ---- Fuzzy filesystem completion (fzf + fzf-tab) — ala CachyOS ----
# Tab = fuzzy picker atas file/direktori NYATA di filesystem (termasuk yang belum
# pernah dibuka), bukan saran dari history. fzf-tab WAJIB dimuat setelah compinit
# dan SEBELUM zsh-autosuggestions / zsh-syntax-highlighting (lihat Aloxaf/fzf-tab).
export PATH="$HOME/.fzf/bin:$PATH"
source "$HOME/.fzf/shell/key-bindings.zsh" 2>/dev/null   # Ctrl-T file, Ctrl-R history, Alt-C cd
source "$HOME/.fzf/shell/completion.zsh" 2>/dev/null     # **<Tab> fuzzy completion
source "$HOME/.config/zsh/fzf-tab/fzf-tab.plugin.zsh" 2>/dev/null

zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' continuous-trigger '/'   # tiap '/' re-masuk fuzzy search (deep path)
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:*' fzf-preview 'cat $realpath 2>/dev/null | head -80'

source ~/.config/zsh/syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.config/zsh/autosuggestions/zsh-autosuggestions.zsh
source ~/.config/zsh/history-substring-search/zsh-history-substring-search.zsh

# ---- Catppuccin Mocha (zsh-syntax-highlighting) ----
# Menyamakan warna shell dengan palette Catppuccin Mocha yang dipakai di Windows.
ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=#f38ba8
ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=#cba6f7
ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[precommand]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=#a6e3a1,underline
ZSH_HIGHLIGHT_STYLES[builtin]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[function]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[command]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[hashed-command]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[arithmetic-expansion]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=#f9e2af
ZSH_HIGHLIGHT_STYLES[assign]=fg=#cba6f7
ZSH_HIGHLIGHT_STYLES[globbing]=fg=#fab387
ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=#cba6f7
ZSH_HIGHLIGHT_STYLES[comment]=fg=#6c7086,italic
ZSH_HIGHLIGHT_STYLES[path]=fg=#a6e3a1,underline
ZSH_HIGHLIGHT_STYLES[path_prefix]=fg=#a6e3a1,underline
ZSH_HIGHLIGHT_STYLES[path_approx]=fg=#fab387,underline
ZSH_HIGHLIGHT_STYLES[named-fd]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[redirection]=fg=#f38ba8
ZSH_HIGHLIGHT_STYLES[arg0]=fg=#89b4fa
ZSH_HIGHLIGHT_STYLES[command-substitution]=fg=#cdd6f4
ZSH_HIGHLIGHT_STYLES[process-substitution]=fg=#cdd6f4
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]=fg=#f38ba8,underline
ZSH_HIGHLIGHT_STYLES[command-substitution-unquoted]=fg=#cdd6f4
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]=fg=#cdd6f4
ZSH_HIGHLIGHT_STYLES[precommand-unknown]=fg=#f38ba8

# ---- Catppuccin Mocha (autosuggestion) ----
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"

# ---- Bindings (vi-ish, tapi tab tetap) ----
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M emacs '^[[A' history-substring-search-up
bindkey -M emacs '^[[B' history-substring-search-down

# ---- PowerShell-style prompt (oh-my-posh look, Catppuccin Mocha) ----
# Layout meniru PowerShell Windows:
#   ~ WSL [main]
#   ❯
# Warna mengikuti palette Catppuccin Mocha (truecolor).
function prompt_powershell() {
  local dir="$PWD"
  dir=${dir/#$HOME/\~}                          # ~/ untuk home

  local git_ps1=""
  if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
    local b
    b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    git_ps1=" %F{#fab387}[$b]%f"               # peach (git)
  fi

  # path: blue #89b4fa | WSL: mauve #cba6f7 | prompt: teal #94e2d5
  PROMPT="%F{#89b4fa}${dir}%f %F{#cba6f7}WSL%f${git_ps1}"$'\n'"%F{#94e2d5}❯%f "
  RPROMPT=""
}
precmd_functions+=(prompt_powershell)

# ---- Konfigurasi p10k interaktif (jalankan sekali bila perlu) ----
# p10k configure

# ---- PATH (login zsh tidak memuat .bashrc, jadi didefinisikan ulang di sini) ----
export PATH="/home/viasco/.local/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="/home/viasco/.local/share/lerd/bin:$PATH"

# ---- Lerd (Electron/flatpak) ----
# Dark mode (konten + title bar) ditangani oleh patch di dalam app,
# lihat ~/.local/bin/lerd-dark-titlebar.sh (re-apply setelah update Lerd).
#
# Wrapper pintar: TANPA argumen = buka Desktop app (GUI); DENGAN argumen =
# terusan ke CLI asli (~/.local/bin/lerd — update, start, dashboard, dll).
# Tanpa ini `lerd update` dkk. malah membuka GUI karena fungsi menutupi binary.
lerd() {
  if [ $# -eq 0 ]; then
    flatpak run sh.lerd.Desktop
  else
    "$HOME/.local/bin/lerd" "$@"
  fi
}

# Perbaiki split-DNS Lerd di WSL (tulis ulang Global DNS + routing *.test)
alias lerd-dns='~/bin/lerd-dns-fix.sh'

# ---- Utilitas umum ----
export EDITOR="nano"
export VISUAL="$EDITOR"

# ---- Alias CachyOS-style ----
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -la'
alias l='ls -l'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias cls='clear'
alias reload='source ~/.config/zsh/.zshrc'

# ---- LS_COLORS Catppuccin Mocha (truecolor) ----
# di=biru bold, ln=mauve, so/pi=peach, ex=hijau, perangkat=merah muda,
# arsip=subtext0, kode=kuning/teal/mauve, media=pink, dokumen=sky, csv=kuning.
export LS_COLORS="di=1;38;2;137;180;250:ln=38;2;203;166;247:so=38;2;250;179;135:pi=38;2;250;179;135:ex=38;2;166;227;161:bd=38;2;245;194;231:cd=38;2;245;194;231:su=38;2;245;194;231:sg=38;2;245;194;231:tw=38;2;245;194;231:ow=38;2;245;194;231:st=38;2;245;194;231:*.7z=38;2;166;173;200:*.a=38;2;166;173;200:*.apk=38;2;166;173;200:*.arj=38;2;166;173;200:*.bin=38;2;166;173;200:*.bz=38;2;166;173;200:*.bz2=38;2;166;173;200:*.cab=38;2;166;173;200:*.crate=38;2;166;173;200:*.deb=38;2;166;173;200:*.dmg=38;2;166;173;200:*.ear=38;2;166;173;200:*.egg=38;2;166;173;200:*.gem=38;2;166;173;200:*.gz=38;2;166;173;200:*.iso=38;2;166;173;200:*.jar=38;2;166;173;200:*.lz=38;2;166;173;200:*.lz4=38;2;166;173;200:*.lzh=38;2;166;173;200:*.lzma=38;2;166;173;200:*.lzo=38;2;166;173;200:*.msi=38;2;166;173;200:*.pkg=38;2;166;173;200:*.rar=38;2;166;173;200:*.rpm=38;2;166;173;200:*.rz=38;2;166;173;200:*.tar=38;2;166;173;200:*.tbz=38;2;166;173;200:*.tbz2=38;2;166;173;200:*.tgz=38;2;166;173;200:*.txz=38;2;166;173;200:*.war=38;2;166;173;200:*.xz=38;2;166;173;200:*.z=38;2;166;173;200:*.zip=38;2;166;173;200:*.Z=38;2;166;173;200:*.ts=38;2;203;166;247:*.tsx=38;2;203;166;247:*.rs=38;2;250;179;135:*.rb=38;2;250;179;135:*.go=38;2;148;226;213:*.py=38;2;148;226;213:*.tex=38;2;148;226;213:*.sh=38;2;148;226;213:*.bash=38;2;148;226;213:*.zsh=38;2;148;226;213:*.fish=38;2;148;226;213:*.js=38;2;249;226;175:*.jsx=38;2;249;226;175:*.json=38;2;249;226;175:*.yml=38;2;249;226;175:*.yaml=38;2;249;226;175:*.toml=38;2;249;226;175:*.css=38;2;245;194;231:*.scss=38;2;245;194;231:*.sass=38;2;245;194;231:*.less=38;2;245;194;231:*.html=38;2;250;179;135:*.htm=38;2;250;179;135:*.xml=38;2;250;179;135:*.sql=38;2;245;194;231:*.md=38;2;137;220;235:*.markdown=38;2;137;220;235:*.dockerfile=38;2;137;180;250:*.gitignore=38;2;166;173;200:*.png=38;2;245;194;231:*.jpg=38;2;245;194;231:*.jpeg=38;2;245;194;231:*.gif=38;2;245;194;231:*.svg=38;2;245;194;231:*.ico=38;2;245;194;231:*.bmp=38;2;245;194;231:*.webp=38;2;245;194;231:*.mp3=38;2;245;194;231:*.wav=38;2;245;194;231:*.flac=38;2;245;194;231:*.ogg=38;2;245;194;231:*.mp4=38;2;245;194;231:*.avi=38;2;245;194;231:*.mkv=38;2;245;194;231:*.mov=38;2;245;194;231:*.webm=38;2;245;194;231:*.pdf=38;2;137;220;235:*.doc=38;2;137;220;235:*.docx=38;2;137;220;235:*.xls=38;2;137;220;235:*.xlsx=38;2;137;220;235:*.ppt=38;2;137;220;235:*.pptx=38;2;137;220;235:*.odt=38;2;137;220;235:*.csv=38;2;249;226;175"

# To customize prompt, run `p10k configure`

# Lerd completions
fpath=(/home/viasco/.local/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# ---- Discord IPC bridge (WSL -> Windows) ----
# Jaga bridge npiperelay/socat tetap hidup: mulai sekali kalau belum jalan.
if ! pgrep -f "discord-ipc-bridge" > /dev/null; then
  ~/scripts/discord-ipc-bridge.sh &
fi
