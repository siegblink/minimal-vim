return {
	"akinsho/bufferline.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Values still live in lua/theme.lua -- this only wires them in. They
		-- have to be passed to setup() as well as written to the BufferLine*
		-- groups, because bufferline builds its per-filetype devicon
		-- highlights from the `highlights` table it was set up with, NOT from
		-- the groups theme.lua writes afterwards. See set_icon_highlight() in
		-- bufferline/highlights.lua: it extends `hls.background` /
		-- `hls.buffer_selected` from its own internal config.
		--
		-- Without this the icon on an inactive tab kept bufferline's computed
		-- background (#d4d4d5 in the light half) while the tab around it was
		-- #eaeaee, so the icon sat on a visibly darker block. `color_icons`
		-- does not help: it only blanks the icon's fg, never its bg.
		--
		-- Rebuilt on every ColorScheme rather than captured once -- a table
		-- passed a single time at setup would bake in whichever mode happened
		-- to be active and go stale on the next switch.
		local function opts()
			local c = require("theme").colors()
			return {
				options = {
					separator_style = "slant",
					always_show_bufferline = false,
					sort_by = "insert_after_current",
					custom_filter = function(buf_number)
						return vim.fn.bufname(buf_number) ~= ""
					end,
					close_command = function(_)
						Snacks.bufdelete()
					end,
				},
				highlights = {
					fill = { bg = c.bl_fill },
					background = { fg = c.bl_inactive_fg, bg = c.bl_inactive_bg },
					buffer_visible = { fg = c.bl_visible_fg, bg = c.bl_inactive_bg },
					buffer_selected = { fg = c.bl_active_fg, bg = c.bl_active_bg, bold = true },
				},
			}
		end

		require("bufferline").setup(opts())

		-- theme.lua's apply() fires ColorScheme, and bufferline's own handler
		-- for that event refreshes highlights from the config it is HOLDING --
		-- which is the table captured at setup, i.e. the old mode's colours.
		-- Re-running setup is what replaces that stored table.
		--
		-- The cache reset afterwards is required, not belt-and-braces:
		-- setup() clears the existing BufferLineDevIcon* groups but leaves
		-- icon_hl_cache populated, so set_icon_highlight() takes its early
		-- return and never recreates them. Without this the icons end up with
		-- no highlight at all -- worse than the mismatched background this
		-- whole change is fixing. Verified by counting the groups after a
		-- switch: 2 before, 0 after setup alone, 2 again with the reset.
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("bufferline_follow_theme", { clear = true }),
			callback = function()
				pcall(function()
					require("bufferline").setup(opts())
					require("bufferline.highlights").reset_icon_hl_cache()
				end)
			end,
		})

		vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
		vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
		vim.keymap.set("n", "<leader>x", function()
			Snacks.bufdelete()
		end, { silent = true })
	end,
}
