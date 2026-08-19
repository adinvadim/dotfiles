# Minimal env for Cursor ACP. The agent dumps `zsh -ilc` state and later
# `eval`s it; a real ~/.zshrc (yc completion, omz) makes that eval hang.
export PATH="${HOME}/bin:/opt/homebrew/bin:${HOME}/.local/bin:${HOME}/.n/bin:${PATH}"
export CURSOR_AGENT="${CURSOR_AGENT:-1}"
export CURSOR_RECORD_SESSION="${CURSOR_RECORD_SESSION:-1}"
