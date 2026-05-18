return {
	"akinsho/bufferline.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("bufferline").setup({
			options = {
				separator_style = "slant",
				always_show_bufferline = false,
				custom_filter = function(buf_number)
					return vim.fn.bufname(buf_number) ~= ""
				end,
			},
		})
		vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
		vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
		vim.keymap.set("n", "<leader>x", function()
			local buffers = vim.fn.getbufinfo({ buflisted = 1 })
			if #buffers > 1 then
				vim.cmd("bp|bd #")
			else
				vim.cmd("bd")
			end
		end, { silent = true })
	end,
}
