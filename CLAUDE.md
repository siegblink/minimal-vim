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

- **Treesitter markdown (multi-layer fix)**: Neovim 0.12 introduced several treesitter crashes for markdown. Three layers of fix are in place — do not remove any of them:
  1. `treesitter.lua` — `highlight.disable = { "markdown", "markdown_inline" }` blocks nvim-treesitter from activating treesitter for markdown (also kept for `html`).
  2. `after/ftplugin/markdown.lua` — calls `vim.treesitter.stop()` to undo Neovim 0.12's new built-in `ftplugin/markdown.lua` which calls `vim.treesitter.start()` unconditionally, bypassing the nvim-treesitter disable list.
  3. `snacks.lua` — `scope.treesitter.enabled = false`, `indent.scope.treesitter.enabled = false`, and `quickfile.exclude = { "latex", "markdown" }` prevent snacks from activating treesitter on markdown via its own code paths.
- **Treesitter LSP hover fix**: `vim-options.lua` monkey-patches `vim.lsp.util.stylize_markdown` to call `vim.treesitter.stop(bufnr)` immediately after, preventing the hover buffer's markdown treesitter from triggering `query_predicates.lua` crashes. `noice.lua` has `lsp.hover.enabled = false` so the native hover handler (which respects this patch) is used instead of noice's.
- **`query_predicates.lua` patch (NOT in git)**: `nvim-treesitter` was archived on 2026-04-03 and will not be updated. Neovim 0.12 changed `match[id]` in query predicates/directives from a single `TSNode` to a list `{ TSNode }`. The file `~/.local/share/nvim/lazy/nvim-treesitter/lua/nvim-treesitter/query_predicates.lua` must be patched manually on each machine: add an `unwrap_node` helper after the `opts` line, then wrap all 6 `match[id]` read sites with `unwrap_node(...)`. See the project memory for details.
- **LSP color preview**: inline color swatches are globally disabled via `vim.lsp.document_color.enable(false)` in `vim-options.lua`; do not re-enable for any LSP.
- **`open_floating_preview` winhighlight patch**: Neovim 0.12's `vim.lsp.util.open_floating_preview` silently drops `winhighlight` from opts — it is a `vim.wo` option set post-creation, not an `nvim_open_win` config key. `vim-options.lua` wraps the function to apply `opts.winhighlight` to the window after creation. Do not remove this patch or the hover/diagnostic floats will lose their `LspFloatBorder` styling.
- **`query_predicates.lua` patch (committed into plugin repo)**: `nvim-treesitter` was archived on 2026-04-03. Neovim 0.12 changed `match[id]` from a single `TSNode` to a list `{ TSNode }`. The patch (adding `unwrap_node` and wrapping 6 call sites) is committed directly into `~/.local/share/nvim/lazy/nvim-treesitter/` as a local git commit so Lazy does not see a dirty working tree. On a fresh machine, re-apply the patch and commit it into the plugin repo again.
