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
- Rust development via rustaceanvim + crates.nvim (`rustaceanvim.lua`, `crates.lua`)
- File explorer via neo-tree (`neo-tree.lua`)
- Git integration via gitsigns (`git-signs.lua`)
- Auto-completion via nvim-cmp (`completions.lua`)
- Syntax highlighting via treesitter (`treesitter.lua`; plugin vendored at `vendor/nvim-treesitter/`)
- Status line via lualine (`lualine.lua`)
- UI enhancements via noice and snacks (`noice.lua`, `snacks.lua`)
- Colorscheme: night-owl (`night-owl.lua`)
- Auto-pairs and commenting (`autopairs.lua`, `comment.lua`)

## Language Servers

Configured LSPs via Mason:
- lua_ls (Lua)
- tsgo (TypeScript/JavaScript) — TypeScript 7 native LSP, replaces ts_ls. Launch command resolved per project by `lua/tsgo-cmd.lua`: project-local stable `tsc --lsp` (typescript >= 7) → project-local preview `tsgo` → Mason's global `tsgo` nightly. JS diagnostics are enabled (the old ts_ls per-buffer disable was intentionally dropped).
- html, cssls (Web)
- pylsp (Python)
- dartls (Dart/Flutter) — managed by flutter-tools, not Mason directly
- rust-analyzer (Rust) — managed by **rustaceanvim**, not Mason/lspconfig. Uses the rustup binary at `~/.cargo/bin/rust-analyzer`. Intentionally NOT added to `vim.lsp.enable({...})` in `lsp-config.lua` to avoid a duplicate LSP client.

## Formatters

Configured via none-ls:
- stylua (Lua)
- black (Python)
- prettier (JSON, JS/TS/JSX/TSX)
- rustfmt (Rust) — via rust-analyzer (not none-ls). Runs automatically on save for `.rs` files only (buffer-local `BufWritePre` autocmd in `rustaceanvim.lua`).

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
- **Vendored nvim-treesitter (in git)**: upstream archived 2026-04-03; Neovim 0.12 requires a `query_predicates.lua` patch (`match[id]` became a list `{ TSNode }`; an `unwrap_node` helper wraps all 6 read sites). Hand-patching lazy's clone gave each machine a different patch commit hash, so `lazy-lock.json` ping-ponged and `:Lazy restore` failed cross-machine. The patched tree now lives in the repo at `vendor/nvim-treesitter/`, loaded via a `dir =` spec in `lua/plugins/treesitter.lua` — lazy treats it as local: never fetched, never in `lazy-lock.json`. Compiled parsers (`vendor/nvim-treesitter/parser{,-info}/`) are gitignored (platform-specific) and rebuilt on demand by `auto_install`; `doc/tags` is force-added (the plugin's nested `.gitignore` excludes it, and lazy skips helptags for local plugins). Migration on a machine with the old setup: `git pull`, optionally copy `~/.local/share/nvim/lazy/nvim-treesitter/parser*` into `vendor/nvim-treesitter/` to skip recompiles, then `:Lazy clean` (the old clone's unpushed patch commit is safe to lose — the patch is in the vendored tree).
- **LSP color preview**: inline color swatches are globally disabled via `vim.lsp.document_color.enable(false)` in `vim-options.lua`; do not re-enable for any LSP.
- **`open_floating_preview` winhighlight patch**: Neovim 0.12's `vim.lsp.util.open_floating_preview` silently drops `winhighlight` from opts — it is a `vim.wo` option set post-creation, not an `nvim_open_win` config key. `vim-options.lua` wraps the function to apply `opts.winhighlight` to the window after creation. Do not remove this patch or the hover/diagnostic floats will lose their `LspFloatBorder` styling.
- **Rust toolchain components (NOT in git)**: rustaceanvim uses the rustup-managed `rust-analyzer`. The component must be installed: `rustup component add rust-analyzer`. If only the `~/.cargo/bin/rust-analyzer` proxy shim exists without the component, it errors with "Unknown binary 'rust-analyzer' in official toolchain" and the LSP silently fails to attach. Per-machine; not tracked in git.
- **Rust debugging (codelldb, NOT in git)**: Step debugging uses the `codelldb` adapter, installed via `:MasonInstall codelldb`. It is an external binary, not tracked in git, so it must be installed once per machine. rustaceanvim auto-detects it from Mason's path (`~/.local/share/nvim/mason/bin/codelldb`); no adapter config is needed.
- **Snacks terminal closes on any exit code**: The `<leader>t` terminal (`snacks.lua`) passes `auto_close = false` plus a custom `TermClose` handler (via `win.on_buf`) so the float closes whenever its shell process exits, regardless of status. Snacks' built-in `auto_close` deliberately keeps the float open on a non-zero exit (showing an error notification) — but a bare `exit` inherits the previous command's exit code, so quitting after a failed command would otherwise leave the float stuck on `[Process exited 1]`. Scoped to this one keymap via a per-call opts override (snacks' terminal identity keys only on `cmd`/`cwd`/`env`/`count`, so toggling still works); lazygit and direct-command terminals keep snacks' default "stay open on error" behavior.
- **TypeScript 7 LSP via tsgo (NOT in git)**: The TS LSP is Mason package `tsgo` (`:MasonInstall tsgo`), which installs the `@typescript/native-preview` nightly — stable `typescript@7` renamed the binary to `tsc` (it serves LSP via `tsc --lsp --stdio`), which is why projects with stable TS7 installed are served by their own `node_modules/.bin/tsc` instead (resolved in `lua/tsgo-cmd.lua`, tested by `nvim -l scripts/test-tsgo-cmd.lua`). Per-machine steps: install `tsgo` AND uninstall `typescript-language-server` — mason-lspconfig v2 auto-enables every installed server, so a lingering typescript-language-server attaches a duplicate ts_ls client alongside tsgo. Until tsgo is installed, TS/JS buffers outside a stable-TS7 project show an LSP spawn-error notification (a function-valued cmd skips Neovim's executable pre-check). Rollback: revert the two code commits and `:MasonInstall typescript-language-server`.
