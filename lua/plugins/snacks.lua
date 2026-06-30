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
