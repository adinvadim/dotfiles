# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/adinvadim/.oh-my-zsh"

export JAVA_HOME=$(/usr/libexec/java_home)

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
    tmux new-session -A -c '/Users/adinvadim/sandbox/bu/bu-frontend-v2/' -n 'frontend' -s 'bu' 'nvim; exec zsh'  \; \
      new-window -a -n 'backend' -c '/Users/adinvadim/sandbox/bu/bu-serverless/' 'nvim; exec zsh' \; \
      new-window -a -n 'console' -c '/Users/adinvadim/sandbox/bu' \; \
      split-window -h -c '/Users/adinvadim/sandbox/bu' \; \
      new-window -a -n 'server' -c '/Users/adinvadim/sandbox/bu/bu-frontend-v2' \; \
      split-window -h -c '/Users/adinvadim/sandbox/bu/bu-serverless' \; \
      new-window -a -n 'mobile' -c '/Users/adinvadim/sandbox/bu/bu-mobile' \; \
      new-window -a -n 'email' -c '/Users/adinvadim/sandbox/bu/bu-email' \; \
      set-option -t "frontend" remain-on-exit on \; \
      set-option -t "backend" remain-on-exit on \;
  else
    tmux attach-session -t "bu"
  fi

}

alias tmxbu="tmuxbu"
