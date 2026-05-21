# --- 1. History Settings ---

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt interactive_comments


# --- 2. Completion Engine (CRITICAL for directory suggestions) ---
autoload -Uz compinit
compinit
# Case-insensitive completion (so 'cd doc' finds 'Documents')
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# --- 3. Essential Aliases ---
alias ls='lsd --color=auto'
alias ll='lsd -la'
alias grep='grep --color=auto'
alias enable-wall='systemctl --user start awww-daemon.service && set-wallpaper.sh'
alias tv-cleanup='adb connect 192.168.220.37:5555 && adb -s 192.168.220.37:5555 shell am kill-all'
alias stop-waydroid='sudo systemctl stop waydroid-container'
alias start-waydroid='sudo systemctl start waydroid-container && waydroid show-full-ui'
alias start-venv='source ~/.venv/bin/activate'
alias run-spotify='spicetify watch -s'
alias i='yay -S'
alias s='pacseek'
alias sp='spotify_player'
alias ghg='ghgrab --out "~/github"'
# --- 4. Suggestions & Highlighting Config ---
# We put completion FIRST so it prioritizes current files over history
ZSH_AUTOSUGGEST_STRATEGY=(completion history)
# Using 244 (Medium Gray) for visibility on Everforest Hard
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'

# --- 5. Plugins (Sourced after config) ---
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- 6. Prompt ---
eval "$(starship init zsh)"
export PATH="$HOME/.local/bin:$PATH"
export XDG_SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"

