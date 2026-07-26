-- Light half of the light/dark pair (night-owl.lua is the dark half).
-- Selected by lua/theme.lua, never by a bare `colorscheme` call here.
--
-- Why catppuccin rather than a Night Owl Light port: the only Neovim Light Owl
-- port is pre-treesitter vimscript, so LSP semantic tokens and most plugin
-- groups would go unstyled. Latte is the closest maintained light theme with
-- first-class support for every plugin in this config.
--
-- Why the colour overrides: stock Latte is tuned for softness, not contrast.
-- Measured against our #f2f2f3 background, 16 of its 20 text colours fall below
-- WCAG AA -- comments sit at 2.33:1. Each colour below keeps Latte's exact hue
-- but has been darkened so the whole set clears AA.
--
-- Crucially the darkening is *proportional*, not flat: each colour's original
-- contrast rank is remapped onto [4.5, 7.2]. Flattening everything to 4.5
-- collapsed overlay0/1/2 and subtext0 into one indistinguishable grey and made
-- teal/sapphire/sky nearly identical. Preserving the ranking keeps comments
-- more muted than borders, and keeps all 14 accent hues tellable apart.
--
--   overlay0 4.51  <  overlay1 4.98  <  overlay2 5.53
--            <  subtext0 6.29  <  subtext1 7.20  <  text 9.14

return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavour = "latte",
      background = { light = "latte", dark = "latte" },
      term_colors = false,
      color_overrides = {
        latte = {
          -- Structural: identical to the Ghostty / delta / lazygit surface.
          base = "#f2f2f3",
          mantle = "#e8e8ec",
          crust = "#e2e2e7",
          text = "#403f53",

          -- Muted ramp -- ordering preserved, floor lifted to AA.
          subtext1 = "#4c4f63",
          subtext0 = "#555869",
          overlay2 = "#5e6072",
          overlay1 = "#64677b",
          overlay0 = "#696e84",

          -- Accents -- hue preserved exactly, lightness lowered to clear AA.
          rosewater = "#bb4930",
          flamingo = "#c63232",
          pink = "#c7239b",
          mauve = "#6f25d0",
          red = "#a51d3a",
          maroon = "#bd212f",
          peach = "#aa511e",
          yellow = "#96631b",
          green = "#2f751f",
          teal = "#146e73",
          sky = "#1b7498",
          sapphire = "#177383",
          blue = "#2153b8",
          lavender = "#445bde",
        },
      },
      integrations = {
        treesitter = true,
        native_lsp = { enabled = true },
        neotree = true,
        bufferline = true,
        noice = true,
        gitsigns = true,
        cmp = true,
        mason = true,
        lsp_trouble = true,
        dap = true,
        dap_ui = true,
        markdown = true,
        semantic_tokens = true,
        which_key = true,
      },
    })
  end,
}
