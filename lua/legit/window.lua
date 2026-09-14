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
--   title      string   shown in statusline
--   on_back    fn       called on <Esc>; defaults to M.close
--   no_escape  bool     if true, don't set <Esc> binding
-- Returns buf, win.
function M.open(lines, opts)
	opts = opts or {}

	local buf = new_buf(lines)

	if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
		local width = math.floor(vim.api.nvim_win_get_height(0) * 0.5)
		vim.cmd("aboveleft " .. width .. " split")
		state.win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_win_set_buf(state.win, buf)

	vim.wo[state.win].number = false
	vim.wo[state.win].relativenumber = false
	vim.wo[state.win].signcolumn = "no"
	vim.wo[state.win].wrap = false
	local title = opts.title or "legit"
	local prefix_width = vim.api.nvim_strwidth("  " .. title .. "  ")
	vim.wo[state.win].statusline = "%#LegitBorder#  " .. title .. "  %{repeat('─', max([0, winwidth(0) - " .. prefix_width .. "]))}"
	vim.wo[state.win].winhighlight = "StatusLine:LegitBorder,StatusLineNC:LegitBorder"

	vim.api.nvim_set_hl(0, "LegitBorder", {
		fg = "#444444",
		bg = "NONE",
	})

	local back = opts.on_back or M.close
	local o = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", M.close, o)
	if not opts.no_escape then
		vim.keymap.set("n", "<Esc>", back, o)
	end

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
