return {
	"akinsho/flutter-tools.nvim",
	lazy = false,
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		local capabilities = require("cmp_nvim_lsp").default_capabilities()
		require("flutter-tools").setup({
			lsp = {
				capabilities = capabilities,
			},
			debugger = {
				enabled = true,
				run_via_dap = true,
			},
			closing_tags = { enabled = true },
			widget_guides = { enabled = true },
			dev_log = { enabled = true },
		})
	end,
}
