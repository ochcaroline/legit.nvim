local M = {}

local state = {
	win = nil,
}

local function new_buf(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	return buf
end

-- Fill the legit window with `lines`.
-- opts:
--   title   string   shown in statusline
--   on_back fn       called on <Esc>; defaults to M.close
-- Returns buf, win.
function M.open(lines, opts)
	opts = opts or {}

	local buf = new_buf(lines)

	if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
		-- Open a vertical split on the right, half the screen width.
		local width = math.floor(vim.o.columns * 0.5)
		vim.cmd("botright vertical " .. width .. " split")
		state.win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_win_set_buf(state.win, buf)

	vim.wo[state.win].number = false
	vim.wo[state.win].relativenumber = false
	vim.wo[state.win].signcolumn = "no"
	vim.wo[state.win].wrap = false
	vim.wo[state.win].statusline = "  " .. (opts.title or "legit")

	local back = opts.on_back or M.close
	local o = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", M.close, o)
	vim.keymap.set("n", "<Esc>", back, o)

	return buf, state.win
end

function M.close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win = nil
end

function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.get_win()
	return state.win
end

return M
