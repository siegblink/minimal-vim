return {
  -- Archived upstream 2026-04-03; vendored into the config repo with the
  -- Neovim 0.12 query_predicates.lua patch applied. As a dir= local plugin,
  -- lazy never fetches it and it stays out of lazy-lock.json (the per-machine
  -- patch commit hashes made the lockfile ping-pong between machines).
  dir = vim.fn.stdpath("config") .. "/vendor/nvim-treesitter",
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
