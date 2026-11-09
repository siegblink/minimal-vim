-- Tests that each language formats with exactly one formatter, its none-ls
-- source: stylua (Lua), black (Python), prettier (TypeScript/JavaScript).
-- <leader>gf (none-ls.lua) is vim.lsp.buf.format(), which runs EVERY attached
-- client that can format, in client-start order, so a second formatter is not
-- a harmless duplicate but a race: whichever runs last decides the style. The
-- language servers bring their own (lua_ls's EmmyLuaCodeStyle, pylsp's
-- autopep8/yapf plugins, tsc's built-in one), and mason-lspconfig would
-- auto-enable a stylua LSP server for the Mason stylua package.
--
-- Run: nvim --headless -c 'luafile scripts/test-formatters.lua'
-- NOT `nvim -l`: that skips init.lua, so lazy never loads the plugins.
local failures = 0

-- io.stdout, not print(): headless print() output can lose its line breaks.
local function say(line)
	io.stdout:write(line .. "\n")
end

local function check(name, ok, hint)
	if ok then
		say("PASS: " .. name)
	else
		say("FAIL: " .. name .. (hint and ("\n      -> " .. hint) or ""))
		failures = failures + 1
	end
end

local function finish()
	if failures > 0 then
		say(failures .. " check(s) failed")
		os.exit(1)
	end
	say("all checks passed")
	os.exit(0)
end

if vim.tbl_isempty(vim.api.nvim_get_runtime_file("lsp/lua_ls.lua", false)) or not pcall(require, "null-ls") then
	say("FAIL: plugins not loaded (nvim-lspconfig / none-ls missing from the runtimepath).")
	say("      Run with: nvim --headless -c 'luafile scripts/test-formatters.lua'")
	os.exit(1)
end

-- Scratch project; .git is a root marker for all three servers.
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/.git", "p")
dir = vim.uv.fs_realpath(dir)

-- `want` is each formatter's default style (no config files in the project).
local CASES = {
	{
		file = "messy.lua",
		server = "lua_ls",
		install = "`:MasonInstall lua-language-server stylua`",
		messy = {
			"local t = {a=1,b='x'}",
			"local function f(x) if x then return {1,2,3} end end",
			"return t",
		},
		-- stylua: tabs, double quotes, spaced braces.
		want = {
			'local t = { a = 1, b = "x" }',
			"local function f(x)",
			"\tif x then",
			"\t\treturn { 1, 2, 3 }",
			"\tend",
			"end",
			"return t",
		},
	},
	{
		file = "messy.py",
		server = "pylsp",
		install = "`:MasonInstall python-lsp-server black`",
		messy = {
			"def f( a,b ):",
			"  return {'k':a,'v':b}",
		},
		-- black: double quotes, 4-space indent.
		want = {
			"def f(a, b):",
			'    return {"k": a, "v": b}',
		},
	},
	{
		file = "messy.ts",
		server = "tsc",
		install = "`:MasonInstall tsc prettier`",
		messy = {
			"const o = {a:1,b:'x'}",
			"function f(x:number){if(x){return [1,2,3]}}",
			"export { o, f }",
		},
		-- prettier: double quotes, semicolons, 2-space indent.
		want = {
			'const o = { a: 1, b: "x" };',
			"function f(x: number) {",
			"  if (x) {",
			"    return [1, 2, 3];",
			"  }",
			"}",
			"export { o, f };",
		},
	},
}

local gf = vim.fn.maparg("<leader>gf", "n", false, true)
check("<leader>gf is mapped", gf.callback ~= nil)

for _, case in ipairs(CASES) do
	local path = dir .. "/" .. case.file
	vim.fn.writefile(case.messy, path)
	vim.cmd.edit(path)
	local buf = vim.api.nvim_get_current_buf()
	local function lines()
		return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end
	local attached = vim.wait(30000, function()
		local server = vim.lsp.get_clients({ bufnr = buf, name = case.server })[1]
		return server ~= nil and server.initialized and #vim.lsp.get_clients({ bufnr = buf, name = "null-ls" }) > 0
	end, 100)
	check(("%s and none-ls attach to %s"):format(case.server, case.file), attached, case.install)
	if attached then
		-- mason-lspconfig enables servers from a scheduled callback; let late clients land.
		vim.wait(2000, function() return false end)

		-- Format the messy code with each formatting-capable client on its own:
		-- only none-ls may change it.
		local changed_by = {}
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, method = "textDocument/formatting" })) do
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, case.messy)
			vim.lsp.buf.format({ bufnr = buf, id = client.id, timeout_ms = 10000 })
			if not vim.deep_equal(lines(), case.messy) then
				changed_by[#changed_by + 1] = client.name
			end
		end
		check(("exactly one client formats %s (none-ls)"):format(case.file),
			#changed_by == 1 and changed_by[1] == "null-ls",
			("formatted by: %s (lsp-config.lua: on_init = no_formatting for %s)")
				:format(table.concat(changed_by, ", "), case.server))

		if gf.callback then
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, case.messy)
			gf.callback()
			check(("<leader>gf formats %s in the none-ls style"):format(case.file),
				vim.deep_equal(lines(), case.want), "got: " .. vim.inspect(lines()))
		end
	end
	vim.cmd("silent! bwipeout!")
end

check("the stylua LSP server is not enabled (mason-lspconfig automatic_enable)",
	not vim.lsp.is_enabled("stylua"),
	"lsp-config.lua: mason-lspconfig opts.automatic_enable = { exclude = { \"stylua\" } }")

vim.fn.delete(dir, "rf")
finish()
