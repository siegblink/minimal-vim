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
		-- v2 knobs are only `ensure_installed` and `automatic_enable` (default
		-- true: every Mason-installed server is enabled). The old
		-- `auto_install = true` was not a v2 option and did nothing.
		-- stylua is excluded: the Mason stylua package is the binary none-ls
		-- formats Lua with, and enabled as a server it would be a second Lua
		-- formatter (see no_formatting below).
		opts = {
			automatic_enable = { exclude = { "stylua" } },
		},
	},
	{
		"neovim/nvim-lspconfig",
		lazy = false,
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- One formatter per language: its none-ls source (stylua, black,
			-- prettier). <leader>gf is vim.lsp.buf.format(), which runs EVERY
			-- attached client that can format, in client-start order, so a
			-- server's own formatter races the none-ls one and whichever runs last
			-- decides the style (lua_ls re-indents stylua's tabs to spaces; it,
			-- pylsp's autopep8/yapf and tsc all keep 'single' quotes). Dropping the
			-- capability in on_init means Neovim never asks these servers to
			-- format, whatever their settings or a project's .luarc.json say.
			-- scripts/test-formatters.lua checks this.
			local function no_formatting(client)
				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false
			end

			-- Configure each LSP server
			vim.lsp.config.html = {
				capabilities = capabilities,
			}
			vim.lsp.config.cssls = {
				capabilities = capabilities,
			}
			-- TypeScript 7 native LSP (Mason package `tsc`). Everything beyond
			-- capabilities and the formatting opt-out comes from upstream
			-- nvim-lspconfig's lsp/tsc.lua: binary resolution (project-local vs
			-- $PATH, version-gated >= 7), Deno detection, and a clean no-attach
			-- when no TS7 binary exists.
			vim.lsp.config.tsc = {
				capabilities = capabilities,
				on_init = no_formatting,
			}
			vim.lsp.config.lua_ls = {
				capabilities = capabilities,
				on_init = no_formatting,
			}
			vim.lsp.config.pylsp = {
				capabilities = capabilities,
				on_init = no_formatting,
			}
			-- C/C++ (Mason package `clangd`; Mason has no Linux arm64 build, so
			-- there the distro clangd on $PATH is used). Formatting (<leader>gf)
			-- is clangd's built-in clang-format, the same split as rust-analyzer
			-- driving rustfmt, so none-ls has no C source. Style: the nearest
			-- .clang-format, else LLVM. Compile flags come from the project's
			-- compile_commands.json or compile_flags.txt; fallbackFlags apply only
			-- to files with neither (single-file programs) so those still get the
			-- warnings a real -Wall -Wextra build would print.
			vim.lsp.config.clangd = {
				capabilities = capabilities,
				init_options = {
					fallbackFlags = { "-Wall", "-Wextra" },
				},
			}

			-- Enable all configured servers
			vim.lsp.enable({ "html", "cssls", "tsc", "lua_ls", "pylsp", "clangd" })

			-- clangd: inlay hints on by default (<leader>ci toggles, see
			-- after/ftplugin/c.lua). Parameter-name hints expose swapped
			-- arguments, e.g. memset(buf, sizeof buf, 0) labels the size as the
			-- fill byte.
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("clangd-attach", { clear = true }),
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client and client.name == "clangd" then
						vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
					end
				end,
			})

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
