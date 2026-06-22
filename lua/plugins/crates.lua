return {
	"saecki/crates.nvim",
	tag = "stable",
	event = { "BufRead Cargo.toml" },
	config = function()
		local crates = require("crates")
		crates.setup({
			completion = {
				cmp = { enabled = true },
			},
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
