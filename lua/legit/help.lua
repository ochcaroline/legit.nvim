local M = {}

local function k(key)
	return key or "(unset)"
end

local function build_lines()
	local km = require("legit.config").keymaps
	return {
		" legit.nvim keybindings",
		" ──────────────────────────────────────────────",
		"",
		" Global",
		("   %-18s  Git status"):format(k(km.status)),
		("   %-18s  Git commit (opens editor)"):format(k(km.commit)),
		("   %-18s  Git push"):format(k(km.push)),
		("   %-18s  Git pull"):format(k(km.pull)),
		("   %-18s  Git log"):format(k(km.log)),
		("   %-18s  Git blame sidebar (toggle)"):format(k(km.blame)),
		("   %-18s  Git rebase"):format(k(km.rebase)),
		"",
		" Status window",
		"   s                   Stage file under cursor",
		"   u                   Unstage file under cursor",
		"   a                   Stage all  (unstage all if on Staged section)",
		"   x                   Discard changes (prompts)",
		"   d                   Unified diff  (<Esc> back to status)",
		"   D                   Side-by-side vimdiff",
		"   cc                  Open commit message editor",
		"   r                   Refresh",
		"   q / <Esc>           Close",
		"",
		" Commit editor",
		("   %-18s  Commit with current message"):format(k(km.commit)),
		"   q / <Esc>           Abort, return to status",
		"",
		" Diff (side-by-side)",
		"   q                   Close HEAD buffer + diffoff",
		"",
		" Blame sidebar",
		"   q                   Close blame",
		"",
		" press q or <Esc> to close this window",
	}
end

function M.open()
	local lines = build_lines()

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = width + 2
	local height = #lines
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " legit help ",
		title_pos = "center",
	})

	local ns = vim.api.nvim_create_namespace("legit_help")
	for i, line in ipairs(lines) do
		if line:match("^ %u") then
			vim.api.nvim_buf_add_highlight(buf, ns, "Title", i - 1, 0, -1)
		elseif line:match("^   %S") then
			local key_end = line:find("  ")
			if key_end then
				vim.api.nvim_buf_add_highlight(buf, ns, "Special", i - 1, 3, key_end - 1)
			end
		elseif i <= 2 then
			vim.api.nvim_buf_add_highlight(buf, ns, "Comment", i - 1, 0, -1)
		end
	end

	local o = { buffer = buf, nowait = true, silent = true }
	local close = function()
		vim.api.nvim_win_close(win, true)
	end
	vim.keymap.set("n", "q", close, o)
	vim.keymap.set("n", "<Esc>", close, o)

	vim.wo[win].cursorline = true
end

return M
