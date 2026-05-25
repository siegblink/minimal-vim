return {
  "oxfist/night-owl.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("night-owl").setup()
    vim.cmd.colorscheme "night-owl"

    -- Elevate LSP/diagnostic float windows above the editor
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#1d3b53", fg = "#d6deeb" })
    vim.api.nvim_set_hl(0, "FloatBorder", { bg = "#1d3b53", fg = "#82aaff" })
    vim.api.nvim_set_hl(0, "FloatTitle",  { bg = "#1d3b53", fg = "#7fdbca", bold = true })

    -- Subtle border for full-screen floats (terminal, lazygit) — stays on editor background
    vim.api.nvim_set_hl(0, "TermFloat", { bg = "#011627", fg = "#637777" })

    -- Lazy.nvim and Mason inherit NormalFloat, which would make them bright blue.
    -- Pin each to the dark editor background so only LSP/diagnostic floats get the
    -- elevated colour.
    vim.api.nvim_set_hl(0, "LazyNormal",      { bg = "#011627", fg = "#d6deeb" })
    vim.api.nvim_set_hl(0, "LazyFloat",       { bg = "#011627", fg = "#d6deeb" })
    vim.api.nvim_set_hl(0, "LazyFloatBorder", { bg = "#011627", fg = "#637777" })
    vim.api.nvim_set_hl(0, "MasonNormal",     { bg = "#011627", fg = "#d6deeb" })
  end,
}

