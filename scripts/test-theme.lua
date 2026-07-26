-- Tests for lua/theme.lua.
-- Run: nvim --headless -c 'luafile scripts/test-theme.lua'
--
-- NOT `nvim -l`, unlike test-tsgo-cmd.lua: `-l` skips init.lua, so lazy never
-- runs and neither colourscheme is on the runtimepath. That test only touches a
-- pure module; this one needs the real plugin environment.
--
-- Regression cover for the bug where a manual `:Theme toggle` was silently
-- undone. sync() used to apply the system mode whenever it differed from the
-- editor's mode, so the next FocusGained -- or the startup sync() still in
-- flight -- would revert the toggle. It followed the system on every check
-- rather than only when the system itself changed.
--
-- Reads the real macOS appearance and reasons relative to it, so the test is
-- valid in either mode.
local ok_mod, theme = pcall(require, "theme")
if not ok_mod then
	print("FAIL: could not require theme: " .. tostring(theme))
	os.exit(1)
end

-- Fail loudly rather than emitting a wall of confusing mismatches if this is
-- run in an environment where the colourschemes never loaded.
for _, scheme in pairs(theme.schemes) do
	if vim.fn.empty(vim.fn.globpath(vim.o.rtp, "colors/" .. scheme .. ".*")) == 1 then
		print(("FAIL: colourscheme %q is not on the runtimepath."):format(scheme))
		print("      Run with: nvim --headless -c 'luafile scripts/test-theme.lua'")
		os.exit(1)
	end
end

local failures = 0

local function check(name, got, want)
	if got == want then
		print("PASS: " .. name)
	else
		print(("FAIL: %s\n  want: %s\n  got:  %s"):format(name, tostring(want), tostring(got)))
		failures = failures + 1
	end
end

local function settle(ms)
	vim.wait(ms or 350, function() return false end)
end

local function other(m)
	return m == "dark" and "light" or "dark"
end

-- Whatever macOS currently says is the baseline for every case below.
theme.sync(true)
settle()
local sys = theme.mode()
print("(system appearance detected as: " .. sys .. ")")

check("sync(force) follows the system", theme.mode(), sys)

-- The reported bug: a manual toggle must outlive both the in-flight startup
-- sync() and any number of focus events.
theme.toggle()
check("toggle switches away from system", theme.mode(), other(sys))
settle(500)
check("toggle survives a late sync() callback", theme.mode(), other(sys))

for i = 1, 3 do
	theme.sync()
	settle(250)
	check("toggle survives FocusGained #" .. i, theme.mode(), other(sys))
end

-- Explicitly asking to re-follow must still work.
theme.sync(true)
settle()
check(":Theme system re-follows the system", theme.mode(), sys)

-- A genuine system change outranks a manual choice: sit manually in the
-- non-system mode, claim we last observed that same mode, then let sync() see
-- the real value change back.
theme.apply(other(sys))
theme._system = other(sys)
check("manually parked opposite the system", theme.mode(), other(sys))
theme.sync()
settle()
check("observed system change overrides manual choice", theme.mode(), sys)

-- Both colourschemes must actually load and set a background.
for _, mode in ipairs({ "light", "dark" }) do
	theme.apply(mode)
	local n = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	check(mode .. ": colors_name set", vim.g.colors_name, theme.schemes[mode])
	check(mode .. ": Normal has a background", type(n.bg), "number")
end

-- Every hand-set group must track the mode rather than going stale.
local expect = {
	light = {
		NormalFloat = "bg", LspFloatBorder = "fg",
		NeoTreeCursorLine = "bg", BufferLineFill = "bg",
	},
	dark = {
		NormalFloat = "bg", LspFloatBorder = "fg",
		NeoTreeCursorLine = "bg", BufferLineFill = "bg",
	},
}
for mode, groups in pairs(expect) do
	theme.apply(mode)
	for group, key in pairs(groups) do
		local got = vim.api.nvim_get_hl(0, { name = group, link = false })[key]
		local want = tonumber(theme.palette[mode][({
			NormalFloat = "float_bg", LspFloatBorder = "lsp_border",
			NeoTreeCursorLine = "neotree_cursorline", BufferLineFill = "bl_fill",
		})[group]]:sub(2), 16)
		check(("%s: %s.%s"):format(mode, group, key), got, want)
	end
end

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all tests passed")
os.exit(0)
