# env-config

Personal development environment configuration (dotfiles) for macOS. Includes shell, terminal emulator, and editor configurations.

## Contents

| File/Directory | Description |
|---|---|
| `.zshrc` | Zsh shell configuration with Powerlevel10k prompt |
| `.wezterm.lua` | WezTerm terminal emulator configuration |
| `nvim/` | Neovim configuration based on NvChad v2.5 |

## Setup

### Prerequisites

Install via [Homebrew](https://brew.sh/):

```sh
brew install neovim powerlevel10k zsh-autosuggestions zsh-syntax-highlighting
```

Install [WezTerm](https://wezfurlong.org/wezterm/) and a [Nerd Font](https://www.nerdfonts.com/) (JetBrains Mono is used in this config).

### Installation

Clone the repository:

```sh
git clone <repo-url> ~/env-config
```

Symlink the configuration files to their expected locations:

```sh
ln -sf ~/env-config/.zshrc ~/.zshrc
ln -sf ~/env-config/.wezterm.lua ~/.wezterm.lua
ln -sf ~/env-config/nvim ~/.config/nvim
```

On first Neovim launch, [lazy.nvim](https://github.com/folke/lazy.nvim) will bootstrap itself and install all plugins automatically.

## Highlights

### Zsh (`.zshrc`)

- **Prompt**: Powerlevel10k with instant prompt
- **Plugins**: git (Oh-My-Zsh), zsh-autosuggestions, zsh-syntax-highlighting
- **PATH**: Homebrew, Go (`~/go/bin`), pipx (`~/.local/bin`)
- **History**: Shared across sessions with deduplication

### WezTerm (`.wezterm.lua`)

- **Leader key**: `ALT + q` (tmux-style workflow)
- **Theme**: Catppuccin Macchiato
- **Font**: JetBrains Mono, size 14
- **Tab management**: `LEADER + c/x/b/n/0-9`
- **Pane splitting**: `LEADER + \` (horizontal), `LEADER + -` (vertical)
- **Pane navigation**: `LEADER + h/j/k/l` (vim-style)

### Neovim (`nvim/`)

- **Framework**: [NvChad](https://nvchad.com/) v2.5
- **Theme**: Aquarium
- **LSP**: HTML, CSS, Go (`gopls`)
- **Formatting**: StyLua (Lua files)
- **Key plugins**: telescope.nvim, nvim-cmp, nvim-treesitter, nvim-tree, gitsigns, auto-session, mason.nvim
- **Custom mappings**: `<Space>` as leader, `jk` to exit insert mode, window/tab/search bindings

## License

Neovim configuration is released under the [Unlicense](nvim/LICENSE). Other dotfiles have no explicit license.
