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
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
        },
      },
    })

    vim.keymap.set('n', '<C-n>', ':Neotree filesystem toggle reveal left <CR>')
  end
}

