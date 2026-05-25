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
			vim.lsp.config.ts_ls = {
				capabilities = capabilities,
				on_attach = function(_, bufnr)
					local js_filetypes = { javascript = true, javascriptreact = true }

					if js_filetypes[vim.bo[bufnr].filetype] then
						vim.diagnostic.enable(false, { bufnr = bufnr })
					end
				end,
			}
			vim.lsp.config.lua_ls = {
				capabilities = capabilities,
			}
			vim.lsp.config.pylsp = {
				capabilities = capabilities,
			}

			-- Enable all configured servers
			vim.lsp.enable({ "html", "cssls", "ts_ls", "lua_ls", "pylsp" })

			-- Bordered floating window for signature help (hover border is set per-call via K keymap)
			vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
				return vim.lsp.handlers.signature_help(err, result, ctx, vim.tbl_extend("force", config or {}, { border = "rounded" }))
			end

			-- Bordered, sourced diagnostic floats (<leader>e)
			vim.diagnostic.config({
				float = {
					border = "rounded",
					source = true,
					header = "",
					prefix = "",
				},
			})

			vim.keymap.set("n", "K", function()
				vim.lsp.buf.hover({ border = "rounded", max_width = 80, max_height = 20 })
			end, {})
			vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
			vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {})
			vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {})
		end,
	},
}
