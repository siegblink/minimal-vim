-- Tests that Lua buffers format with exactly one formatter: none-ls stylua.
-- <leader>gf (none-ls.lua) is vim.lsp.buf.format(), which runs EVERY attached
-- client that can format, in client-start order, so a second formatter is not
-- a harmless duplicate but a race: whichever runs last decides the style.
-- Competing on Lua buffers: lua-language-server's built-in formatter
-- (EmmyLuaCodeStyle keeps 'single' quotes and one-line bodies) and the stylua
-- LSP server that mason-lspconfig auto-enables for the Mason stylua package.
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

-- Scratch project; .git is a lua_ls root marker, so it opens a workspace.
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/.git", "p")
dir = vim.uv.fs_realpath(dir)

local MESSY = {
	"local t = {a=1,b='x'}",
	"local function f(x) if x then return {1,2,3} end end",
	"return t",
}
-- stylua defaults (no stylua.toml): tabs, double quotes, spaced braces.
local STYLUA = {
	'local t = { a = 1, b = "x" }',
	"local function f(x)",
	"\tif x then",
	"\t\treturn { 1, 2, 3 }",
	"\tend",
	"end",
	"return t",
}

local file = dir .. "/messy.lua"
vim.fn.writefile(MESSY, file)
vim.cmd.edit(file)
local buf = vim.api.nvim_get_current_buf()
local attached = vim.wait(30000, function()
	local ls = vim.lsp.get_clients({ bufnr = buf, name = "lua_ls" })[1]
	return ls ~= nil and ls.initialized and #vim.lsp.get_clients({ bufnr = buf, name = "null-ls" }) > 0
end, 100)
check("lua_ls and none-ls attach to a Lua buffer", attached,
	"`:MasonInstall lua-language-server stylua`, then `:checkhealth vim.lsp`")
if not attached then
	finish()
end
-- mason-lspconfig enables servers from a scheduled callback; let late clients land.
vim.wait(2000, function() return false end)

check("the stylua LSP server is not enabled (mason-lspconfig automatic_enable)",
	not vim.lsp.is_enabled("stylua"),
	"lsp-config.lua: mason-lspconfig opts.automatic_enable = { exclude = { \"stylua\" } }")

-- Format the messy code with each formatting-capable client on its own: only
-- one of them may change it.
local function lines()
	return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end
local changed_by = {}
for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, method = "textDocument/formatting" })) do
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, MESSY)
	vim.lsp.buf.format({ bufnr = buf, id = client.id, timeout_ms = 10000 })
	if not vim.deep_equal(lines(), MESSY) then
		changed_by[#changed_by + 1] = client.name
	end
end
check("exactly one client formats Lua buffers (none-ls stylua)",
	#changed_by == 1 and changed_by[1] == "null-ls",
	"formatted by: " .. table.concat(changed_by, ", ")
		.. " (lua_ls: lsp-config.lua settings.Lua.format.enable = false)")

-- The real keymap, run against the same code.
local gf = vim.fn.maparg("<leader>gf", "n", false, true)
check("<leader>gf is mapped", gf.callback ~= nil)
if gf.callback then
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, MESSY)
	gf.callback()
	check("<leader>gf formats Lua with stylua", vim.deep_equal(lines(), STYLUA),
		"got: " .. vim.inspect(lines()))
end

vim.cmd("silent! bwipeout!")
vim.fn.delete(dir, "rf")
finish()
