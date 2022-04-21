# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/adinvadim/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME=""


plugins=(git)

source $ZSH/oh-my-zsh.sh

autoload -U promptinit; promptinit
prompt pure

code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}


# The next line updates PATH for Yandex Cloud CLI.
if [ -f '/Users/adinvadim/yandex-cloud/path.bash.inc' ]; then source '/Users/adinvadim/yandex-cloud/path.bash.inc'; fi

# The next line enables shell command completion for yc.
if [ -f '/Users/adinvadim/yandex-cloud/completion.zsh.inc' ]; then source '/Users/adinvadim/yandex-cloud/completion.zsh.inc'; fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/adinvadim/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/adinvadim/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/adinvadim/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/adinvadim/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
