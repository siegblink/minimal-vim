return {
  -- Archived upstream 2026-04-03; vendored into the config repo with the
  -- Neovim 0.12 query_predicates.lua patch applied. As a dir= local plugin,
  -- lazy never fetches it and it stays out of lazy-lock.json (the per-machine
  -- patch commit hashes made the lockfile ping-pong between machines).
  dir = vim.fn.stdpath("config") .. "/vendor/nvim-treesitter",
  config = function()
    local config = require("nvim-treesitter.configs")
    config.setup({
      -- auto_install fetches the parser for a buffer's own filetype, never for
      -- languages injected into it. C's queries inject printf (format
      -- specifiers in printf/scanf strings) and doxygen (/** */ comments).
      ensure_installed = { "printf", "doxygen" },
      auto_install = true,
      highlight = { enable = true, disable = { "markdown", "markdown_inline", "html" } },
      indent = { enable = true },
    })
  end,
}
