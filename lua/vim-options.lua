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
vim.lsp.document_color.enable(false)
