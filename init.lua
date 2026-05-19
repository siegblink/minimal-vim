-- Ensure the highest installed nvm Node.js is always available for LSPs,
-- regardless of which version the shell had active when nvim was opened.
local function find_highest_nvm_node()
  local versions_dir = vim.fn.expand("~/.nvm/versions/node")

  if vim.fn.isdirectory(versions_dir) == 0 then
    return nil
  end

  local dirs = vim.fn.glob(versions_dir .. "/v*", false, true)

  if #dirs == 0 then
    return nil
  end

  local function parse_semver(path)
    local dirname = vim.fn.fnamemodify(path, ":t")
    local major, minor, patch = dirname:match("v(%d+)%.(%d+)%.(%d+)")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
  end

  table.sort(dirs, function(a, b)
    local a1, a2, a3 = parse_semver(a)
    local b1, b2, b3 = parse_semver(b)
    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    return a3 > b3
  end)

  return dirs[1] .. "/bin"
end

local nvm_node_bin = find_highest_nvm_node()
if nvm_node_bin then
  vim.env.PATH = nvm_node_bin .. ":" .. vim.env.PATH
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local opts = {}

-- Initiliaze all custom options and plugins
require("vim-options")
require("lazy").setup("plugins")

-- Make the statusline span the entire width of the editor 
vim.opt.laststatus = 3

-- Synchronize unnamed register with the system's clipboard register
vim.opt.clipboard = "unnamedplus"

