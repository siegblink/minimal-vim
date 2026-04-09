-- Neovim 0.12 ships a built-in ftplugin/markdown.lua that calls vim.treesitter.start()
-- unconditionally. This overrides it since the markdown treesitter parser has a
-- compatibility issue with the injection processing API in 0.12.1.
vim.treesitter.stop()
