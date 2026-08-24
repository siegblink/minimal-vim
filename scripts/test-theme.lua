-- Tests for lua/theme.lua.
-- Run: nvim --headless -c 'luafile scripts/test-theme.lua'
--
-- NOT `nvim -l`: `-l` skips init.lua, so lazy never runs and neither
-- colourscheme is on the runtimepath. This test needs the real plugin
-- environment.
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

--- Read the desktop appearance WITHOUT going through theme.lua, so the check
--- below is independent of the code under test.
local function system_mode()
	local cmd
	if vim.fn.has("mac") == 1 then
		cmd = { "defaults", "read", "-g", "AppleInterfaceStyle" }
	elseif vim.fn.executable("gsettings") == 1 then
		cmd = { "gsettings", "get", "org.gnome.desktop.interface", "color-scheme" }
	else
		return nil
	end
	return vim.fn.system(cmd):lower():find("dark") and "dark" or "light"
end

-- Whatever the desktop currently says is the baseline for every case below.
local truth = system_mode()
theme.sync(true)
settle()
local sys = theme.mode()
print("(system appearance detected as: " .. sys .. ")")

-- Compare against an INDEPENDENT reading, not against theme.mode() itself.
-- This assertion used to be `check(..., theme.mode(), sys)` where sys had just
-- been assigned from theme.mode() -- i.e. it compared a value to itself and
-- passed even when sync() did nothing at all. That is precisely how the
-- non-macOS bail shipped: on Linux sync() returned immediately, no scheme was
-- ever applied, and the whole suite still went green.
if truth then
	check("sync(force) follows the real system appearance", sys, truth)
else
	print("(no appearance detector on this platform -- follow check skipped)")
end

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
		NeoTreeCursorLine = "bg", BufferLineFill = "bg", Visual = "bg",
	},
	dark = {
		NormalFloat = "bg", LspFloatBorder = "fg",
		NeoTreeCursorLine = "bg", BufferLineFill = "bg", Visual = "bg",
	},
}
for mode, groups in pairs(expect) do
	theme.apply(mode)
	for group, key in pairs(groups) do
		local got = vim.api.nvim_get_hl(0, { name = group, link = false })[key]
		local want = tonumber(theme.palette[mode][({
			NormalFloat = "float_bg", LspFloatBorder = "lsp_border",
			NeoTreeCursorLine = "neotree_cursorline", BufferLineFill = "bl_fill",
			Visual = "visual",
		})[group]]:sub(2), 16)
		check(("%s: %s.%s"):format(mode, group, key), got, want)
	end
end

-- Switching must not leave groups behind from the previous scheme. night-owl
-- doesn't `highlight clear` on the :colorscheme path, so without theme.lua
-- doing it, anything catppuccin defines and night-owl doesn't survives.
--
-- NormalNC is the regression that prompted this: Neovim paints non-current
-- windows with it, so with the cursor in neo-tree the editor kept catppuccin's
-- light background even though Normal was correctly dark. A single-window
-- check cannot see that -- the only window is always the current one.
local function bg_of(group)
	return vim.api.nvim_get_hl(0, { name = group })["bg"]
end

theme.apply("light")
local light_normal = bg_of("Normal")
theme.apply("dark")
local dark_normal = bg_of("Normal")

for _, group in ipairs({ "NormalNC", "NormalFloat", "SignColumn", "Pmenu" }) do
	local got = bg_of(group)
	-- Nothing may still be wearing the light scheme's Normal background.
	check(("dark: %s does not retain the light bg"):format(group), got ~= light_normal, true)
end

check("light and dark Normal actually differ", light_normal ~= dark_normal, true)

-- And the same in reverse.
theme.apply("light")
for _, group in ipairs({ "NormalNC", "NormalFloat", "SignColumn", "Pmenu" }) do
	check(("light: %s does not retain the dark bg"):format(group), bg_of(group) ~= dark_normal, true)
end

-- Startup regression: 'background' matching the target mode is NOT evidence
-- that a colourscheme is loaded. night-owl's plugin setup() sets
-- background=dark and g:colors_name without applying any highlights -- those
-- only land when colors/night-owl.lua is sourced. sync() used to skip apply()
-- whenever the mode already matched, so starting Neovim on a dark system left
-- the editor sitting on Neovim's cleared defaults.
for _, mode in ipairs({ "light", "dark" }) do
	vim.cmd("highlight clear")
	vim.o.background = mode -- mode already "matches"...
	vim.g.colors_name = nil -- ...but nothing is actually loaded
	theme.apply(mode)
	check(("recovers a missing scheme in %s"):format(mode), vim.g.colors_name, theme.schemes[mode])
	check(("%s: Normal is not Neovim's default"):format(mode), bg_of("Normal") ~= 0x14161b, true)
end

-- The startup entry point must land on a real scheme even when 'background'
-- ALREADY equals the system mode -- that is precisely the startup condition,
-- since night-owl's setup() has already set background=dark by this point.
-- Setting background to anything else here would make this test vacuous: the
-- old guard would pass on the mismatch alone. (Verified by mutation.)
vim.cmd("highlight clear")
vim.o.background = sys -- already matches what the system will report
vim.g.colors_name = nil -- yet nothing is loaded
theme.sync(true)
settle()
check("forced sync loads a scheme when background already matches",
	vim.g.colors_name, theme.schemes[sys])

-- Cross-platform regression: sync() used to bail on every non-macOS platform,
-- so on Linux nothing ever applied a scheme and the editor rendered Neovim's
-- built-in defaults.
--
-- g:colors_name is NOT a usable check here. night-owl's plugin setup() sets it
-- (and 'background') without applying any highlights, so on a broken Linux
-- start it reads "night-owl" while Normal is still #14161b -- looks themed,
-- renders unthemed. Assert what is actually on screen.
vim.cmd("highlight clear")
vim.g.colors_name = nil
theme.sync(true)
settle()
check("forced sync renders real highlights, not Neovim's defaults",
	bg_of("Normal") ~= 0x14161b, true)
check("forced sync lands one of our schemes",
	vim.g.colors_name == theme.schemes.dark or vim.g.colors_name == theme.schemes.light, true)

-- With no detector at all, a forced sync must STILL land a scheme -- returning
-- early is what leaves the editor blank. Unforced calls have nothing to follow
-- and must not thrash the user's manual choice.
local real_exec = vim.fn.executable
local real_has = vim.fn.has
vim.fn.executable = function(n) return n == "gsettings" and 0 or real_exec(n) end
vim.fn.has = function(f) return f == "mac" and 0 or real_has(f) end
vim.cmd("highlight clear")
vim.g.colors_name = nil
theme.sync(true)
settle(100)
check("no detector: forced sync still applies a scheme",
	bg_of("Normal") ~= 0x14161b, true)
vim.fn.executable, vim.fn.has = real_exec, real_has

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all tests passed")
os.exit(0)
