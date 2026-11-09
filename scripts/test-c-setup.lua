-- Tests for the C/C++ setup: clangd (lsp-config.lua) with its fallback
-- warnings, formatting and inlay hints; .h detection (vim-options.lua); the
-- keymaps in after/ftplugin/c.lua; the printf injection (treesitter.lua);
-- Tab/S-Tab placeholder jumps (completions.lua); and the codelldb adapter +
-- launch config (debugging.lua).
--
-- Run: nvim --headless -c 'luafile scripts/test-c-setup.lua'
-- Add a live debug session (compiles a program, stops at a breakpoint):
--   C_TEST_DEBUG=1 nvim --headless -c 'luafile scripts/test-c-setup.lua'
-- The live session is opt-in because on macOS the first debugger launch of a
-- login session shows a "Developer Tools Access" password prompt.
--
-- NOT `nvim -l`: that skips init.lua, so lazy never loads the plugins. Every
-- FAIL line says what to install or fix on this machine.
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

local has_dap, dap = pcall(require, "dap")
if not has_dap or vim.tbl_isempty(vim.api.nvim_get_runtime_file("lsp/clangd.lua", false)) then
	say("FAIL: plugins not loaded (nvim-dap / nvim-lspconfig missing from the runtimepath).")
	say("      Run with: nvim --headless -c 'luafile scripts/test-c-setup.lua'")
	os.exit(1)
end

-- Scratch projects. realpath: macOS temp dirs sit behind a /var -> /private/var
-- symlink, and clangd answers with resolved paths.
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
dir = vim.uv.fs_realpath(dir)

local function write(name, lines)
	local path = dir .. "/" .. name
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile(lines, path)
	return path
end

-- single/: one file, no project files, so clangd uses fallbackFlags.
local main_c = write("single/main.c", {
	"#include <stdio.h>",
	"#include <string.h>",
	"",
	"int add(int a,int b){return a+b;}",
	"",
	"int main(void) {",
	"  int unused;",
	"  char buf[8];",
	"  memset(buf, 0, sizeof buf);",
	'  printf("%d %s\\n", add(1, 2), buf);',
	"  return 0;",
	"}",
})
-- proj/: a source/header pair plus the compile_flags.txt C projects need.
-- util.h is valid C but invalid C++ (implicit void * conversion), so a header
-- parsed as C++ shows an error.
write("proj/compile_flags.txt", { "-Wall", "-Wextra" })
local util_h = write("proj/util.h", {
	"#include <stdlib.h>",
	"",
	"static inline int *make_int(void) {",
	"  int *p = malloc(sizeof *p);",
	"  return p;",
	"}",
})
local util_c = write("proj/util.c", {
	'#include "util.h"',
	"",
	"int use(void) {",
	"  int *p = make_int();",
	"  int ok = p != NULL;",
	"  free(p);",
	"  return ok;",
	"}",
})

-- .h detection -------------------------------------------------------------
check(".h files are detected as C (vim.g.c_syntax_for_h)",
	vim.filetype.match({ filename = util_h }) == "c",
	"vim-options.lua must set vim.g.c_syntax_for_h before any buffer is opened")

-- Treesitter ---------------------------------------------------------------
vim.cmd.edit(main_c)
local buf = vim.api.nvim_get_current_buf()
check("main.c has filetype c", vim.bo[buf].filetype == "c")
check("treesitter highlighting is active in C buffers",
	vim.treesitter.highlighter.active[buf] ~= nil,
	"`:TSInstall c`, then check `:checkhealth nvim-treesitter`")

-- ensure_installed runs async at startup; on the first launch after a pull it
-- may still be compiling, so give it time (it needs cc and network once).
local function parser_loads(lang)
	return vim.treesitter.language.add(lang) == true
end
local printf_ready = vim.wait(120000, function() return parser_loads("printf") end, 250)
check("printf parser is installed (treesitter ensure_installed)", printf_ready,
	"`:TSInstall printf` (needs a C compiler: `cc --version`)")
if printf_ready then
	-- Fresh buffer: one parsed before the install finished keeps no printf child.
	local scratch = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { 'void f(void) { printf("%d\\n", 1); }' })
	local parser = vim.treesitter.get_parser(scratch, "c")
	parser:parse(true)
	check("printf format strings in C get the printf injection",
		parser:children().printf ~= nil)
	vim.api.nvim_buf_delete(scratch, { force = true })
end
check("doxygen parser is installed (treesitter ensure_installed)",
	vim.wait(60000, function() return parser_loads("doxygen") end, 250),
	"`:TSInstall doxygen`")

-- Keymaps (after/ftplugin/c.lua) ---------------------------------------------
local function bufmap(lhs)
	local m = vim.fn.maparg(lhs, "n", false, true)
	return (m.buffer == 1 and m.callback) and m or nil
end
local C_MAPS = { "<leader>cm", "<leader>ch", "<leader>ci" }
for _, lhs in ipairs(C_MAPS) do
	check(("%s is mapped buffer-locally in C buffers"):format(lhs), bufmap(lhs) ~= nil)
end

-- Leaving the filetype runs b:undo_ftplugin, which must remove every map. For
-- C++, cpp.vim sources c.lua and then appends ' | setl commentstring<', and a
-- map command reads the space before a '|' as part of its {lhs}
-- (:help map-trailing-white), so a bare `nunmap` there silently misses.
-- `doautocmd filetypeplugin` runs just the real ftplugin chain: the full
-- FileType event would also start treesitter's auto_install (C++ parser).
local function c_maps_here()
	return vim.tbl_filter(function(lhs) return bufmap(lhs) ~= nil end, C_MAPS)
end
for _, ft in ipairs({ "c", "cpp" }) do
	local scratch = vim.api.nvim_create_buf(false, true)
	local entered, left
	vim.api.nvim_buf_call(scratch, function()
		vim.cmd("doautocmd <nomodeline> filetypeplugin FileType " .. ft)
		entered = c_maps_here()
		vim.cmd("doautocmd <nomodeline> filetypeplugin FileType text")
		left = c_maps_here()
	end)
	vim.api.nvim_buf_delete(scratch, { force = true })
	check(("leaving %s removes the C maps (b:undo_ftplugin)"):format(ft),
		#entered == #C_MAPS and #left == 0,
		("mapped on entering: %s; still mapped after leaving: %s (after/ftplugin/c.lua)")
			:format(table.concat(entered, " "), table.concat(left, " ")))
end

-- <leader>cm on `printf` must open the C library page, not the shell command's.
if bufmap("<leader>cm") then
	vim.fn.cursor(10, 3) -- the printf call
	bufmap("<leader>cm").callback()
	local name = vim.api.nvim_buf_get_name(0)
	check("<leader>cm on printf opens man://printf(3)", name == "man://printf(3)",
		("opened %q. Debian/Ubuntu: `sudo apt install man-db manpages-dev`"
			.. " (on a minimized install, `sudo unminimize` first)"):format(name))
	if vim.bo.filetype == "man" then
		vim.cmd.close()
	end
	vim.cmd.buffer(buf)
end

-- clangd ---------------------------------------------------------------------
local clangd = vim.fn.exepath("clangd")
local INSTALL_CLANGD = "macOS / Linux x86-64: `:MasonInstall clangd`;"
	.. " Linux arm64 (no Mason build): `sudo apt install clangd`"
check("clangd is on $PATH", clangd ~= "", INSTALL_CLANGD)

local function clangd_clients(b)
	return vim.lsp.get_clients({ bufnr = b, name = "clangd" })
end

-- A clean file publishes an EMPTY diagnostic list, so "no diagnostics yet"
-- can't tell "not analysed" from "analysed, clean". DiagnosticChanged fires
-- either way.
local diagnosed = {}
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function(ev)
		diagnosed[ev.buf] = true
	end,
})

if clangd ~= "" then
	say("      using " .. clangd .. " (" .. vim.trim(vim.fn.system({ clangd, "--version" })):match("[^\n]+") .. ")")
	local attached = vim.wait(30000, function() return #clangd_clients(buf) > 0 end, 100)
	check("clangd attaches to a C file with no project files around it", attached,
		"`:checkhealth vim.lsp`; is clangd in vim.lsp.enable() in lsp-config.lua?")
	check("exactly one clangd client (no duplicate from mason-lspconfig)", #clangd_clients(buf) == 1)

	if attached then
		local diags = function()
			return vim.diagnostic.get(buf)
		end
		local function unused_warning()
			for _, d in ipairs(diags()) do
				if d.code == "-Wunused-variable" or (d.message or ""):find("[Uu]nused variable") then
					return true
				end
			end
		end
		vim.wait(30000, unused_warning, 100)
		check("fallbackFlags -Wall -Wextra apply (unused-variable warning shown)", unused_warning(),
			"lsp-config.lua: vim.lsp.config.clangd.init_options.fallbackFlags")

		local errors = vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
		check("system headers resolve (no errors in main.c)", #errors == 0,
			(errors[1] and errors[1].message or "") .. ". Linux: `sudo apt install build-essential`")

		check("inlay hints are enabled for clangd buffers",
			vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
		check("clangd returns parameter inlay hints",
			vim.wait(15000, function() return #vim.lsp.inlay_hint.get({ bufnr = buf }) > 0 end, 100))

		local ci = bufmap("<leader>ci")
		if ci then
			ci.callback()
			local off = not vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
			ci.callback()
			check("<leader>ci toggles inlay hints off and back on",
				off and vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
		end

		-- Formatting: clangd must be the only formatter, and use LLVM style when
		-- no .clang-format exists.
		local fmt = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/formatting" })
		check("clangd is the only formatter for C buffers",
			#fmt == 1 and fmt[1].name == "clangd",
			("formatters: %s"):format(table.concat(vim.tbl_map(function(c) return c.name end, fmt), ", ")))
		vim.lsp.buf.format({ bufnr = buf, timeout_ms = 10000 })
		check("<leader>gf formats C with clang-format (LLVM fallback style)",
			vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1] == "int add(int a, int b) { return a + b; }",
			"line 4 is now: " .. tostring(vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]))
		vim.cmd("silent! write")

		-- <leader>ch: util.c -> util.h, then the header must parse as C.
		vim.cmd.edit(util_c)
		local cbuf = vim.api.nvim_get_current_buf()
		vim.wait(30000, function()
			return #clangd_clients(cbuf) > 0 and vim.fn.exists(":LspClangdSwitchSourceHeader") == 2
		end, 100)
		bufmap("<leader>ch").callback()
		local switched = vim.wait(15000, function()
			return vim.api.nvim_buf_get_name(0):sub(-7) == "/util.h"
		end, 100)
		check("<leader>ch switches util.c to util.h", switched)
		if switched then
			local hbuf = vim.api.nvim_get_current_buf()
			check("util.h opens with filetype c", vim.bo[hbuf].filetype == "c")
			local analysed = vim.wait(30000, function() return diagnosed[hbuf] == true end, 100)
			local herrs = vim.diagnostic.get(hbuf, { severity = vim.diagnostic.severity.ERROR })
			check("with compile_flags.txt, clangd parses .h headers as C (no C++ void* error)",
				analysed and #herrs == 0,
				analysed and herrs[1] and herrs[1].message or "clangd never published diagnostics for util.h")
		end
	end
end

-- Snippet placeholders: <Tab> / <S-Tab> (completions.lua) --------------------
-- Real keystrokes: a child nvim in a pty expands a two-argument snippet (what
-- clangd sends when you accept a function), fills it using Tab and S-Tab, then
-- presses Tab outside the snippet, where it must stay a plain Tab.
do
	local file = write("jump/t.txt", { "" })
	local expand = [[<Cmd>lua require('luasnip').lsp_expand('copy(${1:dst}, ${2:src})')<CR>]]
	local screen = ""
	local job = vim.fn.jobstart({ vim.v.progpath, "-i", "NONE", "-c", "inoremap <C-]> " .. expand, file }, {
		pty = true,
		width = 100,
		height = 30,
		env = { TERM = "xterm-256color" },
		on_stdout = function(_, data)
			screen = screen .. table.concat(data, "")
		end,
	})
	local function send(keys)
		vim.fn.chansend(job, keys)
		vim.wait(300, function() return false end)
	end
	vim.wait(15000, function() return screen:find("t.txt", 1, true) ~= nil end, 100)
	vim.wait(1000, function() return false end)
	send("i")
	send("\29") -- <C-]>: expand, "dst" is selected
	send("buf")
	send("\t") -- next placeholder: "src"
	send("name")
	send("\t") -- end of the snippet
	send(";")
	send("\t") -- outside the snippet: a plain Tab (2 spaces)
	send("X")
	send("\27") -- <Esc>
	send("o")
	send("\29")
	send("A")
	send("\t")
	send("B")
	send("\27[Z") -- <S-Tab>: back to the first placeholder
	send("Z")
	send("\27")
	send(":wq\r")
	if vim.fn.jobwait({ job }, 10000)[1] == -1 then
		vim.fn.jobstop(job)
	end
	local got = vim.fn.readfile(dir .. "/jump/t.txt")
	check("<Tab>/<S-Tab> jump between snippet placeholders, plain Tab elsewhere",
		got[1] == "copy(buf, name);  X" and got[2] == "copy(Z, B)",
		"got: " .. vim.inspect(got) .. " (completions.lua <Tab>/<S-Tab> mappings)")
end

-- DAP: codelldb adapter + C launch config -----------------------------------
local adapter = dap.adapters.codelldb
check("dap.adapters.codelldb is a codelldb server adapter",
	type(adapter) == "table" and adapter.type == "server" and adapter.port == "${port}"
		and adapter.executable and adapter.executable.command == "codelldb"
		and vim.deep_equal(adapter.executable.args, { "--port", "${port}" }))

local cfg = (dap.configurations.c or {})[1]
check("dap.configurations.c launches through codelldb",
	cfg ~= nil and cfg.type == "codelldb" and cfg.request == "launch" and cfg.terminal == "integrated")
check("C++ shares the C launch config", dap.configurations.cpp == dap.configurations.c)

if cfg then
	local real_input = vim.fn.input
	vim.fn.input = function() return "/tmp/prog" end
	local program = cfg.program()
	vim.fn.input = function() return "" end
	local aborted = cfg.program() == dap.ABORT
	vim.fn.input = function() return [[-n 3 "two words"]] end
	local args = cfg.args()
	vim.fn.input = real_input
	check("launch prompt returns the typed executable path", program == "/tmp/prog")
	check("an empty executable prompt aborts the launch", aborted)
	check("launch arguments are shell-split", vim.deep_equal(args, { "-n", "3", "two words" }))
end

local codelldb = vim.fn.exepath("codelldb")
check("codelldb is on $PATH", codelldb ~= "", "`:MasonInstall codelldb`")

-- Start the adapter and complete a DAP `initialize` handshake. Proves the
-- binary runs on this OS/arch without debugging any process.
if codelldb ~= "" then
	local probe = vim.uv.new_tcp()
	probe:bind("127.0.0.1", 0)
	local port = probe:getsockname().port
	probe:close()

	local proc
	proc = vim.uv.spawn(codelldb, { args = { "--port", tostring(port) } }, function()
		if proc and not proc:is_closing() then
			proc:close()
		end
	end)

	local reply, sock = "", nil
	local deadline = vim.uv.now() + 20000
	local function connect()
		sock = vim.uv.new_tcp()
		sock:connect("127.0.0.1", port, function(err)
			if err then
				sock:close()
				if vim.uv.now() < deadline then
					vim.defer_fn(connect, 100)
				end
				return
			end
			sock:read_start(function(_, chunk)
				if chunk then
					reply = reply .. chunk
				end
			end)
			local body = vim.json.encode({
				seq = 1,
				type = "request",
				command = "initialize",
				arguments = { clientID = "test-c-setup", adapterID = "codelldb", linesStartAt1 = true, columnsStartAt1 = true, pathFormat = "path" },
			})
			sock:write(("Content-Length: %d\r\n\r\n%s"):format(#body, body))
		end)
	end
	if proc then
		connect()
	end
	local answered = vim.wait(20000, function()
		return reply:find('"command"%s*:%s*"initialize"') ~= nil
	end, 50)
	check("codelldb starts and answers a DAP initialize request",
		answered and reply:find('"success"%s*:%s*true') ~= nil,
		proc and ("reply: " .. reply:sub(1, 200)) or "could not spawn " .. codelldb)
	if sock and not sock:is_closing() then
		sock:close()
	end
	if proc and not proc:is_closing() then
		proc:kill("sigterm")
	end
end

-- Optional live session ------------------------------------------------------
if vim.env.C_TEST_DEBUG == "1" and codelldb ~= "" and cfg then
	local prog_c = write("prog.c", {
		"#include <stdio.h>",
		"",
		"int main(void) {",
		"  int total = 0;",
		"  for (int i = 1; i <= 3; i++)",
		"    total += i;",
		'  printf("%d\\n", total);',
		"  return total == 6 ? 0 : 1;",
		"}",
	})
	local exe = dir .. "/prog"
	local cc = vim.system({ "cc", "-g", "-O0", prog_c, "-o", exe }):wait()
	check("cc -g builds the debug target", cc.code == 0, cc.stderr)
	if cc.code == 0 then
		vim.cmd.edit(prog_c)
		vim.api.nvim_win_set_cursor(0, { 7, 0 })
		dap.toggle_breakpoint()

		local exit_code
		dap.listeners.after.event_exited["test-c-setup"] = function(_, body)
			exit_code = body.exitCode
		end
		local run = vim.deepcopy(cfg)
		run.program, run.args = exe, {}
		dap.run(run)

		local hit = vim.wait(60000, function()
			local s = dap.session()
			return s ~= nil and s.current_frame ~= nil and s.current_frame.line == 7
		end, 100)
		check("debugger stops at the breakpoint (prog.c:7)", hit)
		if hit then
			local s, value = dap.session(), nil
			-- "watch", not "repl": codelldb reads REPL input as LLDB commands.
			s:request("evaluate", { expression = "total", frameId = s.current_frame.id, context = "watch" }, function(err, resp)
				value = resp and resp.result or ("error: " .. tostring(err and err.message))
			end)
			vim.wait(10000, function() return value ~= nil end, 50)
			check("a local evaluates at the breakpoint (total == 6)", value == "6", "got " .. tostring(value))
			dap.continue()
		end
		local done = vim.wait(30000, function() return exit_code ~= nil end, 100)
		check("program runs to completion under the debugger (exit 0)", done and exit_code == 0,
			"exit code " .. tostring(exit_code))
		dap.listeners.after.event_exited["test-c-setup"] = nil
		if dap.session() then
			dap.terminate()
		end
	end
elseif vim.env.C_TEST_DEBUG ~= "1" then
	say("SKIP: live debug session (set C_TEST_DEBUG=1 to run it)")
end

vim.fn.delete(dir, "rf")
finish()
