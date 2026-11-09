-- Dark half of the light/dark pair (catppuccin.lua is the light half).
--
-- This file no longer calls `colorscheme` and no longer sets the float
-- highlights. lua/theme.lua picks the scheme from the system appearance
-- (macOS, or GNOME's color-scheme on Linux) and owns every mode-dependent
-- colour, so both halves get identical treatment and switching can't leave a
-- stale highlight behind.
return {
  "oxfist/night-owl.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("night-owl").setup()
  end,
}
