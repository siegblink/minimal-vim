-- Tests that lazygit looks the same inside Neovim as it does standalone.
-- Run: nvim --headless -c 'luafile scripts/test-lazygit-theme.lua'
--
-- snacks generates its own lazygit config and appends it to LG_CONFIG_FILE, so
-- inside the editor it OVERRIDES ~/.config/lazygit/config.yml. Both must agree
-- or the same lazygit renders differently in the two places.
--
-- Replicates snacks/lazygit.lua get_color() verbatim, so this checks what
-- snacks would actually write without having to launch the TUI. An EMPTY
-- result is the specific bug this guards: snacks writes the key with no value
-- and lazygit reads that as "no highlight". Its default mapped
-- selectedLineBgColor at Visual, whose bg it sometimes resolved as absent,
-- which left the selected commit with no background at all.
--
-- STANDALONE below must be kept in step with set_lazygit() in
-- dotfiles/dot_scripts/executable_theme. If you change a colour there and not
-- here, this test tells you.
local function get_color(v)
	local color = {}
	for _, c in ipairs({ "fg", "bg" }) do
		if v[c] then
			local hl = vim.api.nvim_get_hl(0, { name = v[c], link = false })
			local val = c == "fg" and (hl and hl.fg or hl.foreground) or (hl and hl.bg or hl.background)
			if val then
				table.insert(color, string.format("#%06x", val))
			end
		end
	end
	if v.bold then
		table.insert(color, "bold")
	end
	return color
end

local MAP = {
	activeBorderColor = { fg = "LazygitActiveBorder", bold = true },
	inactiveBorderColor = { fg = "LazygitInactiveBorder" },
	searchingActiveBorderColor = { fg = "LazygitSearchingBorder", bold = true },
	optionsTextColor = { fg = "LazygitOptionsText" },
	selectedLineBgColor = { fg = "LazygitSelectedLine" },
	cherryPickedCommitFgColor = { fg = "LazygitCherryPickedFg" },
	cherryPickedCommitBgColor = { fg = "LazygitCherryPickedBg" },
	unstagedChangesColor = { fg = "LazygitUnstaged" },
	defaultFgColor = { fg = "LazygitDefaultFg" },
}

-- What the standalone config writes, so the two can be compared directly.
local STANDALONE = {
	dark = {
		activeBorderColor = "#88a3d9", inactiveBorderColor = "#4b6479",
		searchingActiveBorderColor = "#d2b189", optionsTextColor = "#80908f",
		selectedLineBgColor = "#1d3b53", cherryPickedCommitFgColor = "#88a3d9",
		cherryPickedCommitBgColor = "#1d3b53", unstagedChangesColor = "#c07a73",
		defaultFgColor = "#b5bcc5",
	},
	light = {
		activeBorderColor = "#2153b8", inactiveBorderColor = "#696e84",
		searchingActiveBorderColor = "#96631b", optionsTextColor = "#696e84",
		selectedLineBgColor = "#bfd6ee", cherryPickedCommitFgColor = "#2153b8",
		cherryPickedCommitBgColor = "#bfd6ee", unstagedChangesColor = "#a51d3a",
		defaultFgColor = "#403f53",
	},
}

local keys = vim.tbl_keys(MAP)
table.sort(keys)
local bad = 0

for _, mode in ipairs({ "dark", "light" }) do
	require("theme").apply(mode)
	print("=== " .. mode .. " ===")
	for _, k in ipairs(keys) do
		local got = get_color(MAP[k])
		local want = STANDALONE[mode][k]
		local first = got[1]
		local status
		if #got == 0 then
			status = "EMPTY -- would write a blank key"
			bad = bad + 1
		elseif first ~= want then
			status = "MISMATCH vs standalone " .. want
			bad = bad + 1
		else
			status = "matches standalone"
		end
		print(string.format("  %-28s %-18s %s", k, table.concat(got, " "), status))
	end
end

print("")
if bad == 0 then
	print("all keys resolve, and every one matches the standalone config")
	vim.cmd("qa!")
else
	print(bad .. " problem(s)")
	vim.cmd("cq!")
end
