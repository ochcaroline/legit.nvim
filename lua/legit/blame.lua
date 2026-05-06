local M = {}

local git = require("legit.git")

local state = {
	blame_win = nil,
	blame_buf = nil,
	main_win = nil,
	main_buf = nil,
	augroup = nil,
	syncing = false,
}

local function trim_blame_line(line)
	return line:match("^(.-%))") or line
end

function M.close()
	if state.augroup then
		vim.api.nvim_del_augroup_by_id(state.augroup)
		state.augroup = nil
	end
	if state.blame_win and vim.api.nvim_win_is_valid(state.blame_win) then
		vim.api.nvim_win_close(state.blame_win, true)
	end
	state.blame_win = nil
	state.blame_buf = nil
	state.main_win = nil
	state.main_buf = nil
end

function M.open()
	local file = vim.fn.expand("%:p")
	if file == "" then
		vim.notify("[legit] no file in current buffer", vim.log.levels.WARN)
		return
	end

	if state.blame_win and vim.api.nvim_win_is_valid(state.blame_win) then
		M.close()
		return
	end

	local raw, ok = git.blame(file)
	if not ok or #raw == 0 then
		vim.notify("[legit] git blame failed", vim.log.levels.ERROR)
		return
	end

	local lines = vim.tbl_map(trim_blame_line, raw)

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.min(width + 1, 55)

	state.main_win = vim.api.nvim_get_current_win()
	state.main_buf = vim.api.nvim_get_current_buf()
	local current_line = vim.fn.line(".")

	vim.cmd("topleft vertical " .. width .. " new")

	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	state.blame_buf = buf
	state.blame_win = win

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "legit-blame"
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].wrap = false
	vim.wo[win].winhighlight = "Normal:NormalFloat,CursorLine:Visual"
	vim.wo[win].cursorline = true

	vim.api.nvim_set_current_win(state.main_win)
	local target = math.min(current_line, #lines)
	vim.api.nvim_win_set_cursor(state.blame_win, { target, 0 })

	vim.keymap.set("n", "q", M.close, { buffer = buf, silent = true, nowait = true })

	state.augroup = vim.api.nvim_create_augroup("LegitBlame", { clear = true })

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = state.augroup,
		buffer = state.main_buf,
		callback = function()
			if state.syncing then
				return
			end
			if not (state.blame_win and vim.api.nvim_win_is_valid(state.blame_win)) then
				M.close()
				return
			end
			state.syncing = true
			local line = vim.api.nvim_win_get_cursor(0)[1]
			local total = vim.api.nvim_buf_line_count(state.blame_buf)
			vim.api.nvim_win_set_cursor(state.blame_win, { math.min(line, total), 0 })
			state.syncing = false
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = state.augroup,
		callback = function(ev)
			local closed = tonumber(ev.match)
			if closed == state.blame_win or closed == state.main_win then
				vim.schedule(M.close)
			end
		end,
	})
end

return M
