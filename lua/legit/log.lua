local M = {}

local window = require("legit.window")
local git = require("legit.git")

function M.open()
	local lines, ok = git.log(50)
	if not ok then
		vim.notify("[legit] not a git repository", vim.log.levels.ERROR)
		return
	end

	local header = {
		" Git Log   q / <Esc> close",
		" ─────────────────────────────────────────────────",
	}
	vim.list_extend(header, lines)

	local buf, win = window.open(header, { title = "legit log" })
	vim.bo[buf].filetype = "legit-log"
	vim.api.nvim_win_set_cursor(win, { 3, 0 })
end

return M
