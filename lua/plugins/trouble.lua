return {
	"folke/trouble.nvim",
	cmd = "Trouble",
	opts = {},
	keys = {
		{ "<leader>qd", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (workspace)" },
		{ "<leader>qb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (buffer)" },
		{ "<leader>qs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols outline" },
		{ "<leader>qq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
	},
}
