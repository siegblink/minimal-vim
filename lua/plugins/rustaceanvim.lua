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

          -- Task 2 adds the format-on-save autocmd below this line.
          -- Task 3 (you) adds the buffer-local Rust keymaps below this line.
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
