# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a minimal Neovim configuration using the Lazy.nvim plugin manager. The configuration follows a modular structure:

- **Entry point**: `init.lua` - Bootstraps lazy.nvim and loads core configuration
- **Core options**: `lua/vim-options.lua` - Basic Vim settings and key mappings
- **Plugin structure**: `lua/plugins/` - Each plugin has its own Lua file with configuration

## Configuration Structure

- **Plugin Manager**: Uses lazy.nvim for plugin management with lazy loading
- **Plugin Lock File**: `lazy-lock.json` tracks exact plugin versions
- **Modular Plugins**: Each plugin is configured in its own file in `lua/plugins/`

Key plugins configured:
- LSP setup via Mason and nvim-lspconfig
- Formatting via none-ls with stylua, black, and prettier
- DAP debugging with nvim-dap and dapui
- File explorer via neo-tree
- Git integration via gitsigns
- Auto-completion via nvim-cmp

## Common Key Mappings

- Leader key: Space
- Window navigation: `<C-h/j/k/l>`
- Clear search highlight: `<leader>h`
- LSP actions: `<leader>gd` (definition), `<leader>gr` (references), `<leader>ca` (code actions), `<leader>rn` (rename)
- Formatting: `<leader>gf`
- Debug: `<leader>dt` (toggle breakpoint), `<leader>dc` (continue), `<leader>dx` (terminate)

## Language Servers

Configured LSPs via Mason:
- lua_ls (Lua)
- ts_ls (TypeScript/JavaScript)  
- html, cssls (Web)
- pylsp (Python)

## Formatters

Configured via none-ls:
- stylua (Lua)
- black (Python)
- prettier (JSON, JS/TS/JSX/TSX)

## Development Workflow

1. **Plugin Management**: Use `:Lazy` to manage plugins
2. **LSP Installation**: Mason auto-installs language servers
3. **Formatting**: `<leader>gf` formats current buffer
4. **File Navigation**: Neo-tree provides file explorer functionality

## File Locations

- All configuration lives in `/home/sieg/.config/nvim/`
- Plugin configs are in `lua/plugins/[plugin-name].lua`
- Core Vim options are in `lua/vim-options.lua`