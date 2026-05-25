return {
  "oxfist/night-owl.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("night-owl").setup()
    vim.cmd.colorscheme "night-owl"

    -- All floats default to the dark editor background — plugins inherit this for free
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#011627", fg = "#d6deeb" })
    vim.api.nvim_set_hl(0, "FloatBorder", { bg = "#011627", fg = "#637777" })
    vim.api.nvim_set_hl(0, "FloatTitle",  { bg = "#011627", fg = "#7fdbca", bold = true })

    -- Full-screen floats (terminal, lazygit) keep the same dark bg but use this
    -- for the border colour via winhighlight in snacks.lua
    vim.api.nvim_set_hl(0, "TermFloat", { bg = "#011627", fg = "#637777" })

    -- LSP hover / signature / diagnostic floats opt in to the elevated blue background
    vim.api.nvim_set_hl(0, "LspFloat",       { bg = "#1d3b53", fg = "#d6deeb" })
    vim.api.nvim_set_hl(0, "LspFloatBorder", { bg = "#1d3b53", fg = "#82aaff" })
    vim.api.nvim_set_hl(0, "LspFloatTitle",  { bg = "#1d3b53", fg = "#7fdbca", bold = true })
  end,
}

