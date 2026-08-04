-- Central light/dark switch.
--
-- The desktop appearance is the single source of truth for the whole terminal
-- stack -- macOS System Settings, or the GNOME color-scheme on Linux:
--   Ghostty  follows it natively (theme = light:...,dark:... in its config)
--   delta    follows via `git config --global delta.features night-owl-{light,dark}`
--   lazygit  inherits delta's colours
--   Neovim   follows via this module
-- `~/.scripts/theme` flips all of them at once.
--
-- This module is shared by both machines, so it must never assume macOS.
-- detect_cmd() below dispatches per platform, and sync() still lands on a
-- scheme when no detector exists at all.
--
-- Colours this config sets by hand -- floats, neo-tree, bufferline -- live in
-- M.palette so there is exactly one place to edit per mode. They are re-applied
-- on every ColorScheme event, so switching never leaves a stale highlight
-- behind and re-sourcing the config is idempotent.

local M = {}

M.schemes = {
  dark = "night-owl",
  light = "catppuccin-latte",
}

M.palette = {
  dark = {
    float_bg = "#011627",
    float_fg = "#d6deeb",
    float_border = "#637777",
    float_title = "#7fdbca",
    lsp_border = "#82aaff",
    neotree_cursorline = "#1d3b53",

    bl_fill = "#010d18",
    bl_inactive_bg = "#01111d",
    bl_active_bg = "#0b2942",
    bl_inactive_fg = "#4b6479",
    bl_visible_fg = "#5f7e97",
    bl_active_fg = "#c5e4fc",
    bl_indicator = "#82aaff",
    bl_modified = "#c5e478",
    bl_duplicate_sel = "#7fdbca",

    -- lazygit, via snacks. Keep in step with set_lazygit() in
    -- dotfiles/dot_scripts/executable_theme -- that config serves the
    -- standalone TUI, these groups serve the one snacks opens, and they must
    -- agree or the same lazygit looks different inside and outside the editor.
    lg_active = "#88a3d9",
    lg_inactive = "#4b6479",
    lg_searching = "#d2b189",
    lg_options = "#80908f",
    lg_selected = "#1d3b53",
    lg_cherry_fg = "#88a3d9",
    lg_cherry_bg = "#1d3b53",
    lg_unstaged = "#c07a73",
    lg_default_fg = "#b5bcc5",

    -- ANSI palette for :terminal buffers, identical to the Ghostty theme of
    -- the same name so a TUI renders the same inside the editor and outside
    -- it. See the light half for why this has to be set per mode.
    term = {
      "#011627", "#EF5350", "#22da6e", "#addb67",
      "#82aaff", "#c792ea", "#21c7a8", "#ffffff",
      "#5f7e97", "#ef5350", "#22da6e", "#ffeb95",
      "#82aaff", "#c792ea", "#7fdbca", "#ffffff",
    },
  },

  -- Shares #f2f2f3 with the Ghostty theme, so the editor and the terminal
  -- around it are literally the same surface. Every foreground below clears
  -- WCAG AA against it.
  light = {
    float_bg = "#e8e8ec",
    float_fg = "#403f53",
    float_border = "#696e84",
    float_title = "#146e73",
    lsp_border = "#2153b8",
    neotree_cursorline = "#dbe7f0",

    bl_fill = "#e2e2e7",
    bl_inactive_bg = "#eaeaee",
    bl_active_bg = "#f2f2f3",
    bl_inactive_fg = "#696e84",
    bl_visible_fg = "#5e6072",
    bl_active_fg = "#403f53",
    bl_indicator = "#2153b8",
    bl_modified = "#2f751f",
    bl_duplicate_sel = "#146e73",

    lg_active = "#2153b8",
    lg_inactive = "#696e84",
    lg_searching = "#96631b",
    lg_options = "#696e84",
    lg_selected = "#bfd6ee",
    lg_cherry_fg = "#2153b8",
    lg_cherry_bg = "#bfd6ee",
    lg_unstaged = "#a51d3a",
    lg_default_fg = "#403f53",

    -- MUST be set per mode. catppuccin runs with term_colors = false and
    -- night-owl never clears these, so before this existed a switch to light
    -- left night-owl's DARK ANSI palette in place: ANSI yellow stayed
    -- #ffd602, which is 1.77:1 on the float background -- lazygit's ahead
    -- markers and git's commit line were effectively unreadable.
    --
    -- Derived from Ghostty's "Night Owlish Light", darkened where that palette
    -- fails WCAG AA against the float background (#e8e8ec, the harder of the
    -- two light grounds). 12 of 16 slots failed; hue is preserved throughout.
    -- Base slots target 5.6:1 and bright slots 4.6:1, so a bright stays
    -- visibly brighter than its base twin instead of collapsing into it --
    -- a flat target merged 2/10 into one colour.
    --
    -- Slots 0, 7 and 15 are left alone: in a light palette those are
    -- structural (backgrounds, light-on-dark foregrounds), not body text.
    term = {
      "#011627", "#b11d22", "#00665e", "#7e5100",
      "#2b56b2", "#403f53", "#006844", "#7a8181",
      "#626869", "#bb373d", "#00746c", "#7c6500",
      "#1a6ca5", "#5e658d", "#007744", "#989fb1",
    },
  },
}

---@return "light"|"dark"
function M.mode()
  return vim.o.background == "light" and "light" or "dark"
end

function M.colors()
  return M.palette[M.mode()]
end

-- Highlights the colourschemes don't set for us. Runs on ColorScheme, so both
-- night-owl and catppuccin get the same treatment.
function M.highlights()
  local c = M.colors()
  local hl = function(g, o) vim.api.nvim_set_hl(0, g, o) end

  -- Terminal ANSI. Only picked up by terminal buffers opened AFTER this runs,
  -- so an already-open lazygit keeps the old palette until reopened.
  for i, colour in ipairs(c.term) do
    vim.g["terminal_color_" .. (i - 1)] = colour
  end

  -- Groups that exist purely so snacks can resolve lazygit's theme from them
  -- (see lua/plugins/snacks.lua). snacks generates its own lazygit config and
  -- appends it to LG_CONFIG_FILE, so it overrides ~/.config/lazygit/config.yml
  -- inside the editor -- pointing it here is what keeps the two in agreement.
  --
  -- Each carries its colour in `fg`, including the selection: snacks' get_color
  -- just emits whichever channel it is told to read, and lazygit decides what
  -- the value means. Its default mapped selectedLineBgColor at Visual, whose
  -- `bg` it sometimes resolved as absent -- get_color then returns an empty
  -- list and the key is written with NO value, which lazygit reads as "no
  -- highlight". That is why the selected commit had no background at all.
  hl("LazygitActiveBorder", { fg = c.lg_active })
  hl("LazygitInactiveBorder", { fg = c.lg_inactive })
  hl("LazygitSearchingBorder", { fg = c.lg_searching })
  hl("LazygitOptionsText", { fg = c.lg_options })
  hl("LazygitSelectedLine", { fg = c.lg_selected })
  hl("LazygitCherryPickedFg", { fg = c.lg_cherry_fg })
  hl("LazygitCherryPickedBg", { fg = c.lg_cherry_bg })
  hl("LazygitUnstaged", { fg = c.lg_unstaged })
  hl("LazygitDefaultFg", { fg = c.lg_default_fg })

  -- All floats share the editor's float background; plugins inherit for free.
  hl("NormalFloat", { bg = c.float_bg, fg = c.float_fg })
  hl("FloatBorder", { bg = c.float_bg, fg = c.float_border })
  hl("FloatTitle", { bg = c.float_bg, fg = c.float_title, bold = true })

  -- Full-screen floats (terminal, lazygit); border colour used via
  -- winhighlight in snacks.lua
  hl("TermFloat", { bg = c.float_bg, fg = c.float_border })

  -- LSP and completion floats: same bg, brighter border
  hl("LspFloatBorder", { bg = c.float_bg, fg = c.lsp_border })

  hl("NeoTreeCursorLine", { bg = c.neotree_cursorline, bold = true })

  -- bufferline reads these groups directly, so setting them here means the
  -- tabline re-colours on switch without re-running bufferline.setup().
  hl("BufferLineFill", { bg = c.bl_fill })
  hl("BufferLineBackground", { fg = c.bl_inactive_fg, bg = c.bl_inactive_bg })
  hl("BufferLineBufferVisible", { fg = c.bl_visible_fg, bg = c.bl_inactive_bg })
  hl("BufferLineBufferSelected", { fg = c.bl_active_fg, bg = c.bl_active_bg, bold = true })
  hl("BufferLineTab", { fg = c.bl_inactive_fg, bg = c.bl_inactive_bg })
  hl("BufferLineTabSelected", { fg = c.bl_active_fg, bg = c.bl_active_bg, bold = true })
  hl("BufferLineTabClose", { fg = c.bl_inactive_fg, bg = c.bl_fill })
  hl("BufferLineCloseButton", { fg = c.bl_inactive_fg, bg = c.bl_inactive_bg })
  hl("BufferLineCloseButtonVisible", { fg = c.bl_visible_fg, bg = c.bl_inactive_bg })
  hl("BufferLineCloseButtonSelected", { fg = c.bl_active_fg, bg = c.bl_active_bg })
  hl("BufferLineSeparator", { fg = c.bl_fill, bg = c.bl_inactive_bg })
  hl("BufferLineSeparatorVisible", { fg = c.bl_fill, bg = c.bl_inactive_bg })
  hl("BufferLineSeparatorSelected", { fg = c.bl_fill, bg = c.bl_active_bg })
  hl("BufferLineIndicatorVisible", { fg = c.bl_inactive_bg, bg = c.bl_inactive_bg })
  hl("BufferLineIndicatorSelected", { fg = c.bl_indicator, bg = c.bl_active_bg })
  hl("BufferLineModified", { fg = c.bl_modified, bg = c.bl_inactive_bg })
  hl("BufferLineModifiedVisible", { fg = c.bl_modified, bg = c.bl_inactive_bg })
  hl("BufferLineModifiedSelected", { fg = c.bl_modified, bg = c.bl_active_bg })
  hl("BufferLineDuplicate", { fg = c.bl_inactive_fg, bg = c.bl_inactive_bg, italic = true })
  hl("BufferLineDuplicateVisible", { fg = c.bl_visible_fg, bg = c.bl_inactive_bg, italic = true })
  hl("BufferLineDuplicateSelected", { fg = c.bl_duplicate_sel, bg = c.bl_active_bg, italic = true })
end

--- Apply a mode. Idempotent; safe to call repeatedly.
---@param mode "light"|"dark"
function M.apply(mode)
  if mode ~= "light" and mode ~= "dark" then
    vim.notify(("theme: unknown mode %q"):format(tostring(mode)), vim.log.levels.WARN)
    return
  end
  M._gen = M._gen + 1
  vim.o.background = mode
  local scheme = M.schemes[mode]

  -- Colourschemes are expected to `highlight clear` on load, but night-owl.nvim
  -- doesn't on this path: colors/night-owl.lua calls theme.set_highlights()
  -- directly, while the clear lives in its config.setup(), which :colorscheme
  -- never reaches. Without an explicit clear, every group catppuccin defines
  -- and night-owl does not survives the switch.
  --
  -- NormalNC is the one that bites: Neovim paints *non-current* windows with
  -- it, and night-owl never defines it. Switching to dark with the cursor in
  -- neo-tree left the editor window on catppuccin's light background while
  -- Normal, the statusline and the tree were all correctly dark.
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  local ok, err = pcall(vim.cmd.colorscheme, scheme)
  if not ok then
    vim.notify(("theme: colorscheme %q failed: %s"):format(scheme, err), vim.log.levels.ERROR)
    return
  end

  -- night-owl.nvim never sets g:colors_name, so switching away from catppuccin
  -- leaves it nil. lualine's `auto` theme resolves by looking up
  -- lua/lualine/themes/<colors_name> -- and night-owl ships one -- so without
  -- this the statusline silently loses its palette on every switch.
  if vim.g.colors_name ~= scheme then
    vim.g.colors_name = scheme
  end

  -- lualine resolves `auto` once, at setup time. Re-run it so the statusline
  -- follows the switch. Guarded on package.loaded so this never force-loads
  -- lualine during early startup.
  if package.loaded["lualine"] then
    pcall(function() require("lualine").setup({}) end)
  end

  -- ColorScheme fires above and triggers M.highlights(); call directly too so
  -- this still works if the autocmd group was cleared.
  M.highlights()
end

function M.toggle()
  M.apply(M.mode() == "dark" and "light" or "dark")
end

-- Last system appearance we observed. sync() follows the system only when THIS
-- changes -- not merely when it differs from the editor -- so a manual :Theme
-- toggle isn't undone by the next FocusGained.
M._system = nil

-- Bumped by every apply(). A sync() callback that started before a manual
-- switch is stale by the time it resolves and must not clobber it.
M._gen = 0

--- The command that reports the desktop appearance on this platform, or nil if
--- we don't know how to ask. Both detectors report dark by the presence of
--- "dark" in stdout, so one parse rule covers them.
---
---   macOS  `defaults` only writes AppleInterfaceStyle when Dark; absent = Light
---   GNOME  `gsettings` reports 'prefer-dark' / 'prefer-light' / 'default'
---@return string[]|nil
local function detect_cmd()
  if vim.fn.has("mac") == 1 then
    return { "defaults", "read", "-g", "AppleInterfaceStyle" }
  end
  if vim.fn.executable("gsettings") == 1 then
    return { "gsettings", "get", "org.gnome.desktop.interface", "color-scheme" }
  end
  return nil
end

--- Read the system appearance and follow it.
--- Async (vim.system) so FocusGained never blocks on the subprocess.
---@param force boolean|nil apply even if the system value hasn't changed
function M.sync(force)
  local cmd = detect_cmd()
  local gen = M._gen

  -- No detector: headless, a non-GNOME desktop, an unknown platform. There is
  -- nothing to follow, but returning here is how the editor ends up with no
  -- scheme at all -- which is strictly worse than picking one. Note we cannot
  -- test `vim.g.colors_name` to decide whether that already happened:
  -- night-owl's plugin setup() sets it (and 'background') WITHOUT applying any
  -- highlights, so it reads "night-owl" while Neovim renders its own defaults.
  -- Same trap as cd0545dd. Only a forced call lands a scheme; an unforced one
  -- (FocusGained) has nothing to follow and harmlessly does nothing.
  if not cmd then
    if force then M.apply(M.mode()) end
    return
  end

  vim.system(cmd, { text = true }, function(res)
    local dark = res.code == 0 and (res.stdout or ""):lower():find("dark") ~= nil
    local mode = dark and "dark" or "light"
    vim.schedule(function()
      local prev = M._system
      M._system = mode

      -- System unchanged since we last looked: leave a manual choice alone.
      if not force and prev ~= nil and prev == mode then return end

      -- Raced with a manual switch while the subprocess was running.
      if not force and M._gen ~= gen then return end

      -- 'background' alone is NOT evidence that a scheme is loaded.
      -- night-owl's plugin setup() sets background=dark and g:colors_name
      -- without ever applying highlights -- those only land when
      -- colors/night-owl.lua is sourced. So on a dark system this used to see
      -- "already dark, nothing to do", skip apply(), and leave the editor on
      -- Neovim's cleared defaults. Check the actual scheme too.
      if force or mode ~= M.mode() or vim.g.colors_name ~= M.schemes[mode] then
        M.apply(mode)
      end
    end)
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("theme_custom_highlights", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function() M.highlights() end,
  })

  vim.api.nvim_create_user_command("Theme", function(o)
    local arg = (o.args ~= "" and o.args or "toggle"):lower()
    if arg == "toggle" then
      M.toggle()
    elseif arg == "system" then
      M.sync(true) -- explicit request: re-follow the system even if unchanged
    elseif arg == "light" or arg == "dark" then
      M.apply(arg)
    else
      vim.notify("theme: expected light | dark | toggle | system", vim.log.levels.WARN)
    end
  end, {
    nargs = "?",
    complete = function() return { "light", "dark", "toggle", "system" } end,
    desc = "Switch colourscheme: light | dark | toggle | system",
  })

  vim.keymap.set("n", "<leader>tt", function() M.toggle() end,
    { silent = true, desc = "Toggle light/dark theme" })

  -- Flipping macOS appearance (or running `theme` in a shell) updates Neovim
  -- the moment it regains focus.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("theme_follow_system", { clear = true }),
    callback = function() M.sync() end,
  })

  -- Initial state: whatever macOS is set to right now. force=true so startup
  -- always loads a scheme -- there is nothing sensible to leave in place, and
  -- skipping here is what left the editor on Neovim's defaults.
  M.sync(true)
end

return M
