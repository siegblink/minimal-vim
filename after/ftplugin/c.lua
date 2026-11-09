-- Buffer-local C keymaps. They apply to C++ too: Neovim's ftplugin/cpp.vim
-- sources every ftplugin/c.{vim,lua} on the runtimepath, this file included.

-- Man page for the word under the cursor, searching system calls (2), then
-- the C library (3), then commands (1). Plain :Man resolves printf to the
-- shell command's page, printf(1). On Debian/Ubuntu, sections 2 and 3 come
-- from the manpages-dev package.
local function man_under_cursor()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end
	local saved = vim.env.MANSECT
	vim.env.MANSECT = "2:3:1"
	local ok, err = pcall(vim.cmd.Man, word)
	vim.env.MANSECT = saved
	if not ok then
		vim.notify((tostring(err):gsub("^Vim:", "")), vim.log.levels.WARN)
	end
end

-- :LspClangdSwitchSourceHeader comes from nvim-lspconfig and only exists
-- once clangd has attached to the buffer.
local function switch_source_header()
	if vim.fn.exists(":LspClangdSwitchSourceHeader") == 2 then
		vim.cmd.LspClangdSwitchSourceHeader()
	else
		vim.notify("clangd is not attached to this buffer", vim.log.levels.WARN)
	end
end

local function toggle_inlay_hints()
	local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
	vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
end

vim.keymap.set("n", "<leader>cm", man_under_cursor, { buffer = true, desc = "C: man page for word under cursor" })
vim.keymap.set("n", "<leader>ch", switch_source_header, { buffer = true, desc = "C: switch source/header" })
vim.keymap.set("n", "<leader>ci", toggle_inlay_hints, { buffer = true, desc = "C: toggle inlay hints" })

-- Each unmap goes through `exe`: a map command reads the space before a '|'
-- as part of its {lhs} (:help map-trailing-white), so `nunmap <buffer> x |`
-- tries to unmap "x " and silently misses. That includes the last one, since
-- cpp.vim appends ' | setl commentstring<' after sourcing this file.
local undo = 'silent! exe "nunmap <buffer> <leader>cm" | silent! exe "nunmap <buffer> <leader>ch"'
	.. ' | silent! exe "nunmap <buffer> <leader>ci"'
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
