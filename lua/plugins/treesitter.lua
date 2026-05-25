return {
  "nvim-treesitter/nvim-treesitter",
  -- Archived 2026-04-03; pin so lazy never tries to update and clobber the
  -- query_predicates.lua patch committed locally in the plugin's git repo.
  pin = true,
  build = ":TSUpdate",
  config = function()
    local config = require("nvim-treesitter.configs")
    config.setup({
      -- ensure_installed = {
      --   "lua",
      --   "html",
      --   "css",
      --   "javascript",
      --   "typescript",
      --   "json",
      --   "bash",
      -- },
      auto_install = true,
      highlight = { enable = true, disable = { "markdown", "markdown_inline", "html" } },
      indent = { enable = true },
    })
  end,
}
