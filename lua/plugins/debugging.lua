return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"rcarriga/nvim-dap-ui",
		"mfussenegger/nvim-dap",
		"nvim-neotest/nvim-nio",
		"theHamsta/nvim-dap-virtual-text",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

    dapui.setup()
		require("nvim-dap-virtual-text").setup() -- inline variable values while stepping

		dap.listeners.before.attach.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.launch.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated.dapui_config = function()
			dapui.close()
		end
		dap.listeners.before.event_exited.dapui_config = function()
			dapui.close()
		end

		-- C/C++ step debugging through codelldb (Mason package, shared with
		-- Rust). This is the same server-mode adapter rustaceanvim builds for
		-- itself; it only creates dap.adapters.codelldb when nothing else has,
		-- so :RustLsp debuggables keeps working unchanged.
		dap.adapters.codelldb = {
			type = "server",
			host = "127.0.0.1",
			port = "${port}",
			executable = {
				command = "codelldb",
				args = { "--port", "${port}" },
			},
		}

		-- <leader>dc in a C file. Build with debug info first, e.g.
		-- `cc -g -O0 main.c -o main`; the prompt defaults to that output name.
		dap.configurations.c = {
			{
				name = "Launch executable",
				type = "codelldb",
				request = "launch",
				program = function()
					local path = vim.fn.input({
						prompt = "Executable: ",
						default = vim.fn.expand("%:p:r"),
						completion = "file",
					})
					return path ~= "" and path or dap.ABORT
				end,
				args = function()
					return require("dap.utils").splitstr(vim.fn.input("Arguments: "))
				end,
				cwd = "${workspaceFolder}",
				stopOnEntry = false,
				-- A real terminal (the dap-ui console) so programs reading stdin work.
				terminal = "integrated",
			},
		}
		dap.configurations.cpp = dap.configurations.c

		vim.keymap.set("n", "<Leader>dt", ":DapToggleBreakpoint<CR>")
		vim.keymap.set("n", "<Leader>dc", ":DapContinue<CR>")
		vim.keymap.set("n", "<Leader>dx", ":DapTerminate<CR>")
		vim.keymap.set("n", "<Leader>do", ":DapStepOver<CR>")
		vim.keymap.set("n", "<Leader>di", ":DapStepInto<CR>")
		vim.keymap.set("n", "<Leader>dO", ":DapStepOut<CR>")
		vim.keymap.set("n", "<Leader>dr", ":DapToggleRepl<CR>")
		vim.keymap.set("n", "<Leader>dl", ":DapRunLast<CR>")
	end,
}
