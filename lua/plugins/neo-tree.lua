return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup({
      window = {
        mappings = {
          ["h"] = function(state)
            local node = state.tree:get_node()
            if node.type == "directory" and node:is_expanded() then
              require("neo-tree.sources.filesystem.commands").close_node(state)
            else
              local parent_id = node:get_parent_id()
              if parent_id then
                require("neo-tree.ui.renderer").focus_node(state, parent_id)
              end
            end
          end,
        },
      },
      filesystem = {
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
        },
      },
    })

    vim.keymap.set('n', '<C-n>', ':Neotree filesystem toggle reveal left <CR>')

    local function set_neotree_hl()
      vim.api.nvim_set_hl(0, "NeoTreeCursorLine", { bg = "#1d3b53", bold = true })
    end
    set_neotree_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_neotree_hl })

    vim.api.nvim_create_autocmd("BufEnter", {
      callback = function()
        if vim.fn.bufname() ~= "" then return end
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "neo-tree" then
            vim.api.nvim_win_set_cursor(win, { 1, 0 })
            return
          end
        end
      end,
    })
  end
}

