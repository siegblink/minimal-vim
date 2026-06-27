# scripts/

Maintenance helpers for this Neovim config. **Not loaded by Neovim** — `init.lua`
only does `require("lazy").setup("plugins")`, which imports `lua/plugins/`, so files
in here are inert until you run them yourself.

---

## dump-keymaps.lua

Source-scans this config and lists/diffs the **custom** keymaps, so the
"Custom Keymaps" section of my command reference (`~/.commands/nvim-commands.md`)
can be regenerated or checked mechanically instead of by hand-reading every plugin
file after pulling changes across machines.

It reads the config **source files** (it does NOT load Neovim or plugins), so it is
fast and deterministic. It lists only keymaps defined here (no built-in Neovim
defaults as noise), groups them by source file = concern, and captures buffer-local
Rust / `Cargo.toml` maps without rust-analyzer having to attach.

Detects four idioms: `vim.keymap.set(...)`, lazy `keys = {}` specs, the custom
`map(lhs, …, desc)` helpers (rust/crates), and `["lhs"] =` tables (cmp / neo-tree).

### Print the full inventory (markdown)

Run from the repo root:

```bash
nvim -l scripts/dump-keymaps.lua             # to the terminal
nvim -l scripts/dump-keymaps.lua > keys.md   # to a file
nvim -l scripts/dump-keymaps.lua /other/cfg  # scan a different config dir
```

Output is grouped markdown, ready to paste under `## Custom Keymaps`.

### Diff config against the doc

```bash
nvim -l scripts/dump-keymaps.lua --check
# explicit paths:  --check <doc> <config-dir>
nvim -l scripts/dump-keymaps.lua --check ~/.commands/nvim-commands.md ~/.config/nvim
```

Prints **`++ ADDED`** (in config, missing from the doc — with description + group)
and **`-- STALE`** (in the doc, gone from config), then `✓ in sync` /
`✗ differences found`.

**Exit codes:** `0` in sync · `1` differences · `2` doc unreadable — so it can back a
git pre-commit hook or CI check.

### Typical workflow after pulling config changes

1. Pull the latest config.
2. `nvim -l scripts/dump-keymaps.lua --check`
3. Hand-edit only the ADDED / STALE entries in `~/.commands/nvim-commands.md` (the
   committed doc has hand-written prose nicer than the raw dump, so don't blindly
   replace the whole section).

### Notes

- **Comment.nvim defaults** (`gcc` / `gc` / `gb`) are plugin defaults, not detected;
  they live in a `DOC_ONLY` allowlist in the script so `--check` won't flag them as
  stale. Maintain those doc lines by hand.
- Maps in **new plugin files** still appear (unknown files get an auto-named group at
  the end), so nothing is silently dropped.
- Key matching is case-insensitive inside `<…>` (`<Leader>` == `<leader>`) but
  case-sensitive for suffix letters (`<leader>rD` ≠ `<leader>rd`, `<leader>dO` ≠ `<leader>do`).
