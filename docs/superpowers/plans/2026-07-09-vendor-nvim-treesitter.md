# Vendored nvim-treesitter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the archived, hand-patched nvim-treesitter plugin out of lazy.nvim's git management by vendoring the patched tree into the config repo as a `dir =` local plugin.

**Architecture:** Snapshot the patched working tree (`~/.local/share/nvim/lazy/nvim-treesitter`, content of local commit `76cb8b0a`) into `vendor/nvim-treesitter/`, switch `lua/plugins/treesitter.lua` to a `dir =` spec (lazy then treats it as local: never fetched, never in `lazy-lock.json`), remove the old managed clone with `:Lazy! clean`, and update CLAUDE.md. Spec: `docs/superpowers/specs/2026-07-09-vendor-nvim-treesitter-design.md`.

**Tech Stack:** Neovim 0.12 headless checks, lazy.nvim, git, rsync.

## Global Constraints

- Config repo root: `/home/sieg/.config/nvim` (a git repo; run git commands there).
- Old managed clone: `~/.local/share/nvim/lazy/nvim-treesitter` (do NOT delete by hand; Task 3 removes it via `:Lazy! clean`).
- Never commit compiled parsers: no `.so` file may ever be staged. `vendor/nvim-treesitter/parser/` and `vendor/nvim-treesitter/parser-info/` stay gitignored.
- The `config = function()` body in `lua/plugins/treesitter.lua` must remain byte-identical (including the commented `ensure_installed` block).
- Use `vim.fn.stdpath("config")` for the vendor path (config is shared between Linux and macOS; never hardcode `/home/sieg`).
- This machine's `lazy-lock.json` is ALREADY dirty before Task 1 (its `nvim-treesitter` line was rewritten by an earlier `:Lazy restore`). Do not commit it before Task 3; Task 3 resolves it.
- Every commit message ends with exactly this trailer (explicit user preference — never any other model name):

  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  ```

---

### Task 1: Vendor the patched tree and gitignore parsers

**Files:**
- Create: `vendor/nvim-treesitter/` (full tree copy, ~8.7MB source + ~17MB ignored parsers)
- Create: `.gitignore` (repo root; the repo has none today)

**Interfaces:**
- Produces: `vendor/nvim-treesitter/` — the plugin tree Task 2's `dir =` spec points at. Contains the Neovim 0.12 patch in `lua/nvim-treesitter/query_predicates.lua` (an `unwrap_node` helper + 6 wrapped `match[id]` read sites) and prebuilt parsers in `parser/`.

- [ ] **Step 1: Copy the tree (everything except `.git`)**

```bash
mkdir -p ~/.config/nvim/vendor
rsync -a --exclude=.git ~/.local/share/nvim/lazy/nvim-treesitter/ ~/.config/nvim/vendor/nvim-treesitter/
```

- [ ] **Step 2: Verify the copy is faithful and carries the patch**

```bash
diff -r --exclude=.git ~/.local/share/nvim/lazy/nvim-treesitter ~/.config/nvim/vendor/nvim-treesitter && echo TREE_IDENTICAL
grep -c unwrap_node ~/.config/nvim/vendor/nvim-treesitter/lua/nvim-treesitter/query_predicates.lua
ls ~/.config/nvim/vendor/nvim-treesitter/parser/*.so | wc -l
ls -la ~/.config/nvim/vendor/nvim-treesitter/doc/tags
```

Expected: `TREE_IDENTICAL`; unwrap_node count ≥ 7 (1 helper + 6 call sites); 33 parsers; `doc/tags` exists (~3.2KB).

- [ ] **Step 3: Create the root `.gitignore`**

Write `/home/sieg/.config/nvim/.gitignore` with exactly:

```
vendor/nvim-treesitter/parser/
vendor/nvim-treesitter/parser-info/
```

- [ ] **Step 4: Verify ignore rules bite**

```bash
cd ~/.config/nvim
git check-ignore -v vendor/nvim-treesitter/parser/lua.so
git status --porcelain=v1 -uall -- vendor | grep -c '\.so$'
```

Expected: check-ignore prints a match against `.gitignore:1`; the grep count is `0`.

- [ ] **Step 5: Stage tree + gitignore; force-add `doc/tags`**

The plugin's own nested `.gitignore` (`vendor/nvim-treesitter/.gitignore`) ignores `doc/tags`, but we want it tracked: lazy.nvim's helptags step never runs for local plugins, so committing the tags file is what keeps `:h nvim-treesitter` working on every machine. Once force-added, ignore rules no longer apply to it.

```bash
cd ~/.config/nvim
git add .gitignore vendor/
git add -f vendor/nvim-treesitter/doc/tags
git diff --cached --name-only | grep -c '\.so$'
git diff --cached --name-only | grep -c 'parser-info'
git diff --cached --name-only | grep 'doc/tags'
git diff --cached --stat | tail -1
```

Expected: both grep counts `0`; `vendor/nvim-treesitter/doc/tags` listed; stat line shows ~1600 files changed (1592 counted at plan time; queries/ dominates), no `.so`.

- [ ] **Step 6: Commit**

```bash
cd ~/.config/nvim
git commit -m "feat(vendor): vendor patched nvim-treesitter tree

Snapshot of the archived plugin (upstream HEAD cf12346a) with the
Neovim 0.12 query_predicates.lua unwrap_node patch applied. Compiled
parsers are gitignored; doc/tags is force-added because the plugin's
nested .gitignore excludes it and lazy skips helptags for local plugins.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

Verify afterwards: `git status --short` shows only ` M lazy-lock.json` (pre-existing, see Global Constraints).

---

### Task 2: Point the plugin spec at the vendored tree

**Files:**
- Modify: `lua/plugins/treesitter.lua` (whole file, 24 lines)

**Interfaces:**
- Consumes: `vendor/nvim-treesitter/` from Task 1.
- Produces: lazy plugin named `nvim-treesitter` (name derives from the dir basename) with `_.is_local == true` — Task 3 relies on the old clone becoming unused.

- [ ] **Step 1: Replace the file contents**

Write `lua/plugins/treesitter.lua` to exactly (the `config` body is byte-identical to the current file — only the source line, the comment, and the dropped `pin`/`build` change):

```lua
return {
  -- Archived upstream 2026-04-03; vendored into the config repo with the
  -- Neovim 0.12 query_predicates.lua patch applied. As a dir= local plugin,
  -- lazy never fetches it and it stays out of lazy-lock.json (the per-machine
  -- patch commit hashes made the lockfile ping-pong between machines).
  dir = vim.fn.stdpath("config") .. "/vendor/nvim-treesitter",
  config = function()
    local config = require("nvim-treesitter.configs")
    config.setup({
      -- ensure_installed = {
      --   "lua",
      --   "html",
      --   "css",
      --   "javascript",
      --   "typescript",
      --   "json",
      --   "bash",
      -- },
      auto_install = true,
      highlight = { enable = true, disable = { "markdown", "markdown_inline", "html" } },
      indent = { enable = true },
    })
  end,
}
```

- [ ] **Step 2: Verify lazy resolves the plugin to the vendor dir as local**

```bash
nvim --headless "+lua local p = require('lazy.core.config').plugins['nvim-treesitter']; print('DIR:' .. p.dir); print('LOCAL:' .. tostring(p._.is_local))" +qa 2>&1
```

Expected output contains `DIR:/home/sieg/.config/nvim/vendor/nvim-treesitter` and `LOCAL:true`, and no error lines.

- [ ] **Step 3: Verify the vendored copy actually serves the runtime**

```bash
nvim --headless "+lua print('RTF:' .. (vim.api.nvim_get_runtime_file('lua/nvim-treesitter/query_predicates.lua', false)[1] or 'MISSING'))" +qa 2>&1
```

Expected: `RTF:/home/sieg/.config/nvim/vendor/nvim-treesitter/lua/nvim-treesitter/query_predicates.lua` (the vendor path, not `~/.local/share/nvim/lazy/...` — the old clone still exists until Task 3 but must no longer be on the runtimepath).

- [ ] **Step 4: Verify highlighting behavior (lua on, markdown off)**

```bash
cd ~/.config/nvim
nvim --headless init.lua "+lua vim.defer_fn(function() print('TS_LUA:' .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)) vim.cmd('qa!') end, 2000)" 2>&1
printf '# hi\n' > /tmp/claude-1000/-home-sieg--config-nvim/96764272-7d65-44ef-8c5e-fb7a28cf430a/scratchpad/ts-check.md
nvim --headless /tmp/claude-1000/-home-sieg--config-nvim/96764272-7d65-44ef-8c5e-fb7a28cf430a/scratchpad/ts-check.md "+lua vim.defer_fn(function() print('TS_MD:' .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)) vim.cmd('qa!') end, 2000)" 2>&1
```

Expected: `TS_LUA:true` and `TS_MD:false` (markdown must stay treesitter-free per the Neovim 0.12 quirk; `after/ftplugin/markdown.lua` calls `vim.treesitter.stop()`).

- [ ] **Step 5: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/treesitter.lua
git commit -m "feat(treesitter): load nvim-treesitter from vendored tree

dir= spec pointing at vendor/nvim-treesitter. pin (proven ineffective
against :Lazy restore) and build (never fires for local plugins) dropped;
auto_install still handles parser compilation.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Remove the old managed clone and its lockfile entry

**Files:**
- Modify: `lazy-lock.json` (entry removed by lazy itself, not by hand)

**Interfaces:**
- Consumes: the `dir =` spec from Task 2 (makes the old clone "unused" in lazy's eyes).
- Produces: `lazy-lock.json` without any `nvim-treesitter` key; `~/.local/share/nvim/lazy/nvim-treesitter` deleted.

- [ ] **Step 1: Confirm lazy considers exactly one plugin cleanable**

```bash
nvim --headless "+lua local out = {} for _, p in pairs(require('lazy.core.config').to_clean or {}) do table.insert(out, p.name) end print('CLEAN:' .. table.concat(out, ','))" +qa 2>&1
```

Expected: `CLEAN:nvim-treesitter` (only; `to_clean` is a real field — `lazy/core/config.lua:256` — populated at startup with on-disk plugins absent from the spec). STOP and investigate if any other plugin name appears here or in Step 2's output.

- [ ] **Step 2: Clean headlessly**

```bash
nvim --headless "+Lazy! clean" +qa 2>&1 | tr '\r' '\n' | grep -iv "^$" | tail -20
```

Expected: output references removing `nvim-treesitter` and no other plugin.

- [ ] **Step 3: Verify clone gone, lockfile entry gone, nothing else changed**

```bash
ls ~/.local/share/nvim/lazy/nvim-treesitter 2>&1
grep -c nvim-treesitter ~/.config/nvim/lazy-lock.json
cd ~/.config/nvim && git diff -- lazy-lock.json
```

Expected: `ls` errors with "No such file or directory"; grep count `0`; the diff removes exactly one line (the `"nvim-treesitter": ...` entry — this also resolves the pre-existing dirty line from today's `:Lazy restore`).

- [ ] **Step 4: Verify the editor still works without the old clone**

```bash
cd ~/.config/nvim
nvim --headless init.lua "+lua vim.defer_fn(function() print('TS_LUA:' .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)) vim.cmd('qa!') end, 2000)" 2>&1
```

Expected: `TS_LUA:true`, no error lines.

- [ ] **Step 5: Commit the lockfile**

```bash
cd ~/.config/nvim
git add lazy-lock.json
git commit -m "chore: drop nvim-treesitter from lazy-lock.json (vendored)

The plugin is now a dir= local plugin; lazy excludes local plugins from
the lockfile. Ends the cross-machine ping-pong of per-machine patch
commit hashes.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

Verify afterwards: `git status --short` is empty.

---

### Task 4: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (Key plugins list + Known Quirks)

**Interfaces:**
- Consumes: nothing from other tasks (documentation of the end state).

- [ ] **Step 1: Read `CLAUDE.md` and make three edits**

Edit 1 — in the "Key plugins configured" list, replace:

```
- Syntax highlighting via treesitter (`treesitter.lua`)
```

with:

```
- Syntax highlighting via treesitter (`treesitter.lua`; plugin vendored at `vendor/nvim-treesitter/`)
```

Edit 2 — in "Known Quirks", DELETE these two bullets entirely (match them by their bold headers; each is a single `- **...**:` list item):

- the bullet starting `- **\`query_predicates.lua\` patch (NOT in git)**:`
- the bullet starting `- **\`query_predicates.lua\` patch (committed into plugin repo)**:`

Edit 3 — in their place (same position in the list), insert this single bullet:

```
- **Vendored nvim-treesitter (in git)**: upstream archived 2026-04-03; Neovim 0.12 requires a `query_predicates.lua` patch (`match[id]` became a list `{ TSNode }`; an `unwrap_node` helper wraps all 6 read sites). Hand-patching lazy's clone gave each machine a different patch commit hash, so `lazy-lock.json` ping-ponged and `:Lazy restore` failed cross-machine. The patched tree now lives in the repo at `vendor/nvim-treesitter/`, loaded via a `dir =` spec in `lua/plugins/treesitter.lua` — lazy treats it as local: never fetched, never in `lazy-lock.json`. Compiled parsers (`vendor/nvim-treesitter/parser{,-info}/`) are gitignored (platform-specific) and rebuilt on demand by `auto_install`; `doc/tags` is force-added (the plugin's nested `.gitignore` excludes it, and lazy skips helptags for local plugins). Migration on a machine with the old setup: `git pull`, optionally copy `~/.local/share/nvim/lazy/nvim-treesitter/parser*` into `vendor/nvim-treesitter/` to skip recompiles, then `:Lazy clean` (the old clone's unpushed patch commit is safe to lose — the patch is in the vendored tree).
```

- [ ] **Step 2: Verify the edits**

```bash
cd ~/.config/nvim
grep -c "patch (NOT in git)\|committed into plugin repo" CLAUDE.md
grep -c "Vendored nvim-treesitter" CLAUDE.md
grep -c "vendor/nvim-treesitter" CLAUDE.md
```

Expected: `0` (both old bullet headers gone — don't grep for `query_predicates.lua` itself; the hover-fix bullet and the new bullet legitimately still mention it), `1`, and ≥ `3`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config/nvim
git add CLAUDE.md
git commit -m "docs: document vendored nvim-treesitter in CLAUDE.md

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Full verification sweep (spec checklist)

**Files:** none (read-only checks).

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Run the spec's verification list end-to-end**

```bash
cd ~/.config/nvim
nvim --headless "+lua local p = require('lazy.core.config').plugins['nvim-treesitter']; print('DIR:' .. p.dir)" +qa 2>&1
nvim --headless init.lua "+lua vim.defer_fn(function() print('TS_LUA:' .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)) vim.cmd('qa!') end, 2000)" 2>&1
printf '# hi\n' > /tmp/claude-1000/-home-sieg--config-nvim/96764272-7d65-44ef-8c5e-fb7a28cf430a/scratchpad/ts-check.md
nvim --headless /tmp/claude-1000/-home-sieg--config-nvim/96764272-7d65-44ef-8c5e-fb7a28cf430a/scratchpad/ts-check.md "+lua vim.defer_fn(function() print('TS_MD:' .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)) vim.cmd('qa!') end, 2000)" 2>&1
grep -c unwrap_node vendor/nvim-treesitter/lua/nvim-treesitter/query_predicates.lua
grep -c nvim-treesitter lazy-lock.json
ls ~/.local/share/nvim/lazy/nvim-treesitter 2>&1
nvim --headless "+silent help nvim-treesitter" "+lua print('HELP:' .. vim.fn.expand('%:p'))" +qa 2>&1
git status --short
```

Expected, in order: `DIR:` ends with `/vendor/nvim-treesitter`; `TS_LUA:true`; `TS_MD:false`; unwrap_node count ≥ 7; lockfile grep `0`; `ls` says No such file; `HELP:` path is under `vendor/nvim-treesitter/doc/`; `git status --short` empty.

- [ ] **Step 2: Confirm the four commits exist**

```bash
cd ~/.config/nvim && git log --oneline -5
```

Expected: the vendor, treesitter-spec, lockfile, and CLAUDE.md commits on top of `d71d970 docs(specs): add nvim-treesitter vendoring design`.
