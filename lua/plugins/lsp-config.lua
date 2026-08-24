return {
	{
		"williamboman/mason.nvim",
		lazy = false,
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		lazy = false,
		opts = {
			auto_install = true,
		},
	},
	{
		"neovim/nvim-lspconfig",
		lazy = false,
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Configure each LSP server
			vim.lsp.config.html = {
				capabilities = capabilities,
			}
			vim.lsp.config.cssls = {
				capabilities = capabilities,
			}
			-- TypeScript 7 native LSP (Mason package `tsc`). Everything beyond
			-- capabilities comes from upstream nvim-lspconfig's lsp/tsc.lua:
			-- binary resolution (project-local vs $PATH, version-gated >= 7),
			-- Deno detection, and a clean no-attach when no TS7 binary exists.
			vim.lsp.config.tsc = {
				capabilities = capabilities,
			}
			vim.lsp.config.lua_ls = {
				capabilities = capabilities,
			}
			vim.lsp.config.pylsp = {
				capabilities = capabilities,
			}

			-- Enable all configured servers
			vim.lsp.enable({ "html", "cssls", "tsc", "lua_ls", "pylsp" })

			local lsp_float_opts = {
				border = "rounded",
				winhighlight = "NormalFloat:NormalFloat,FloatBorder:LspFloatBorder,FloatTitle:FloatTitle",
			}

			vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
				return vim.lsp.handlers.signature_help(
					err,
					result,
					ctx,
					vim.tbl_extend("force", config or {}, lsp_float_opts)
				)
			end

			-- Bordered, sourced diagnostic floats (<leader>e)
			vim.diagnostic.config({
				float = vim.tbl_extend("force", lsp_float_opts, {
					source = true,
					header = "",
					prefix = "",
				}),
			})

			vim.keymap.set("n", "K", function()
				vim.lsp.buf.hover(vim.tbl_extend("force", lsp_float_opts, { max_width = 80, max_height = 20 }))
			end, {})
			vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
			vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {})
			vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {})
		end,
	},
}
