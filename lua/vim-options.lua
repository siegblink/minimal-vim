vim.opt.termguicolors = true
vim.opt.splitright = true
vim.cmd("set number")
vim.cmd("set relativenumber")
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.g.mapleader = " "

-- Navigate vim panes better
vim.keymap.set("n", "<c-k>", ":wincmd k<CR>")
vim.keymap.set("n", "<c-j>", ":wincmd j<CR>")
vim.keymap.set("n", "<c-h>", ":wincmd h<CR>")
vim.keymap.set("n", "<c-l>", ":wincmd l<CR>")

-- Toggle keyword highlight off
vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>")

-- Terminal keybindings
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>")

-- Auto-enter terminal mode whenever a terminal buffer is focused
-- (snacks terminal toggle re-shows the buffer without calling startinsert)
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "term://*",
  callback = function()
    vim.cmd("startinsert")
  end,
})

-- Use system clipboard as the default register
vim.opt.clipboard = "unnamed,unnamedplus"

-- Disable LSP inline color swatches globally (noisy in non-CSS files)
-- document_color was added in Neovim 0.12; guard for older builds
if vim.lsp.document_color then
  vim.lsp.document_color.enable(false)
end

-- Neovim 0.12 + archived nvim-treesitter: query_predicates.lua crashes when
-- treesitter tries to resolve injections in LSP hover buffers (nil-node from
-- match[id] now being a list). Stop treesitter on the buffer right after
-- stylize_markdown starts it, before the first render triggers the crash.
local _orig_stylize = vim.lsp.util.stylize_markdown
vim.lsp.util.stylize_markdown = function(bufnr, contents, opts)
  local result = _orig_stylize(bufnr, contents, opts)
  pcall(vim.treesitter.stop, bufnr)
  return result
end

-- Neovim 0.12: open_floating_preview silently drops `winhighlight` from opts
-- because it is a window-local option, not an nvim_open_win config key.
-- Wrap it to apply winhighlight to the window after creation.
local _orig_open_floating = vim.lsp.util.open_floating_preview
vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
  local bufnr, winid = _orig_open_floating(contents, syntax, opts)
  if winid and opts and opts.winhighlight then
    vim.wo[winid].winhighlight = opts.winhighlight
  end
  return bufnr, winid
end
