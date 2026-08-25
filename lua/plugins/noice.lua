return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    -- add any options here
  },
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    "MunifTanjim/nui.nvim",
    -- OPTIONAL:
--   `nvim-notify` is only needed, if you want to use the notification view.
    --   If not available, we use `mini` as the fallback
    "rcarriga/nvim-notify",
  },
  config = function()
    -- noice's cmdline UI loses the visual selection: while the cmdline is
    -- open the selection is still active, but any repaint of the buffer
    -- draws it unhighlighted (folke/noice.nvim#478, closed not-planned).
    -- Stock Neovim keeps drawing it. The repaint always happens for a
    -- selection made with G past the viewport, because `:` from visual mode
    -- scrolls the view back to the range start. Re-apply the region as
    -- extmarks for the duration of the cmdline -- decorations survive the
    -- repaints the native visual-area drawing does not. Uses the Visual
    -- group itself, so theme.lua's pinned colour applies unchanged.
    -- Event order for `:` from visual (verified with an event logger) is
    --   ModeChanged V:n  ->  CmdlineEnter (mode already "c")  ->  ModeChanged n:c
    -- so no visual->cmdline ModeChanged ever fires, and by CmdlineEnter the
    -- anchor is gone (getpos("v") == cursor, both already moved to the range
    -- start). The region therefore has to be tracked while visual mode is
    -- live -- same approach as moyiz/command-and-cursor.nvim. V:n alone is
    -- ambiguous (plain <Esc> fires it too); what distinguishes `:` is that
    -- CmdlineEnter follows within the same input batch, before scheduled
    -- callbacks run -- hence the left_visual flag with a scheduled reset.
    local ns = vim.api.nvim_create_namespace("visual_in_cmdline")
    local group = vim.api.nvim_create_augroup("visual_in_cmdline", { clear = true })
    local region -- { srow, scol, erow, ecol, regtype } 0-indexed, or nil
    local left_visual = false
    local marked_buf

    local function track()
      local mode = vim.fn.mode()
      if not mode:match("^[vV\22]") then return end
      local srow, scol = unpack(vim.api.nvim_win_get_cursor(0))
      srow = srow - 1
      local erow, ecol = vim.fn.line("v") - 1, vim.fn.col("v") - 1
      if srow > erow then
        srow, erow, scol, ecol = erow, srow, ecol, scol
      end
      if srow == erow and scol > ecol then
        scol, ecol = ecol, scol
      end
      local regtype = mode
      if mode == "V" then
        scol, ecol = 0, #vim.fn.getline(erow + 1)
      elseif mode == "\22" then
        if scol > ecol then scol, ecol = ecol, scol end
        regtype = regtype .. (ecol - scol + 1)
      end
      region = { srow, scol, erow, ecol, regtype }
    end

    vim.api.nvim_create_autocmd("ModeChanged", {
      group = group,
      pattern = "*:[vV\22]*", -- entering any visual mode
      callback = track,
    })
    vim.api.nvim_create_autocmd("CursorMoved", { group = group, callback = track })

    vim.api.nvim_create_autocmd("ModeChanged", {
      group = group,
      pattern = "[vV\22]*:n*", -- leaving visual: either <Esc> or the start of `:`
      callback = function()
        left_visual = true
        vim.schedule(function() left_visual = false end)
      end,
    })

    vim.api.nvim_create_autocmd("CmdlineEnter", {
      group = group,
      callback = function(ev)
        if not (left_visual and region) then return end
        left_visual = false
        vim.hl.range(ev.buf, ns, "Visual",
          { region[1], region[2] }, { region[3], region[4] },
          {
            regtype = region[5],
            inclusive = vim.o.selection ~= "exclusive",
            priority = vim.hl.priorities.user,
          })
        marked_buf = ev.buf
        -- The bare repaint (view jumping to the range start) has already
        -- happened by now, and the idle cmdline never repaints again on its
        -- own -- without this the extmarks may never reach the screen.
        vim.cmd("redraw")
      end,
    })
    vim.api.nvim_create_autocmd("CmdlineLeave", {
      group = group,
      callback = function()
        if marked_buf and vim.api.nvim_buf_is_valid(marked_buf) then
          vim.api.nvim_buf_clear_namespace(marked_buf, ns, 0, -1)
        end
        marked_buf = nil
      end,
    })

    -- Display "CmdLine" and "Popupmenu" together.
    require("noice").setup({
      lsp = {
        -- Use native handlers for both so our lsp_float_opts winhighlight applies
        hover = { enabled = false },
        signature = { enabled = false },
      },
      views = {
        cmdline_popup = {
          position = {
            row = 5,
            col = "50%",
          },
          size = {
            width = 60,
            height = "auto",
          },
        },
        popupmenu = {
          relative = "editor",
          position = {
            row = 8,
            col = "50%",
          },
          size = {
            width = 60,
            height = 10,
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
          win_options = {
            winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
          },
        },
      },
    })
  end
}

