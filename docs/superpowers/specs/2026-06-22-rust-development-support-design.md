# Rust Development Support — Design

**Date:** 2026-06-22
**Status:** Approved (ready for implementation plan)

## Goal

Make this Neovim config a first-class environment for Rust — usable for both
learning and professional work. Optimize for: understanding types while
learning (inlay hints, rich hover), and real-world ergonomics (clippy,
run/test under cursor, step debugging, dependency management).

## Context (existing environment)

- Toolchain installed via **rustup**: `cargo` 1.96, `rustc` 1.96, `rustfmt`,
  `clippy`, `rust-src`. NOTE: the `rust-analyzer` *proxy* was on PATH but the
  component itself was missing — installed during implementation via
  `rustup component add rust-analyzer`. We use the rustup binary, not Mason's.
- Missing only the **debug adapter** (`codelldb`).
- Config is modular: `lua/plugins/<name>.lua`, Lazy.nvim, new-style
  `vim.lsp.config`/`vim.lsp.enable` for existing LSPs, `nvim-cmp` completion,
  `nvim-dap` + `dapui` debugging, `none-ls` formatting, treesitter `auto_install`.

## Decisions

1. **Scope:** Full professional kit — LSP, inlay hints, completion,
   format-on-save, clippy, run/test, step debugging, Cargo.toml management.
2. **Approach:** `rustaceanvim` (`mrcjkb/rustaceanvim`, `version = '^9'`) — the
   maintained standard. It manages the rust-analyzer client itself and provides
   runnables/testables/debuggables/macro-expansion out of the box, rather than
   hand-rolling that glue on top of plain `nvim-lspconfig`.
3. **Formatting:** Auto-format on save, **Rust-only** (`BufWritePre *.rs`).
   Other languages keep their existing manual `<leader>gf`.

## Architecture / Components

| Action | File | Responsibility |
|---|---|---|
| New | `lua/plugins/rustaceanvim.lua` | Sets `vim.g.rustaceanvim`: server (rust-analyzer settings + on_attach keymaps + inlay hints), tools (clippy), dap (autoload). Owns the LSP client. |
| New | `lua/plugins/crates.lua` | `saecki/crates.nvim`, lazy on `Cargo.toml`. Inline dependency versions, update/upgrade actions, completion source. |
| Edit | `lua/plugins/completions.lua` | Add `{ name = "crates" }` to nvim-cmp sources (inert outside `Cargo.toml`). |
| One-time | `:MasonInstall codelldb` | Debug adapter binary; rustaceanvim auto-detects it from Mason's install path. |
| Untouched | `lsp-config.lua` | Must NOT add `rust_analyzer` to `vim.lsp.enable` (see Conflicts). |
| Untouched | `none-ls.lua` | Rust formats via rust-analyzer→rustfmt; a second formatter would be redundant. |

Each unit has one clear purpose and communicates through existing interfaces
(cmp source list, dap config list, LSP attach). They can be reasoned about and
tested independently.

## Data Flow

- Open `.rs` → rustaceanvim (filetype plugin) auto-attaches rust-analyzer
  (rustup binary) → existing `nvim-cmp` `nvim_lsp` source + existing
  `K`/`<leader>gd|gr|ca|rn|e` keymaps work, plus Rust-only `:RustLsp` actions.
- Save `.rs` → clippy (`check.command = "clippy"`) → diagnostics via existing
  `<leader>e` float; `BufWritePre` autocmd runs `vim.lsp.buf.format` (rustfmt).
- `:RustLsp debuggables` → rustaceanvim reads `cargo metadata`, builds a
  codelldb launch config, hands it to existing `nvim-dap` + `dapui`; existing
  `<leader>dt|dc|do|dx` drive stepping.
- Open `Cargo.toml` → crates.nvim → inline versions + `<leader>c*` actions +
  crate/version completion.

## Behavior Details

- **Inlay type hints: ON.** rust-analyzer `inlayHints.enable = true`, displayed
  via `vim.lsp.inlay_hint.enable(true, { bufnr })` in `on_attach`. Toggle keymap
  provided to mute when noisy.
- **Clippy on save: ON.** `tools.enable_clippy = true` +
  `default_settings['rust-analyzer'].check.command = "clippy"`, `checkOnSave = true`.
- **Format on save: Rust-only** (decision 3).
- **Keymaps: buffer-local in `.rs`** (and `Cargo.toml` for crates) so they never
  pollute global space. The full keymap block in `rustaceanvim.lua`'s `on_attach`
  is authored by the user during implementation (a deliberate learning task — it
  requires knowing what each `:RustLsp` action does).

  Proposed default set (user finalizes):

  | Key | Action |
  |---|---|
  | `K` | `:RustLsp hover actions` (override; richer hover) |
  | `<leader>ca` | `:RustLsp codeAction` (grouped; rust-buffer override) |
  | `<leader>rr` | `:RustLsp runnables` |
  | `<leader>rt` | `:RustLsp testables` |
  | `<leader>rd` | `:RustLsp debuggables` |
  | `<leader>rm` | `:RustLsp expandMacro` |
  | `<leader>re` | `:RustLsp explainError` |
  | `<leader>rD` | `:RustLsp renderDiagnostic` (full diagnostic on line) |
  | `<leader>rc` | `:RustLsp openCargo` |
  | `<leader>rp` | `:RustLsp parentModule` |
  | `<leader>ri` | toggle inlay hints |

  crates.nvim (buffer-local in `Cargo.toml`): `<leader>cu` update crate,
  `<leader>cU` upgrade all, `<leader>cv` versions popup, `<leader>cf` features.

## Conflicts Handled

- **Double LSP client:** rustaceanvim owns rust-analyzer. We keep `rust_analyzer`
  out of `vim.lsp.enable({...})`; `mason-lspconfig`'s `auto_install` won't pull it
  because it's never configured through lspconfig. → single client, no duplicate
  diagnostics/hovers.
- **Version drift:** use rustup's rust-analyzer (toolchain-locked), not Mason's.
- **Treesitter:** the existing markdown-crash patches are unrelated to Rust; the
  rust parser is stable and auto-installs on first `.rs` open.

## One-Time Setup Steps

1. `:Lazy sync` (installs rustaceanvim + crates.nvim).
2. `:MasonInstall codelldb` (debug adapter). Note: not auto-reproduced on new
   machines — documented in README/CLAUDE.md as a manual step (same philosophy
   as the existing treesitter patch note).

## Verification

In a scratch `cargo new` project:
- Hover (`K`) shows types; inlay hints render inferred types.
- `<leader>rr` runs the binary; `<leader>rt` runs the test under cursor.
- Breakpoint (`<leader>dt`) + `<leader>rd` debuggables → dapui opens, stepping works.
- Introduce a clippy-flagged pattern, save → diagnostic appears.
- Save reformats via rustfmt.
- Open `Cargo.toml` → versions shown inline; crate-name completion works.
- `:checkhealth rustaceanvim` is green.

## Out of Scope (YAGNI)

- neotest integration (test_executor stays default).
- cargo-nextest config (auto-detected if present, no extra wiring).
- Cross-compilation / `cargo_override`.
- Reproducible codelldb install automation (mason-tool-installer) — documented
  manual step instead.
