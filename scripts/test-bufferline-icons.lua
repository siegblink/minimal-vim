-- Tests that a tab's devicon sits on the same background as the tab itself.
-- Run: nvim --headless -c 'luafile scripts/test-bufferline-icons.lua'
--
-- bufferline builds its per-filetype icon highlights from the `highlights`
-- table it was set up with, NOT from the BufferLine* groups theme.lua writes
-- afterwards -- see set_icon_highlight() in bufferline/highlights.lua, which
-- extends `hls.background` / `hls.buffer_selected` from bufferline's own
-- internal config. So overriding the visible groups alone left the icon on
-- bufferline's computed background (#d4d4d5 in the light half) while the tab
-- around it was #eaeaee: a visible darker block behind the icon.
--
-- The icon groups only exist once the tabline has actually been rendered, so
-- this forces an evaluation. A first version of this check skipped that and
-- silently passed against ZERO groups -- hence the explicit vacuity guard.

local theme = require("theme")

local failures = 0
local function check(name, got, want)
	if got == want then
		print("PASS: " .. name)
	else
		print(("FAIL: %s\n  want: %s\n  got:  %s"):format(name, tostring(want), tostring(got)))
		failures = failures + 1
	end
end

-- Two buffers so both the selected and the unselected states are exercised.
vim.cmd("edit CLAUDE.md")
vim.cmd("edit README.md")
vim.wait(500, function() return false end)

local function hex(group, attr)
	local h = vim.api.nvim_get_hl(0, { name = group, link = false })
	return h[attr] and string.format("#%06x", h[attr]) or nil
end

local function icon_groups()
	-- Rendering is what creates them; without this there is nothing to check.
	pcall(vim.api.nvim_eval_statusline, vim.o.tabline, { use_tabline = true })
	local names = {}
	for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
		if name:match("^BufferLineDevIcon") then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

for _, mode in ipairs({ "dark", "light" }) do
	theme.apply(mode)
	vim.wait(300, function() return false end)

	local selected_bg = hex("BufferLineBufferSelected", "bg")
	local inactive_bg = hex("BufferLineBackground", "bg")
	local groups = icon_groups()

	-- Guard against the check passing simply because nothing was found.
	check(mode .. ": tabline rendered some icon groups", #groups > 0, true)

	for _, g in ipairs(groups) do
		local want = g:match("Selected$") and selected_bg or inactive_bg
		check(("%s: %s sits on its tab's background"):format(mode, g), hex(g, "bg"), want)
	end
end

if failures > 0 then
	print(failures .. " test(s) failed")
	os.exit(1)
end
print("all tests passed")
os.exit(0)
