-- Snacks' auto_close keeps a terminal float OPEN when its process exits with a
-- non-zero status (it shows an error notification instead), so failed output
-- stays visible. For the interactive <leader>t shell that backfires: a bare
-- `exit` inherits the previous command's exit code, so quitting after any
-- failed command would leave the float stuck on "[Process exited 1]". Disable
-- snacks' status-gated handler for this terminal and close it unconditionally.
local function toggle_terminal()
  Snacks.terminal(nil, {
    auto_close = false,
    win = {
      on_buf = function(self)
        vim.api.nvim_create_autocmd("TermClose", {
          buffer = self.buf,
          callback = function()
            self:close()
            vim.cmd.checktime()
          end,
        })
      end,
    },
  })
end

return {
  "folke/snacks.nvim",
  dependencies = {
    "echasnovski/mini.icons",
  },
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = {
      enabled = true
    },
    dashboard = {
      enabled = true,
      preset = {
        header = [[
                                                                     
       ████ ██████           █████      ██                     
      ███████████             █████                             
      █████████ ███████████████████ ███   ███████████   
     █████████  ███    █████████████ █████ ██████████████   
    █████████ ██████████ █████████ █████ █████ ████ █████   
  ███████████ ███    ███ █████████ █████ █████ ████ █████  
 ██████  █████████████████████ ████ █████ █████ ████ ██████ 
        ]],
      },
    },
    indent = { enabled = true, scope = { treesitter = { enabled = false } } },
    input = { enabled = true },
    git = { enabled = true },
    lazygit = {
      -- snacks generates its own lazygit config and appends it to
      -- LG_CONFIG_FILE, so it overrides ~/.config/lazygit/config.yml whenever
      -- lazygit is opened from inside Neovim. Every key is therefore repointed
      -- at a Lazygit* group owned by lua/theme.lua, which carries the same
      -- values the standalone config uses -- otherwise the same lazygit looks
      -- different inside and outside the editor.
      --
      -- The defaults this replaces were not merely different, two were wrong:
      -- selectedLineBgColor mapped to Visual, whose `bg` sometimes resolved as
      -- absent, and snacks then wrote the key with NO value, so the selected
      -- commit had no highlight at all; activeBorderColor mapped to MatchParen,
      -- which is orange in the light half against the standalone config's blue.
      theme = {
        activeBorderColor = { fg = "LazygitActiveBorder", bold = true },
        inactiveBorderColor = { fg = "LazygitInactiveBorder" },
        searchingActiveBorderColor = { fg = "LazygitSearchingBorder", bold = true },
        optionsTextColor = { fg = "LazygitOptionsText" },
        selectedLineBgColor = { fg = "LazygitSelectedLine" },
        cherryPickedCommitFgColor = { fg = "LazygitCherryPickedFg" },
        cherryPickedCommitBgColor = { fg = "LazygitCherryPickedBg" },
        unstagedChangesColor = { fg = "LazygitUnstaged" },
        defaultFgColor = { fg = "LazygitDefaultFg" },
      },
      win = {
        position = "float",
        border = "rounded",
        width = 0.9,
        height = 0.9,
        wo = { winhighlight = "Normal:Normal,FloatBorder:TermFloat" },
      },
    },
    picker = { enabled = true },
    notifier = { enabled = true },
    quickfile = { enabled = true, exclude = { "latex", "markdown" } },
    scroll = { enabled = false },
    scope = { enabled = true, treesitter = { enabled = false } },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    terminal = {
      enabled = true,
      win = {
        position = "float",
        border = "rounded",
        width = 0.9,
        height = 0.9,
        wo = { winhighlight = "Normal:Normal,FloatBorder:TermFloat" },
      },
    },
  },
  keys = {
    { "<leader>sf",       function() Snacks.scratch() end,            desc = "Toggle Scratch Buffer" },
    { "<leader>S",        function() Snacks.scratch.select() end,     desc = "Select Scratch Buffer" },
    { "<leader>gl",       function() Snacks.lazygit.log_file() end,   desc = "Lazygit Log (cwd)" },
    { "<leader>lg",       function() Snacks.lazygit() end,            desc = "Lazygit" },
    { "<C-p>",            function() Snacks.picker.pick("files") end, desc = "Find Files" },
    { "<leader><leader>", function() Snacks.picker.recent() end,      desc = "Recent Files" },
    { "<leader>fb",       function() Snacks.picker.buffers() end,     desc = "Buffers" },
    { "<leader>fg",       function() Snacks.picker.grep() end,        desc = "Grep Files" },
    { "<leader>t",        toggle_terminal,                            desc = "Toggle Terminal" },
    -- { "<C-n>",            function() Snacks.explorer() end,           desc = "Explorer" },
  }
}
