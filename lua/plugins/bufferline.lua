return {
	"akinsho/bufferline.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local p = {
			fill = "#010d18", -- darkest night-owl background
			inactive_bg = "#01111d", -- tab_inactive_bg
			active_bg = "#0b2942", -- tab_active_bg
			inactive_fg = "#4b6479", -- line_number_fg (muted)
			visible_fg = "#5f7e97", -- ui_border (mid-tone)
			active_fg = "#c5e4fc", -- line_number_active_fg (bright)
			indicator = "#82aaff", -- blue accent
			modified = "#c5e478", -- green (modified dot)
		}

		require("bufferline").setup({
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
				fill = { bg = p.fill },

				background = { fg = p.inactive_fg, bg = p.inactive_bg },
				buffer_visible = { fg = p.visible_fg, bg = p.inactive_bg },
				buffer_selected = { fg = p.active_fg, bg = p.active_bg, bold = true },

				tab = { fg = p.inactive_fg, bg = p.inactive_bg },
				tab_selected = { fg = p.active_fg, bg = p.active_bg, bold = true },
				tab_close = { fg = p.inactive_fg, bg = p.fill },

				close_button = { fg = p.inactive_fg, bg = p.inactive_bg },
				close_button_visible = { fg = p.visible_fg, bg = p.inactive_bg },
				close_button_selected = { fg = p.active_fg, bg = p.active_bg },

				separator = { fg = p.fill, bg = p.inactive_bg },
				separator_visible = { fg = p.fill, bg = p.inactive_bg },
				separator_selected = { fg = p.fill, bg = p.active_bg },

				indicator_visible = { fg = p.inactive_bg, bg = p.inactive_bg },
				indicator_selected = { fg = p.indicator, bg = p.active_bg },

				modified = { fg = p.modified, bg = p.inactive_bg },
				modified_visible = { fg = p.modified, bg = p.inactive_bg },
				modified_selected = { fg = p.modified, bg = p.active_bg },

				-- parent dir prefix shown when two files share the same name
				duplicate = { fg = p.inactive_fg, bg = p.inactive_bg, italic = true },
				duplicate_visible = { fg = p.visible_fg, bg = p.inactive_bg, italic = true },
				duplicate_selected = { fg = "#7fdbca", bg = p.active_bg, italic = true },
			},
		})

		vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
		vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
		vim.keymap.set("n", "<leader>x", function()
			Snacks.bufdelete()
		end, { silent = true })
	end,
}
