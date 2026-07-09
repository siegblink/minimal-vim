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
