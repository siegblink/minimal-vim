local M = {}

-- Launch-command resolution for the TypeScript 7 native LSP.
-- Preference order: the project's own stable compiler (typescript >= 7 ships
-- `tsc`, which serves LSP via `tsc --lsp --stdio`), then a project-local
-- preview install (`@typescript/native-preview` ships `tsgo`), then the
-- global `tsgo` from Mason's bin path.
---@param root_dir string|nil
---@return string[] argv
function M.resolve(root_dir)
	if root_dir then
		local local_tsc = vim.fs.joinpath(root_dir, "node_modules/.bin/tsc")
		local pkg_json = vim.fs.joinpath(root_dir, "node_modules/typescript/package.json")
		local ok, pkg = pcall(function()
			return vim.json.decode(table.concat(vim.fn.readfile(pkg_json), "\n"))
		end)
		local major = ok
				and type(pkg) == "table"
				and type(pkg.version) == "string"
				and tonumber(pkg.version:match("^(%d+)"))
			or nil
		if major and major >= 7 and vim.fn.executable(local_tsc) == 1 then
			return { local_tsc, "--lsp", "--stdio" }
		end

		local local_tsgo = vim.fs.joinpath(root_dir, "node_modules/.bin/tsgo")
		if vim.fn.executable(local_tsgo) == 1 then
			return { local_tsgo, "--lsp", "--stdio" }
		end
	end
	return { "tsgo", "--lsp", "--stdio" }
end

return M
