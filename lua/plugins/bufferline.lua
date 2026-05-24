return {
	"akinsho/bufferline.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
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
		})
		vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
		vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
		vim.keymap.set("n", "<leader>x", function()
			Snacks.bufdelete()
		end, { silent = true })
	end,
}
