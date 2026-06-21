return {
	"mrcjkb/rustaceanvim",
	version = "^9",
	lazy = false, -- rustaceanvim implements its own lazy-loading
	dependencies = { "hrsh7th/cmp-nvim-lsp" },
	config = function()
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		vim.g.rustaceanvim = {
			server = {
				capabilities = capabilities,
				default_settings = {
					["rust-analyzer"] = {
						-- Run clippy (not just `cargo check`) on save for idiomatic lints
						checkOnSave = true,
						check = { command = "clippy" },
						-- Inlay hints: rust-analyzer side (display is toggled in on_attach)
						inlayHints = { enable = true },
						cargo = { allFeatures = true },
					},
				},
				on_attach = function(client, bufnr)
					-- Inlay hints: show inferred types inline (great while learning Rust)
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

					-- Format on save (Rust only). rust-analyzer drives rustfmt.
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ bufnr = bufnr })
						end,
					})

					-- Buffer-local Rust keymaps (active only in .rs buffers).
					-- :RustLsp is wrapped in a function so it fires on press, not at map time.
					local function rust(cmd)
						return function()
							vim.cmd.RustLsp(cmd)
						end
					end
					local function map(lhs, cmd, desc)
						vim.keymap.set("n", lhs, rust(cmd), { buffer = bufnr, desc = desc })
					end

					vim.keymap.set("n", "K", function()
						vim.cmd.RustLsp({ "hover", "actions" })
					end, { buffer = bufnr, desc = "Rust: hover actions" })

					map("<leader>ca", "codeAction", "Rust: code action")
					map("<leader>rr", "runnables", "Rust: runnables")
					map("<leader>rt", "testables", "Rust: testables")
					map("<leader>rd", "debuggables", "Rust: debuggables")
					map("<leader>rm", "expandMacro", "Rust: expand macro")
					map("<leader>re", "explainError", "Rust: explain error")
					map("<leader>rD", "renderDiagnostic", "Rust: render diagnostic")
					map("<leader>rc", "openCargo", "Rust: open Cargo.toml")
					map("<leader>rp", "parentModule", "Rust: parent module")

					vim.keymap.set("n", "<leader>ri", function()
						local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
						vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
					end, { buffer = bufnr, desc = "Rust: toggle inlay hints" })
				end,
			},
			tools = {
				enable_clippy = true,
			},
			dap = {
				-- Auto-register nvim-dap launch configs when the LSP attaches.
				autoload_configurations = true,
			},
		}
	end,
}
