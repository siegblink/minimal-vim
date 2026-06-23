return {
	"saecki/crates.nvim",
	tag = "stable",
	event = { "BufRead Cargo.toml" },
	config = function()
		local crates = require("crates")

		-- Bordered floating popups that match the styled LSP hover (K). Mirrors
		-- lsp_float_opts in lsp-config.lua: rounded border + the blue LspFloatBorder
		-- highlight. crates.nvim has no winhighlight option for its popup window, so
		-- we apply it ourselves below once the window opens.
		local hover_winhighlight = "NormalFloat:NormalFloat,FloatBorder:LspFloatBorder,FloatTitle:FloatTitle"

		crates.setup({
			completion = {
				cmp = { enabled = true },
			},
			popup = {
				border = "rounded",
			},
		})

		-- crates sets filetype "crates.nvim" on the popup buffer *before* it opens
		-- the window, so the window doesn't exist yet when FileType fires — defer a
		-- tick, then style whichever window ends up showing the popup buffer.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "crates.nvim",
			callback = function(ev)
				vim.schedule(function()
					for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
						vim.wo[win].winhighlight = hover_winhighlight
					end
				end)
			end,
		})

		local function set_keymaps(buf)
			local function map(lhs, fn, desc)
				vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
			end
			map("<leader>cv", crates.show_versions_popup, "Crates: versions")
			map("<leader>cf", crates.show_features_popup, "Crates: features")
			map("<leader>cu", crates.update_crate, "Crates: update crate")
			map("<leader>cU", crates.upgrade_all_crates, "Crates: upgrade all")
		end

		-- crates.nvim is lazy-loaded ON `BufRead Cargo.toml`, so that event has
		-- already fired for the current buffer by the time this runs. Register
		-- the autocmd for FUTURE Cargo.toml buffers...
		vim.api.nvim_create_autocmd("BufRead", {
			pattern = "Cargo.toml",
			callback = function(ev)
				set_keymaps(ev.buf)
			end,
		})

		-- ...and apply to the Cargo.toml that triggered this load right now.
		local cur = vim.api.nvim_get_current_buf()
		if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(cur), ":t") == "Cargo.toml" then
			set_keymaps(cur)
		end
	end,
}
