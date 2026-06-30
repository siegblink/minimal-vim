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

    -- Keep neo-tree's git status fresh after changes made outside Neovim.
    -- Lazygit (and friends) mutate .git/index from a separate process, so a
    -- pure `git add` is invisible to neo-tree until we ask it to re-scan.
    -- refresh("filesystem") is safe even when neo-tree is closed: it just
    -- marks the state dirty so the next open re-scans.
    local function refresh_git_status()
      require("neo-tree.sources.manager").refresh("filesystem")
    end

    -- Grouped + cleared so re-sourcing the config never stacks duplicates.
    local git_refresh = vim.api.nvim_create_augroup("neotree_git_refresh", { clear = true })

    -- Quitting lazygit (<leader>lg) or any Snacks terminal (<leader>t) exits a
    -- terminal job. Defer so the re-scan runs after the buffer tears down.
    vim.api.nvim_create_autocmd("TermClose", {
      group = git_refresh,
      callback = function()
        vim.schedule(refresh_git_status)
      end,
    })

    -- Returning to Neovim from another app (e.g. staging in a separate
    -- terminal) regains focus: re-scan so the tree is never stale.
    vim.api.nvim_create_autocmd("FocusGained", {
      group = git_refresh,
      callback = refresh_git_status,
    })
  end
}

