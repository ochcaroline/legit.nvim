local M = {}

local window = require("legit.window")
local git = require("legit.git")

local function get_help()
	local current_branch = git.get_current_branch()
	return { "#", "# <leader>gc to commit  |  q to abort", "# " .. current_branch }
end

local function git_dir()
	local out = vim.fn.systemlist("git rev-parse --git-dir")
	return vim.v.shell_error == 0 and out[1] or nil
end

local function strip_comments(lines)
	local out = {}
	for _, l in ipairs(lines) do
		if not l:match("^#") then
			table.insert(out, l)
		end
	end
	while #out > 0 and out[#out] == "" do
		out[#out] = nil
	end
	return out
end

function M.open(on_done)
	local dir = git_dir()
	if not dir then
		vim.notify("[legit] not a git repository", vim.log.levels.ERROR)
		return
	end

	local editmsg = dir .. "/COMMIT_EDITMSG"

	-- Always start with blank message; don't restore stale COMMIT_EDITMSG
	-- (git recreates this file after each commit, causing unwanted persistence)
	local lines = { "" }
	table.insert(lines, "")
	vim.list_extend(lines, get_help())

	local function abort()
		window.close()
		if on_done then
			on_done(false)
		end
	end

	local buf, win = window.open(lines, { title = "legit commit", no_escape = true })

	vim.bo[buf].modifiable = true
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "gitcommit"

	vim.api.nvim_win_set_cursor(win, { 1, 0 })

	local function do_commit()
		local msg_lines = strip_comments(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		while #msg_lines > 0 and msg_lines[1] == "" do
			table.remove(msg_lines, 1)
		end

		if #msg_lines == 0 then
			vim.notify("[legit] empty commit message, aborted", vim.log.levels.WARN)
			return
		end

		vim.fn.writefile(msg_lines, editmsg)
		local out, ok = git.run("commit -F " .. vim.fn.shellescape(editmsg))
		vim.notify(table.concat(out, "\n"), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
		-- Clean up after successful commit
		if ok then
			vim.fn.delete(editmsg)
		end
		window.close()
		if on_done then
			on_done(ok)
		end
	end

	local o = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "<leader>gc", do_commit, vim.tbl_extend("force", o, { desc = "Commit" }))
	vim.keymap.set("n", "q", abort, vim.tbl_extend("force", o, { desc = "Abort commit" }))
end

return M
