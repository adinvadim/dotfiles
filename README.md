# dotfiles

Personal macOS configuration managed with [Dotbot](https://github.com/anishathalye/dotbot).

The repository configures the shell, Git, tmux, Neovim, terminal applications, and several coding agents. It also links shared agent instructions and skills into their expected locations.

## Install

Review [`install.conf.yaml`](install.conf.yaml) before running the installer. It changes files in the home directory, installs global tools, and restarts the `cliproxyapi` Homebrew service.

```sh
git clone --recurse-submodules <repository-url> ~/sandbox/dotfiles
cd ~/sandbox/dotfiles
./install
```

The current setup targets macOS and expects Git, Homebrew, and npm to be available.

## Repository map

- `install.conf.yaml` defines directories, symlinks, packages, and setup commands.
- `AGENTS.md` is the shared instruction source; `CLAUDE.md` is its compatibility symlink.
- `agents/skills/` contains skills shared by supported coding agents.
- `bin/` contains personal command-line helpers.
- `claude/`, `codex/`, and `pi/` contain agent-specific configuration.
- `nvim/`, `kitty/`, `ghostty/`, and `herdr/` contain application configuration.

Machine-local authentication and generated agent artifacts are intentionally excluded through `.gitignore`.
