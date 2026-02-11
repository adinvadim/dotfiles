# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export JAVA_HOME="/opt/homebrew/opt/openjdk"
export N_PREFIX=$HOME/.n
export PATH="$N_PREFIX/bin:$PATH"
export CLAUDE_CODE_DISABLE_COAUTHORSHIP=1

alias cc="claude --dangerously-skip-permissions"
alias cx="codex --yolo"

# Claude Code with Ollama (local models)
olcc() {
  ANTHROPIC_AUTH_TOKEN=ollama \
  ANTHROPIC_API_KEY="" \
  ANTHROPIC_BASE_URL=http://localhost:11434 \
  claude --dangerously-skip-permissions --model "${1:-qwen3-coder}" "${@:2}"
}

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME=""


plugins=(git)

source $ZSH/oh-my-zsh.sh

fpath+=("$(brew --prefix)/share/zsh/site-functions")
autoload -U promptinit; promptinit
prompt pure

export PATH="${HOME}/.pyenv/shims:${PATH}"

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

lg() {
    export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

    lazygit "$@"

    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
            cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
            rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
}


tmuxbu() {
  # Check if the session exists, discarding output
  # We can check $? for the exit status (zero for success, non-zero for failure)
  tmux has-session -t "bu" 2>/dev/null

  if [ $? != 0 ] ; then
    tmux new-session -A -c '$HOME/sandbox/bu/bu-frontend-v2/' -n 'frontend' -s 'bu' 'nvim; exec zsh'  \; \
      new-window -a -n 'backend' -c '$HOME/sandbox/bu/bu-serverless/' 'nvim; exec zsh' \; \
      new-window -a -n 'console' -c '$HOME/sandbox/bu' \; \
      split-window -h -c '$HOME/sandbox/bu' \; \
      new-window -a -n 'server' -c '$HOME/sandbox/bu/bu-frontend-v2' \; \
      split-window -h -c '$HOME/sandbox/bu/bu-serverless' \; \
      new-window -a -n 'mobile' -c '$HOME/sandbox/bu/bu-mobile' \; \
      new-window -a -n 'email' -c '$HOME/sandbox/bu/bu-email' \; \
      set-option -t "frontend" remain-on-exit on \; \
      set-option -t "backend" remain-on-exit on \;
  else
    tmux attach-session -t "bu"
  fi

}

alias tmxbu="tmuxbu"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/comp/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"

# The next line updates PATH for CLI.
if [ -f '/Users/comp/yandex-cloud/path.bash.inc' ]; then source '/Users/comp/yandex-cloud/path.bash.inc'; fi

# The next line enables shell command completion for yc.
if [ -f '/Users/comp/yandex-cloud/completion.zsh.inc' ]; then source '/Users/comp/yandex-cloud/completion.zsh.inc'; fi

# Disable Powerlevel10k when Cursor Agent runs
if [[ -n "$CURSOR_AGENT" ]]; then
  # Skip theme initialization for better compatibility
else
  [[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

tmxhq() {
  tmux has-session -t "hq" 2>/dev/null

  if [ $? != 0 ]; then
    tmux new-session -A -c ~/sandbox/medivey/medivey-hq -n 'hq-1' -s 'hq' 'claude; exec zsh' \; \
      new-window -a -n 'hq-2' -c ~/sandbox/medivey/medivey-hq-2 'claude; exec zsh' \; \
      new-window -a -n 'hq-3' -c ~/sandbox/medivey/medivey-hq-3 'claude; exec zsh' \; \
      new-window -a -n 'hq-4' -c ~/sandbox/medivey/medivey-hq-4 'claude; exec zsh' \; \
      new-window -a -n 'hq-5' -c ~/sandbox/medivey/medivey-hq-5 'claude; exec zsh' \; \
      select-window -t 'hq-1'
  else
    tmux attach-session -t "hq"
  fi
}

tmxnai() {
  tmux has-session -t "novostroy" 2>/dev/null

  if [ $? != 0 ]; then
    tmux new-session -A -c ~/sandbox/novostroyai -n 'ns-1' -s 'novostroy' 'claude; exec zsh' \; \
      new-window -a -n 'ns-2' -c ~/sandbox/novostroyai-2 'claude; exec zsh' \; \
      new-window -a -n 'ns-3' -c ~/sandbox/novostroyai-3 'claude; exec zsh' \; \
      new-window -a -n 'ns-4' -c ~/sandbox/novostroyai-4 'claude; exec zsh' \; \
      new-window -a -n 'ns-5' -c ~/sandbox/novostroyai-5 'claude; exec zsh' \; \
      select-window -t 'ns-1'
  else
    tmux attach-session -t "novostroy"
  fi
}

tmxobs() {
  tmux has-session -t "obsidian" 2>/dev/null

  if [ $? != 0 ]; then
    tmux new-session -A -c ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents -n 'obs' -s 'obsidian' 'claude --dangerously-skip-permissions; exec zsh' \; \
      split-window -h -c ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents \; \
      select-pane -t 0
  else
    tmux attach-session -t "obsidian"
  fi
}


# bun completions
[ -s "/Users/comp/.bun/_bun" ] && source "/Users/comp/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/Users/comp/.opencode/bin:$PATH

. "$HOME/.local/bin/env"
