# Rust Development Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this Neovim config into a full Rust development environment (LSP, inlay hints, clippy, format-on-save, run/test, step debugging, Cargo.toml management) for learning and professional use.

**Architecture:** A single new plugin (`rustaceanvim`) owns the rust-analyzer client and provides runnables/testables/debuggables; it reuses the existing `nvim-cmp`, `nvim-dap`/`dapui`, and treesitter infrastructure. A second small plugin (`crates.nvim`) handles `Cargo.toml`. No changes to the existing `vim.lsp.config`/`vim.lsp.enable` block — that avoids a duplicate LSP client.

**Tech Stack:** Lua, Lazy.nvim, rustaceanvim `^9`, rust-analyzer (rustup), clippy, rustfmt, codelldb (Mason), nvim-dap, nvim-cmp, crates.nvim.

## Global Constraints

- Target Neovim **0.12** (current on this machine).
- rustaceanvim pinned to **`version = "^9"`**.
- Use the **rustup** `rust-analyzer` (`~/.cargo/bin`), NOT Mason's — no version drift.
- **Never** add `rust_analyzer` to `vim.lsp.enable({...})` in `lsp-config.lua` — rustaceanvim owns the client; a second one causes duplicate diagnostics/hovers.
- Format-on-save is **Rust-only** (buffer-local autocmd on attach), must not affect other filetypes.
- All Rust/Cargo keymaps are **buffer-local** (`{ buffer = bufnr }`) — no global pollution.
- This repo has **no automated test harness** (zero test files by design). "Tests" here = concrete manual verification inside Neovim. That is the established pattern for this codebase.
- Commits: this config follows commit-when-asked. Each task ends with a commit step; confirm with the user before running it if executing interactively.

---

### Task 1: Core rustaceanvim — LSP, clippy, inlay hints

Stands up rust-analyzer via rustaceanvim with clippy-on-save and inlay type hints. After this task, opening a `.rs` file gives full LSP (hover, goto, completion, diagnostics) plus inferred-type hints.

**Files:**
- Create: `lua/plugins/rustaceanvim.lua`

**Interfaces:**
- Consumes: `require("cmp_nvim_lsp").default_capabilities()` (existing).
- Produces: a global `vim.g.rustaceanvim` table whose `server.on_attach(client, bufnr)` is extended by Tasks 2 and 3. Later tasks add lines *inside* this `on_attach` body.

- [ ] **Step 1: Create the plugin file**

Create `lua/plugins/rustaceanvim.lua`:

```lua
return {
  "mrcjkb/rustaceanvim",
  version = "^9",
  lazy = false, -- rustaceanvim implements its own lazy-loading
  dependencies = { "hrsh7th/cmp-nvim-lsp" },
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    vim.g.rustaceanvim = {
      server = {
        capabilities = capabilities,
        default_settings = {
          ["rust-analyzer"] = {
            -- Run clippy (not just `cargo check`) on save for idiomatic lints
            checkOnSave = true,
            check = { command = "clippy" },
            -- Inlay hints: rust-analyzer side (display is toggled in on_attach)
            inlayHints = { enable = true },
            cargo = { allFeatures = true },
          },
        },
        on_attach = function(client, bufnr)
          -- Inlay hints: show inferred types inline (great while learning Rust)
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

          -- Task 2 adds the format-on-save autocmd below this line.
          -- Task 3 (you) adds the buffer-local Rust keymaps below this line.
        end,
      },
      tools = {
        enable_clippy = true,
      },
      dap = {
        -- Auto-register nvim-dap launch configs when the LSP attaches.
        autoload_configurations = true,
      },
    }
  end,
}
```

- [ ] **Step 2: Install the plugin**

Run in Neovim: `:Lazy sync`
Expected: `rustaceanvim` (and `cmp-nvim-lsp` if not already) installs with no errors. `:Lazy` shows rustaceanvim loaded.

- [ ] **Step 3: Verify LSP attaches and hints render**

1. `cd` to a scratch crate (create one if needed: `cargo new /tmp/ra-smoke && nvim /tmp/ra-smoke/src/main.rs`).
2. Wait a few seconds for rust-analyzer to index.
3. Run `:checkhealth rustaceanvim` → Expected: rust-analyzer found, no errors.
4. Add `let x = 1 + 2;` inside `main`, then save and reopen — Expected: inlay hint shows `let x: i32` style annotation.
5. Press `K` on a symbol → Expected: hover doc float appears (uses your existing `K`/LSP).
6. Trigger completion (`<C-Space>`) after `x.` → Expected: method completions from rust-analyzer.

- [ ] **Step 4: Verify clippy runs on save**

Replace `main` with a snippet that trips a clippy-only lint (not a plain `cargo check` error):

```rust
fn main() {
    let v: Vec<i32> = Vec::new();
    if v.len() == 0 {
        println!("empty");
    }
}
```

Save the file. Expected: a clippy diagnostic appears on the `v.len() == 0` line (`clippy::len_zero` — "length comparison to zero; use `is_empty()`"). View it with `<leader>e`. This confirms clippy (not just `cargo check`) is wired in.

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/rustaceanvim.lua lazy-lock.json
git commit -m "feat(rust): add rustaceanvim with rust-analyzer, clippy, inlay hints"
```

---

### Task 2: Format-on-save (Rust-only)

Adds a buffer-local `BufWritePre` autocmd so saving a `.rs` file runs rustfmt (via rust-analyzer). Scoped to attached Rust buffers only.

**Files:**
- Modify: `lua/plugins/rustaceanvim.lua` (inside `server.on_attach`)

**Interfaces:**
- Consumes: the `bufnr` from `on_attach` (Task 1).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Add the format-on-save autocmd**

In `lua/plugins/rustaceanvim.lua`, inside `on_attach`, replace the line
`          -- Task 2 adds the format-on-save autocmd below this line.`
with:

```lua
          -- Format on save (Rust only). rust-analyzer drives rustfmt.
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format({ bufnr = bufnr })
            end,
          })
```

- [ ] **Step 2: Verify Rust formats on save**

1. Reopen the scratch crate's `src/main.rs`.
2. Type messy code: `fn main(){let x=1;println!("{}",x);}`
3. Save (`:w`).
Expected: buffer is reformatted to idiomatic multi-line rustfmt output (braces expanded, spaces inserted).

- [ ] **Step 3: Verify other filetypes are unaffected**

1. Open a Lua file in this config, e.g. `nvim lua/vim-options.lua`.
2. Add trailing whitespace / messy spacing on a line, save (`:w`).
Expected: NO automatic formatting (still manual via `<leader>gf`). Confirms the autocmd is Rust-scoped.

- [ ] **Step 4: Commit**

```bash
git add lua/plugins/rustaceanvim.lua
git commit -m "feat(rust): auto-format .rs on save via rust-analyzer"
```

---

### Task 3: Rust keymaps (you author this — learning task)

You write the buffer-local keymap block. This is deliberately yours: choosing bindings is a real muscle-memory decision, and writing it makes you learn what each `:RustLsp` action does. A complete reference block is provided — type it in, and adjust keys/desc to taste.

**Files:**
- Modify: `lua/plugins/rustaceanvim.lua` (inside `server.on_attach`)

**Interfaces:**
- Consumes: `bufnr` from `on_attach`; the `:RustLsp` user command provided by rustaceanvim.
- Produces: nothing new for later tasks.

**What each action does (so your choices are informed):**
- `runnables` — pick & run a binary/example/bench (cargo run targets).
- `testables` — pick & run tests, including the one under your cursor.
- `debuggables` — like runnables but launches under the debugger (needs Task 4).
- `expandMacro` — show what a macro invocation expands to.
- `explainError` — open the long-form explanation for the error on the line.
- `renderDiagnostic` — show the full rendered (cargo-style) diagnostic.
- `openCargo` — jump to the crate's `Cargo.toml`.
- `parentModule` — jump to the parent module.
- `hover actions` — richer hover that also offers actions.
- `codeAction` — rustaceanvim's grouped code-action picker.

- [ ] **Step 1: Write the keymap block**

In `lua/plugins/rustaceanvim.lua`, inside `on_attach`, replace the line
`          -- Task 3 (you) adds the buffer-local Rust keymaps below this line.`
with your block. Reference implementation (edit keys to taste):

```lua
          -- Buffer-local Rust keymaps (active only in .rs buffers).
          -- :RustLsp must be wrapped in a function so it fires on press.
          local function rust(cmd)
            return function() vim.cmd.RustLsp(cmd) end
          end
          local function map(lhs, cmd, desc)
            vim.keymap.set("n", lhs, rust(cmd), { buffer = bufnr, desc = desc })
          end

          -- Richer hover (overrides the global K for Rust buffers)
          vim.keymap.set("n", "K", function()
            vim.cmd.RustLsp({ "hover", "actions" })
          end, { buffer = bufnr, desc = "Rust: hover actions" })

          map("<leader>ca", "codeAction", "Rust: code action")
          map("<leader>rr", "runnables", "Rust: runnables")
          map("<leader>rt", "testables", "Rust: testables")
          map("<leader>rd", "debuggables", "Rust: debuggables")
          map("<leader>rm", "expandMacro", "Rust: expand macro")
          map("<leader>re", "explainError", "Rust: explain error")
          map("<leader>rD", "renderDiagnostic", "Rust: render diagnostic")
          map("<leader>rc", "openCargo", "Rust: open Cargo.toml")
          map("<leader>rp", "parentModule", "Rust: parent module")

          -- Toggle inlay hints on/off for this buffer
          vim.keymap.set("n", "<leader>ri", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
          end, { buffer = bufnr, desc = "Rust: toggle inlay hints" })
```

- [ ] **Step 2: Reload and verify a sampling of maps**

1. Restart Neovim, open the scratch crate's `src/main.rs`.
2. `<leader>rr` → Expected: a picker of runnable targets; selecting runs in a terminal split.
3. `<leader>ri` → Expected: inlay hints disappear; press again → they return.
4. `K` on a symbol → Expected: hover-with-actions float.
5. `<leader>rc` → Expected: jumps to `Cargo.toml`.

- [ ] **Step 3: Verify no global clash**

Open a non-Rust file (e.g. a Lua file). Press `<leader>rr`.
Expected: nothing Rust happens (the map is buffer-local to `.rs`). `<leader>rn` (global rename) still works everywhere.

- [ ] **Step 4: Commit**

```bash
git add lua/plugins/rustaceanvim.lua
git commit -m "feat(rust): add buffer-local RustLsp keymaps and inlay-hint toggle"
```

---

### Task 4: Step debugging (codelldb)

Installs the codelldb debug adapter and wires Rust debugging into your existing `nvim-dap` + `dapui`. rustaceanvim auto-detects codelldb from Mason's path; no adapter config needed.

**Files:**
- No file changes (Mason binary install). `dap.autoload_configurations = true` from Task 1 already enables it.

**Interfaces:**
- Consumes: existing `nvim-dap`/`dapui` and DAP keymaps (`<leader>dt|dc|do|dx`); `<leader>rd` (debuggables) from Task 3.
- Produces: nothing new.

- [ ] **Step 1: Install codelldb**

Run in Neovim: `:MasonInstall codelldb`
Expected: codelldb installs to `~/.local/share/nvim/mason/bin/`. Verify:

```bash
ls ~/.local/share/nvim/mason/bin/ | grep codelldb
```
Expected: `codelldb` listed.

- [ ] **Step 2: Verify adapter is detected**

Restart Neovim, open the scratch crate's `src/main.rs`, run `:checkhealth rustaceanvim`.
Expected: the debug adapter section reports codelldb found (no "adapter not found" warning).

- [ ] **Step 3: Verify a real debug session**

1. In `src/main.rs`, put a couple of statements in `main` and place the cursor on a line.
2. Set a breakpoint there: `<leader>dt`.
3. Run `<leader>rd` (debuggables) → select the binary target.
Expected: `dapui` opens (your existing config) and execution stops at the breakpoint; `<leader>do` steps over, `<leader>dc` continues, `<leader>dx` terminates and closes dapui.

- [ ] **Step 4: Commit**

codelldb is an external binary (not tracked in git), so there's nothing to commit here. Proceed to Task 5. (Its install is documented in Task 6.)

---

### Task 5: crates.nvim — Cargo.toml dependency management

Adds inline dependency-version display, update/upgrade actions, and crate-name/version completion in `Cargo.toml`.

**Files:**
- Create: `lua/plugins/crates.lua`
- Modify: `lua/plugins/completions.lua` (add `{ name = "crates" }` source)

**Interfaces:**
- Consumes: existing nvim-cmp setup in `completions.lua`.
- Produces: a `crates` cmp source (registered by crates.nvim when `completion.cmp.enabled = true`).

- [ ] **Step 1: Create the crates plugin file**

Create `lua/plugins/crates.lua`:

```lua
return {
  "saecki/crates.nvim",
  tag = "stable",
  event = { "BufRead Cargo.toml" },
  config = function()
    local crates = require("crates")
    crates.setup({
      completion = {
        cmp = { enabled = true },
      },
    })

    -- Buffer-local keymaps, only in Cargo.toml
    vim.api.nvim_create_autocmd("BufRead", {
      pattern = "Cargo.toml",
      callback = function(ev)
        local function map(lhs, fn, desc)
          vim.keymap.set("n", lhs, fn, { buffer = ev.buf, desc = desc })
        end
        map("<leader>cv", crates.show_versions_popup, "Crates: versions")
        map("<leader>cf", crates.show_features_popup, "Crates: features")
        map("<leader>cu", crates.update_crate, "Crates: update crate")
        map("<leader>cU", crates.upgrade_all_crates, "Crates: upgrade all")
      end,
    })
  end,
}
```

- [ ] **Step 2: Add the crates completion source**

In `lua/plugins/completions.lua`, the current sources block is:

```lua
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
				}, {
					{ name = "buffer" },
				}),
```

Change the first group to include crates:

```lua
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "crates" },
				}, {
					{ name = "buffer" },
				}),
```

(The `crates` source only yields results inside `Cargo.toml`, so it is inert elsewhere.)

- [ ] **Step 3: Install**

Run in Neovim: `:Lazy sync`
Expected: `crates.nvim` installs without errors.

- [ ] **Step 4: Verify**

1. Open the scratch crate's `Cargo.toml`: `nvim /tmp/ra-smoke/Cargo.toml`.
2. Under `[dependencies]`, add a line: `serde = "1"`.
3. Save, then reopen.
Expected: crates.nvim shows inline version info next to the dependency.
4. With cursor on the `serde` line, press `<leader>cv` → Expected: a popup listing available versions.
5. On a new dependency line, type a partial crate name and trigger completion (`<C-Space>`) → Expected: crate-name completions appear.

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/crates.lua lua/plugins/completions.lua lazy-lock.json
git commit -m "feat(rust): add crates.nvim for Cargo.toml management + cmp source"
```

---

### Task 6: Documentation

Records the Rust setup in `CLAUDE.md` (the repo's documentation home), including the one manual step (`:MasonInstall codelldb`) and the deliberate "rust-analyzer is not in vim.lsp.enable" decision — matching how the treesitter patch is already documented.

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:** none.

- [ ] **Step 1: Update the Language Servers section**

In `CLAUDE.md`, under `## Language Servers`, add a bullet after the `dartls` line:

```markdown
- rust-analyzer (Rust) — managed by **rustaceanvim**, not Mason/lspconfig. Uses
  the rustup binary at `~/.cargo/bin/rust-analyzer`. Intentionally NOT added to
  `vim.lsp.enable({...})` in `lsp-config.lua` to avoid a duplicate LSP client.
```

- [ ] **Step 2: Update the Formatters section**

Under `## Formatters`, add:

```markdown
- rustfmt (Rust) — via rust-analyzer (not none-ls). Runs automatically on save
  for `.rs` files only (buffer-local `BufWritePre` autocmd in `rustaceanvim.lua`).
```

- [ ] **Step 3: Add a Known Quirks entry for codelldb**

Under `## Known Quirks`, add:

```markdown
- **Rust debugging (codelldb, NOT in git)**: Step debugging uses the `codelldb`
  adapter, installed via `:MasonInstall codelldb`. It is an external binary, not
  tracked in git, so it must be installed once per machine. rustaceanvim
  auto-detects it from Mason's path (`~/.local/share/nvim/mason/bin/codelldb`);
  no adapter config is needed. If a fresh machine lacks debugging, run the
  Mason install.
```

- [ ] **Step 4: Verify**

Re-read the three additions in `CLAUDE.md`. Confirm: phrasing matches the file's existing terse style, and the codelldb note mirrors the existing "NOT in git" patch notes.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document Rust setup, codelldb manual install, and LSP-client decision"
```

---

## Final Verification (whole feature)

After all tasks, in a fresh `cargo new` project:
- [ ] rust-analyzer attaches; `K` shows types; inlay hints render; `<leader>ri` toggles them.
- [ ] Saving reformats (rustfmt); a clippy-flagged pattern shows a diagnostic.
- [ ] `<leader>rr` runs; `<leader>rt` runs the test under cursor.
- [ ] Breakpoint + `<leader>rd` → dapui stops at the breakpoint; stepping works.
- [ ] `Cargo.toml` shows inline versions; `<leader>cv` lists versions; crate-name completion works.
- [ ] `:checkhealth rustaceanvim` is green.
- [ ] A non-Rust buffer is unchanged (no auto-format, no Rust keymaps).
