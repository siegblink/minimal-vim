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
- LSP setup via Mason and nvim-lspconfig (`lsp-config.lua`)
- Formatting via none-ls with stylua, black, and prettier (`none-ls.lua`)
- DAP debugging with nvim-dap and dapui (`debugging.lua`)
- File explorer via neo-tree (`neo-tree.lua`)
- Git integration via gitsigns (`git-signs.lua`)
- Auto-completion via nvim-cmp (`completions.lua`)
- Syntax highlighting via treesitter (`treesitter.lua`)
- Status line via lualine (`lualine.lua`)
- UI enhancements via noice and snacks (`noice.lua`, `snacks.lua`)
- Colorscheme: night-owl (`night-owl.lua`)
- Auto-pairs and commenting (`autopairs.lua`, `comment.lua`)

## Language Servers

Configured LSPs via Mason:
- lua_ls (Lua)
- ts_ls (TypeScript/JavaScript) — diagnostics intentionally disabled for JS files (not TS)
- html, cssls (Web)
- pylsp (Python)
- dartls (Dart/Flutter) — managed by flutter-tools, not Mason directly

## Formatters

Configured via none-ls:
- stylua (Lua)
- black (Python)
- prettier (JSON, JS/TS/JSX/TSX)

## File Locations

- All configuration lives in `~/.config/nvim/` (`/home/<user>` on Linux, `/Users/<user>` on macOS)
- Plugin configs are in `lua/plugins/[plugin-name].lua`
- Core Vim options are in `lua/vim-options.lua`

## Known Quirks

- **Treesitter**: highlight queries for `markdown` and `html` are disabled in `treesitter.lua` — intentional workaround for a nil-node crash on Neovim 0.12; do not remove.
- **LSP color preview**: inline color swatches are globally disabled via `vim.lsp.document_color.enable(false)` in `vim-options.lua`; do not re-enable for any LSP.
