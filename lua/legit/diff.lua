local M = {}

local git = require("legit.git")

function M.open(file)
	local root_out = vim.fn.systemlist("git rev-parse --show-toplevel")
	local root = (vim.v.shell_error == 0 and root_out[1] or vim.fn.getcwd()):gsub("/$", "")
	local abs_file = root .. "/" .. file

	local orig, ok = git.run("show HEAD:" .. vim.fn.shellescape(file))
	if not ok then
		orig, ok = git.run("show :" .. vim.fn.shellescape(file))
		if not ok then
			vim.notify("[legit] no committed version found for " .. file, vim.log.levels.WARN)
			return
		end
	end

	require("legit.window").close()

	vim.cmd("edit " .. vim.fn.fnameescape(abs_file))
	local file_win = vim.api.nvim_get_current_win()
	local ft = vim.bo.filetype

	vim.cmd("leftabove vertical new")
	local orig_buf = vim.api.nvim_get_current_buf()
	local orig_win = vim.api.nvim_get_current_win()

	vim.bo[orig_buf].modifiable = true
	vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, orig)
	vim.bo[orig_buf].modifiable = false
	vim.bo[orig_buf].buftype = "nofile"
	vim.bo[orig_buf].bufhidden = "wipe"
	vim.bo[orig_buf].swapfile = false
	vim.bo[orig_buf].filetype = ft
	vim.api.nvim_buf_set_name(orig_buf, "HEAD:" .. file)

	vim.cmd("diffthis")
	vim.api.nvim_set_current_win(file_win)
	vim.cmd("diffthis")

	local function close()
		vim.cmd("diffoff!")
		if vim.api.nvim_win_is_valid(orig_win) then
			vim.api.nvim_win_close(orig_win, true)
		end
	end

	local o = { silent = true, nowait = true }
	vim.keymap.set("n", "q", close, vim.tbl_extend("force", o, { buffer = orig_buf }))
end

return M
