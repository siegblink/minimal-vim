# TypeScript 7 LSP Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `ts_ls` (typescript-language-server) with TypeScript 7's native LSP (`tsgo`), preferring each project's own stable `tsc --lsp` over Mason's nightly binary.

**Architecture:** A pure resolver module (`lua/tsgo-cmd.lua`) decides the launch argv for a given project root (local stable `tsc` ≥ 7 → local preview `tsgo` → global Mason `tsgo`). `lua/plugins/lsp-config.lua` wires it into nvim-lspconfig's stock `tsgo` server config via a `cmd` override; everything else (root detection, Deno avoidance, settings) is inherited from the stock config through `vim.lsp.config` merging.

**Tech Stack:** Neovim 0.12 Lua (`vim.lsp.config`/`vim.lsp.enable`, `vim.lsp.rpc.start`), nvim-lspconfig's bundled `lsp/tsgo.lua`, Mason registry package `tsgo`.

**Spec:** `docs/superpowers/specs/2026-07-09-typescript7-lsp-design.md`

## Global Constraints

- Neovim 0.12 on macOS (darwin); paths use `~/.local/share/nvim` for data and `~/.config/nvim` for config.
- No new plugins; `lazy-lock.json` must not change.
- mason-lspconfig is v2 with `automatic_enable = true` in effect: **every installed Mason LSP package is auto-enabled**. `typescript-language-server` must be uninstalled from Mason or it will attach alongside tsgo (duplicate clients).
- Lua formatting: stylua defaults (tabs). Format with `~/.local/share/nvim/mason/bin/stylua <files>` before committing.
- Commit style: conventional commits (`feat(lsp): ...`, `docs: ...`), each ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Verified upstream facts (do not re-derive): `typescript@7.0.2` ships only a `tsc` binary which serves LSP via `tsc --lsp --stdio`; `@typescript/native-preview` nightlies ship the same binary named `tsgo`; Mason package `tsgo` installs the nightly and maps to lspconfig name `tsgo`.

---

### Task 1: `tsgo-cmd` resolver module (TDD)

**Files:**
- Create: `lua/tsgo-cmd.lua`
- Create: `scripts/test-tsgo-cmd.lua` (test script, run with `nvim -l`)

**Interfaces:**
- Consumes: nothing (pure module; only `vim.fs`, `vim.fn`, `vim.json` stdlib).
- Produces: `require("tsgo-cmd").resolve(root_dir: string|nil) -> string[]` — returns the full argv to launch the TS7 LSP for that root, e.g. `{ "/root/node_modules/.bin/tsc", "--lsp", "--stdio" }`. Never errors; always returns an argv (final fallback is `{ "tsgo", "--lsp", "--stdio" }`).

- [ ] **Step 1: Write the failing test script**

Create `scripts/test-tsgo-cmd.lua` with exactly:

```lua
-- Tests for lua/tsgo-cmd.lua. Run: nvim -l scripts/test-tsgo-cmd.lua
vim.opt.rtp:prepend(vim.fn.stdpath("config"))

local ok_mod, tsgo_cmd = pcall(require, "tsgo-cmd")
if not ok_mod then
	print("FAIL: could not require tsgo-cmd: " .. tostring(tsgo_cmd))
	os.exit(1)
end

local failures = 0

local function check(name, got, want)
	local got_str = table.concat(got, " ")
	local want_str = table.concat(want, " ")
	if got_str == want_str then
		print("PASS: " .. name)
	else
		print(("FAIL: %s\n  want: %s\n  got:  %s"):format(name, want_str, got_str))
		failures = failures + 1
	end
end

-- Build a fixture project root with an optional typescript package.json
-- version and optional executable bins in node_modules/.bin.
local function fixture(opts)
	local root = vim.fn.tempname()
	vim.fn.mkdir(root .. "/node_modules/.bin", "p")
	if opts.ts_version then
		vim.fn.mkdir(root .. "/node_modules/typescript", "p")
		vim.fn.writefile(
			{ ('{"name":"typescript","version":"%s"}'):format(opts.ts_version) },
			root .. "/node_modules/typescript/package.json"
		)
	elseif opts.raw_package_json then
		vim.fn.mkdir(root .. "/node_modules/typescript", "p")
		vim.fn.writefile({ opts.raw_package_json }, root .. "/node_modules/typescript/package.json")
	end
	for _, bin in ipairs(opts.bins or {}) do
		local path = root .. "/node_modules/.bin/" .. bin
		vim.fn.writefile({ "#!/bin/sh", "exit 0" }, path)
		vim.fn.setfperm(path, "rwxr-xr-x")
	end
	return root
end

-- 1. Stable TS7 project: local tsc wins.
local r1 = fixture({ ts_version = "7.0.2", bins = { "tsc" } })
check("ts7 project uses local tsc", tsgo_cmd.resolve(r1), { r1 .. "/node_modules/.bin/tsc", "--lsp", "--stdio" })

-- 2. TS5 project (old JS shim tsc, no tsgo): global fallback.
local r2 = fixture({ ts_version = "5.9.3", bins = { "tsc" } })
check("ts5 project falls back to global tsgo", tsgo_cmd.resolve(r2), { "tsgo", "--lsp", "--stdio" })

-- 3. Preview package installed locally: local tsgo wins over global.
local r3 = fixture({ ts_version = "5.9.3", bins = { "tsc", "tsgo" } })
check("local preview tsgo preferred", tsgo_cmd.resolve(r3), { r3 .. "/node_modules/.bin/tsgo", "--lsp", "--stdio" })

-- 4. typescript v7 in package.json but no executable .bin/tsc: global fallback.
local r4 = fixture({ ts_version = "7.0.2", bins = {} })
check("v7 without executable tsc falls back", tsgo_cmd.resolve(r4), { "tsgo", "--lsp", "--stdio" })

-- 5. nil root: global fallback.
check("nil root uses global tsgo", tsgo_cmd.resolve(nil), { "tsgo", "--lsp", "--stdio" })

-- 6. Malformed package.json: falls through without erroring.
local r6 = fixture({ raw_package_json = "{ not json", bins = { "tsc" } })
check("malformed package.json falls back", tsgo_cmd.resolve(r6), { "tsgo", "--lsp", "--stdio" })

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all tests passed")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `nvim -l scripts/test-tsgo-cmd.lua`
Expected: `FAIL: could not require tsgo-cmd: module 'tsgo-cmd' not found...` and exit code 1 (check with `echo $?`).

- [ ] **Step 3: Write the module**

Create `lua/tsgo-cmd.lua` with exactly:

```lua
local M = {}

-- Launch-command resolution for the TypeScript 7 native LSP.
-- Preference order: the project's own stable compiler (typescript >= 7 ships
-- `tsc`, which serves LSP via `tsc --lsp --stdio`), then a project-local
-- preview install (`@typescript/native-preview` ships `tsgo`), then the
-- global `tsgo` from Mason's bin path.
---@param root_dir string|nil
---@return string[] argv
function M.resolve(root_dir)
	if root_dir then
		local local_tsc = vim.fs.joinpath(root_dir, "node_modules/.bin/tsc")
		local pkg_json = vim.fs.joinpath(root_dir, "node_modules/typescript/package.json")
		local ok, pkg = pcall(function()
			return vim.json.decode(table.concat(vim.fn.readfile(pkg_json), "\n"))
		end)
		local major = ok
				and type(pkg) == "table"
				and type(pkg.version) == "string"
				and tonumber(pkg.version:match("^(%d+)"))
			or nil
		if major and major >= 7 and vim.fn.executable(local_tsc) == 1 then
			return { local_tsc, "--lsp", "--stdio" }
		end

		local local_tsgo = vim.fs.joinpath(root_dir, "node_modules/.bin/tsgo")
		if vim.fn.executable(local_tsgo) == 1 then
			return { local_tsgo, "--lsp", "--stdio" }
		end
	end
	return { "tsgo", "--lsp", "--stdio" }
end

return M
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `nvim -l scripts/test-tsgo-cmd.lua && echo "exit: $?"`
Expected output ends with:

```
PASS: ts7 project uses local tsc
PASS: ts5 project falls back to global tsgo
PASS: local preview tsgo preferred
PASS: v7 without executable tsc falls back
PASS: nil root uses global tsgo
PASS: malformed package.json falls back
all tests passed
exit: 0
```

- [ ] **Step 5: Format and commit**

```bash
~/.local/share/nvim/mason/bin/stylua lua/tsgo-cmd.lua scripts/test-tsgo-cmd.lua
git add lua/tsgo-cmd.lua scripts/test-tsgo-cmd.lua
git commit -m "feat(lsp): add tsgo cmd resolver module with tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Switch lsp-config.lua from ts_ls to tsgo

**Files:**
- Modify: `lua/plugins/lsp-config.lua` (the `vim.lsp.config.ts_ls` block, currently lines 29–38, and the `vim.lsp.enable` list, currently line 47)
- Machine state (not git): Mason install `tsgo`, uninstall `typescript-language-server`

**Interfaces:**
- Consumes: `require("tsgo-cmd").resolve(root_dir: string|nil) -> string[]` from Task 1.
- Produces: LSP server `tsgo` enabled for `javascript`, `javascriptreact`, `typescript`, `typescriptreact` (filetypes/root_dir inherited from nvim-lspconfig's stock `lsp/tsgo.lua`). No `ts_ls` anywhere.

- [ ] **Step 1: Install the tsgo Mason package (headless)**

```bash
nvim --headless -c 'lua local reg = require("mason-registry"); reg.refresh(function() local pkg = reg.get_package("tsgo"); pkg:install():once("closed", function() vim.schedule(function() print(pkg:is_installed() and "tsgo: installed" or "tsgo: INSTALL FAILED"); vim.cmd.quitall() end) end) end)'
```

Expected: prints `tsgo: installed`. If this errors, run `:MasonInstall tsgo` interactively instead.

Verify the binary:

```bash
~/.local/share/nvim/mason/bin/tsgo --version
```

Expected: a `7.x.0-dev...` version string (native-preview nightly).

- [ ] **Step 2: Replace the ts_ls config block with tsgo**

In `lua/plugins/lsp-config.lua`, replace this block:

```lua
			vim.lsp.config.ts_ls = {
				capabilities = capabilities,
				on_attach = function(_, bufnr)
					local js_filetypes = { javascript = true, javascriptreact = true }

					if js_filetypes[vim.bo[bufnr].filetype] then
						vim.diagnostic.enable(false, { bufnr = bufnr })
					end
				end,
			}
```

with:

```lua
			vim.lsp.config.tsgo = {
				capabilities = capabilities,
				cmd = function(dispatchers, config)
					local argv = require("tsgo-cmd").resolve((config or {}).root_dir)
					return vim.lsp.rpc.start(argv, dispatchers)
				end,
			}
```

And replace the enable line:

```lua
			vim.lsp.enable({ "html", "cssls", "ts_ls", "lua_ls", "pylsp" })
```

with:

```lua
			vim.lsp.enable({ "html", "cssls", "tsgo", "lua_ls", "pylsp" })
```

Then confirm no stragglers: `grep -n ts_ls lua/plugins/lsp-config.lua` — expected: no output.

- [ ] **Step 3: Uninstall typescript-language-server from Mason**

Required, not optional: mason-lspconfig v2 auto-enables every installed LSP package, so a lingering install would attach `ts_ls` alongside `tsgo`.

```bash
nvim --headless -c 'lua require("mason-registry").get_package("typescript-language-server"):uninstall(); print("typescript-language-server: uninstalled")' -c 'qa'
ls ~/.local/share/nvim/mason/packages/
```

Expected: listing shows `tsgo` and no `typescript-language-server`.

- [ ] **Step 4: E2E — TS7 project uses its own tsc**

Create a test bed (use the session scratchpad; any temp dir works):

```bash
TESTBED="$(mktemp -d)/ts7-testbed" && mkdir -p "$TESTBED" && cd "$TESTBED" && npm init -y >/dev/null && npm i -D typescript@7 --silent && printf 'const n: number = "oops";\n' > index.ts && printf 'let 1bad = 2;\n' > bad.js && ls node_modules/.bin/
```

Expected: `tsc` in the bin listing and a `package-lock.json` in the dir (the stock root detection keys on lock files).

```bash
cd "$TESTBED" && nvim --headless index.ts -c 'lua vim.defer_fn(function() local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = 0 })); print("clients: " .. table.concat(names, ",")); print(vim.fn.system({ "pgrep", "-fl", "--", "--lsp --stdio" })); vim.cmd.quitall() end, 5000)'
```

Expected:
- `clients: tsgo` (exactly one client — proves ts_ls is gone)
- pgrep output contains `<testbed>/node_modules/.bin/tsc --lsp --stdio` (proves local-first resolution)

- [ ] **Step 5: E2E — loose file falls back to global tsgo**

```bash
echo 'const x: number = 1;' > "$(dirname "$TESTBED")/loose.ts" && cd "$(dirname "$TESTBED")" && nvim --headless loose.ts -c 'lua vim.defer_fn(function() local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = 0 })); print("clients: " .. table.concat(names, ",")); print(vim.fn.system({ "pgrep", "-fl", "--", "--lsp --stdio" })); vim.cmd.quitall() end, 5000)'
```

Expected: `clients: tsgo` and pgrep output showing the Mason binary (`.../mason/packages/tsgo/...` or bare `tsgo`) — not a `node_modules` path.

- [ ] **Step 6: E2E — JS files now get diagnostics**

```bash
cd "$TESTBED" && nvim --headless bad.js -c 'lua local ok = vim.wait(10000, function() return #vim.diagnostic.get(0) > 0 end, 200); print("js-diagnostics: " .. #vim.diagnostic.get(0)); vim.cmd.quitall()'
```

Expected: `js-diagnostics: <N>` with N ≥ 1 (the file's syntax error; under old ts_ls behavior this was suppressed).

- [ ] **Step 7: Regression — unit tests still pass, other LSPs unaffected**

```bash
nvim -l scripts/test-tsgo-cmd.lua
nvim --headless "+checkhealth vim.lsp" "+w! $TESTBED/lsp-health.txt" +qa; grep -iE "error|warn" "$TESTBED/lsp-health.txt" || echo "health: clean"
```

Expected: `all tests passed`; health output free of new errors (pre-existing warnings unrelated to tsgo are acceptable — compare against `git stash` state only if something looks off).

- [ ] **Step 8: Format and commit**

```bash
~/.local/share/nvim/mason/bin/stylua lua/plugins/lsp-config.lua
git add lua/plugins/lsp-config.lua
git commit -m "feat(lsp): switch TypeScript LSP from ts_ls to tsgo (TS7)

typescript-language-server wraps tsserver, which no longer exists in
TypeScript 7. Enable the native tsgo LSP instead, preferring the
project-local stable tsc (>= 7) via lua/tsgo-cmd.lua, falling back to a
local preview tsgo, then Mason's global nightly. JS diagnostics are now
enabled (the old per-buffer disable is intentionally dropped).

Requires per-machine: :MasonInstall tsgo, and uninstalling
typescript-language-server (mason-lspconfig v2 auto-enables installed
servers).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (Language Servers list; Known Quirks section)

**Interfaces:**
- Consumes: behavior established in Tasks 1–2 (documents it).
- Produces: nothing consumed by other tasks.

- [ ] **Step 1: Update the Language Servers list**

Replace the line:

```markdown
- ts_ls (TypeScript/JavaScript) — diagnostics intentionally disabled for JS files (not TS)
```

with:

```markdown
- tsgo (TypeScript/JavaScript) — TypeScript 7 native LSP, replaces ts_ls. Launch command resolved per project by `lua/tsgo-cmd.lua`: project-local stable `tsc --lsp` (typescript >= 7) → project-local preview `tsgo` → Mason's global `tsgo` nightly. JS diagnostics are enabled (the old ts_ls per-buffer disable was intentionally dropped).
```

- [ ] **Step 2: Add a Known Quirks entry**

Append this bullet to the `## Known Quirks` section:

```markdown
- **TypeScript 7 LSP via tsgo (NOT in git)**: The TS LSP is Mason package `tsgo` (`:MasonInstall tsgo`), which installs the `@typescript/native-preview` nightly — stable `typescript@7` renamed the binary to `tsc` (it serves LSP via `tsc --lsp --stdio`), which is why projects with stable TS7 installed are served by their own `node_modules/.bin/tsc` instead (resolved in `lua/tsgo-cmd.lua`, tested by `nvim -l scripts/test-tsgo-cmd.lua`). Per-machine steps: install `tsgo` AND uninstall `typescript-language-server` — mason-lspconfig v2 auto-enables every installed server, so a lingering typescript-language-server attaches a duplicate ts_ls client alongside tsgo.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document tsgo TS7 LSP migration in CLAUDE.md

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Final verification (after all tasks)

- [ ] `git log --oneline -5` shows the three task commits on top of the spec and plan commits.
- [ ] Interactive smoke test (user): open a real TS project, confirm hover/completion/diagnostics feel right and `:LspInfo` shows a single `tsgo` client.
