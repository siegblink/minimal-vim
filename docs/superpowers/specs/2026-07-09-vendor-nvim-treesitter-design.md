# Vendored nvim-treesitter Design

**Date:** 2026-07-09
**Status:** Approved

## Background

nvim-treesitter (master) was archived 2026-04-03. Neovim 0.12 changed
`match[id]` in query predicates from a single `TSNode` to a list, so this
config depends on a hand-applied `unwrap_node` patch to the plugin's
`query_predicates.lua`. The patch is committed into the plugin's git clone on
each machine so lazy.nvim sees a clean tree.

Verified facts (checked 2026-07-09):

- Git commit hashes are content-addressed over author/date/parent, so the
  identical patch produces a **different hash on each machine**. The shared
  `lazy-lock.json` can never hold a commit valid everywhere: today's pull
  brought the other machine's hash (`85c77497`), `:Lazy restore` here failed
  with `not our ref`, and lazy rewrote the entry to this machine's hash
  (`76cb8b0a`), dirtying the repo. Every machine flips the entry back and
  forth (ping-pong).
- `pin = true` (present in the current spec) does **not** protect against
  restore: in lazy.nvim `manage/task/git.lua`, the lockfile target overrides
  the pin target. The pin only blocks `:Lazy update`.
- lazy.nvim skips git management entirely for local plugins
  (`M.checkout.skip` returns true when `plugin._.is_local`), and `dir =`
  plugins are excluded from `lazy-lock.json`.
- Plugin tree is 8.7MB without `.git` and parsers (mostly `queries/` text).
  Compiled parsers: 33 `.so` files, 17MB, platform-specific — must stay out
  of git (config is shared between Linux and macOS machines).
- Only references in the config: the plugin spec itself
  (`lua/plugins/treesitter.lua`) and a comment in `lua/vim-options.lua`. No
  other plugin declares nvim-treesitter as a dependency.

## Decisions

- **Vendor the patched tree into the config repo** (user): snapshot of the
  patched working tree (content of `76cb8b0a` = archived upstream HEAD
  `cf12346a` + `unwrap_node` patch) at `vendor/nvim-treesitter/`, no `.git`.
  The patch becomes reproducible on every machine via `git pull`; the plugin
  leaves lazy's git management and the lockfile for good.
- **Parsers stay in the plugin's own `parser/` dir, gitignored** (user):
  zero runtime behavior change. A new root `.gitignore` excludes
  `vendor/nvim-treesitter/parser/` and `parser-info/`. The 33 already-built
  parsers are copied over during migration so nothing recompiles here.
- **Drop `pin = true` and `build = ":TSUpdate"`**: pin is proven ineffective
  and meaningless for local plugins; build hooks only fire on install/update,
  which never happen for local plugins. `auto_install = true` keeps covering
  parser compilation.

## Changes

### New: `vendor/nvim-treesitter/` (committed)

Full working tree of the patched plugin minus `.git`; `parser/` and
`parser-info/` present on disk but gitignored. Includes the patched
`lua/nvim-treesitter/query_predicates.lua` (`unwrap_node` helper + 6 wrapped
read sites). During implementation, inspect the plugin's own nested
`.gitignore` — if it ignores anything beyond parser artifacts that we need
tracked, neutralize it; otherwise leave it as part of the snapshot.

### New: `.gitignore` (repo root)

```
vendor/nvim-treesitter/parser/
vendor/nvim-treesitter/parser-info/
```

### `lua/plugins/treesitter.lua`

Replace `"nvim-treesitter/nvim-treesitter"` + `pin` + `build` with
`dir = vim.fn.stdpath("config") .. "/vendor/nvim-treesitter"` and update the
explanatory comment. The `config` function is unchanged.

### `lazy-lock.json`

The nvim-treesitter entry disappears (rewritten by `:Lazy! clean`). This also
resolves the line dirtied by today's restore.

### `CLAUDE.md`

- Known Quirks: delete both obsolete `query_predicates.lua` patch bullets
  (the "(NOT in git)" one and the "(committed into plugin repo)" one).
  Add a single "vendored nvim-treesitter" bullet: why (archived upstream +
  per-machine patch hashes broke the lockfile), what (local `dir =` plugin at
  `vendor/`, excluded from `lazy-lock.json`), parsers gitignored and rebuilt
  by `auto_install`, and other-machine migration steps.
- Architecture note: mention treesitter now loads from `vendor/`.

### Migration — this machine (during implementation)

1. Copy the tree from `~/.local/share/nvim/lazy/nvim-treesitter/` to
   `vendor/nvim-treesitter/`, excluding `.git` (parsers come along and are
   simply gitignored).
2. Switch the spec to `dir =`.
3. Headless `:Lazy! clean` — removes the old managed clone and rewrites
   `lazy-lock.json` without the entry.
4. Helptags: keep `doc/tags` if the copy includes it; otherwise generate once.

### Migration — other machine (documented in CLAUDE.md)

1. `git pull` (vendored tree + spec arrive; lockfile already lacks the entry).
2. Optional: copy the old clone's `parser/*.so` and `parser-info/` into
   `vendor/nvim-treesitter/` to avoid recompiles (else `auto_install`
   rebuilds on demand).
3. `:Lazy clean` — deletes the old clone. Its unpushed local patch commit is
   safe to lose; the patch now lives in the vendored tree.

## Behavior changes

None at runtime: same plugin content, same config, same parser location
relative to the plugin dir. `:TSInstall`/`auto_install` keep writing into
`vendor/nvim-treesitter/parser/` (ignored). `:Lazy` shows the plugin as
local. `:h nvim-treesitter` keeps working via `doc/tags`.

## Out of scope

- Migrating to the rewritten nvim-treesitter `main` branch.
- Any highlight/indent configuration changes.
- Other plugins or lockfile policy changes.

## Verification plan

Headless `nvim` checks plus shell inspection:

1. Startup is clean; lazy resolves `nvim-treesitter` to the vendor dir
   (`require("lazy.core.config").plugins["nvim-treesitter"].dir`).
2. Open a `.lua` file: `vim.treesitter.highlighter.active[bufnr]` is set
   (highlighting works from the vendored copy).
3. Open a `.md` file: no active highlighter (Neovim 0.12 markdown quirk
   layers intact).
4. `grep unwrap_node vendor/nvim-treesitter/lua/nvim-treesitter/query_predicates.lua`
   confirms the patch shipped.
5. `lazy-lock.json` contains no `nvim-treesitter` key; `git status` shows
   only intended paths; old clone dir is gone.
6. `:h nvim-treesitter` resolves.
