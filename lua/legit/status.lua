local M = {}

local window = require("legit.window")
local git = require("legit.git")

local ns = vim.api.nvim_create_namespace("legit_status")

local HELP = {
	" legit status",
	" ─────────────────────────────────────────────────",
}
local HELP_LINES = #HELP

local function letter_hl(ch)
	if ch == "A" then
		return "LegitAdded"
	end
	if ch == "M" then
		return "LegitModified"
	end
	if ch == "D" then
		return "LegitDeleted"
	end
	if ch == "R" then
		return "LegitRenamed"
	end
	if ch == "U" then
		return "LegitConflict"
	end
	if ch == "?" then
		return "LegitUntracked"
	end
	return "LegitModified"
end

local function build()
	local raw, ok = git.status()
	if not ok then
		return nil, nil
	end

	local staged, unstaged, untracked = {}, {}, {}

	for _, line in ipairs(raw) do
		if #line >= 4 then
			local x, y = line:sub(1, 1), line:sub(2, 2)
			local file = line:sub(4)
			file = file:match("^.+ %-> (.+)$") or file

			if x == "?" then
				table.insert(untracked, { file = file, xy = "??", display = "?? " .. file })
			else
				if x ~= " " then
					table.insert(staged, { file = file, xy = x .. y, display = x .. "  " .. file })
				end
				if y ~= " " then
					table.insert(unstaged, { file = file, xy = " " .. y, display = y .. "  " .. file })
				end
			end
		end
	end

	local lines = vim.deepcopy(HELP)
	local file_map = {} -- lnum (1-based) → entry

	local function add_section(title, items, hl, section_type)
		if #items == 0 then
			return
		end
		table.insert(lines, "")
		table.insert(lines, " " .. title)
		for _, entry in ipairs(items) do
			entry.section_hl = hl
			entry.section_type = section_type
			table.insert(lines, " " .. entry.display)
			file_map[#lines] = entry
		end
	end

	add_section("Staged", staged, "LegitSectionStaged", "staged")
	add_section("Unstaged", unstaged, "LegitSectionUnstaged", "unstaged")
	add_section("Untracked", untracked, "LegitSectionUntracked", "untracked")

	if #staged == 0 and #unstaged == 0 and #untracked == 0 then
		table.insert(lines, "  (nothing to commit, working tree clean)")
	end

	return lines, file_map
end

local function apply_hl(buf, lines, file_map)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for i = 2, HELP_LINES do
		vim.api.nvim_buf_add_highlight(buf, ns, "Comment", i - 1, 0, -1)
	end

	for lnum, line in ipairs(lines) do
		if lnum > HELP_LINES then
			local entry = file_map[lnum]
			if entry then
				local ch = entry.xy:sub(1, 1) ~= " " and entry.xy:sub(1, 1) or entry.xy:sub(2, 2)
				vim.api.nvim_buf_add_highlight(buf, ns, letter_hl(ch), lnum - 1, 1, 2)
			elseif line:match("^ %u") then
				vim.api.nvim_buf_add_highlight(buf, ns, "Title", lnum - 1, 0, -1)
			end
		end
	end
end

local function set_lines(buf, lines, file_map)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	apply_hl(buf, lines, file_map)
end

function M.open()
	if window.is_open() then
		window.close()
		return
	end

	local lines, file_map = build()
	if not lines then
		vim.notify("[legit] not a git repository", vim.log.levels.ERROR)
		return
	end

	local buf, win = window.open(lines, { title = "legit status", no_escape = true })
	vim.bo[buf].filetype = "legit-status"
	apply_hl(buf, lines, file_map)

	vim.wo[win].number = true

	vim.api.nvim_win_set_cursor(win, { HELP_LINES + 1, 0 })

	local function refresh()
		local new_lines, new_map = build()
		if new_lines then
			file_map = new_map
			set_lines(buf, new_lines, new_map)
		end
	end

	local function entry_at_cursor()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		return file_map[row]
	end

	local function stage()
		local e = entry_at_cursor()
		if e then
			git.stage(e.file)
			refresh()
		end
	end

	local function unstage()
		local e = entry_at_cursor()
		if e then
			git.unstage(e.file)
			refresh()
		end
	end

	local function discard()
		local e = entry_at_cursor()
		if not e then
			return
		end
		local confirm = vim.fn.input("Discard changes to " .. e.file .. "? [y/N] ")
		vim.cmd("redraw")
		if confirm:lower() == "y" then
			git.discard(e.file)
			refresh()
		end
	end

	local function show_diff()
		local e = entry_at_cursor()
		if not e then
			return
		end

		if e.section_type == "untracked" then
			vim.notify("[legit] untracked file, cannot show diff", vim.log.levels.WARN)
			return
		end

		local staged = e.section_type == "staged"
		local diff_lines, ok = git.diff(e.file, staged)
		if not ok or #diff_lines == 0 then
			diff_lines = { "  (no changes)" }
		end
		local hdr = {
			" Diff: " .. e.file .. "   (<Esc> back to status)",
			" ─────────────────────────────────────────────────",
		}
		vim.list_extend(hdr, diff_lines)
		local dbuf = window.open(hdr, { title = "legit diff: " .. e.file, on_back = M.open })
		vim.bo[dbuf].filetype = "diff"
	end

	local function do_commit()
		require("legit.commit").open(function(_)
			M.open()
		end)
	end

	local function stage_unstage_all()
		local e = entry_at_cursor()
		if e and e.section_hl == "LegitSectionStaged" then
			git.unstage_all()
		else
			git.stage_all()
		end
		refresh()
	end

	local o = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "s", stage, vim.tbl_extend("force", o, { desc = "Stage" }))
	vim.keymap.set("n", "u", unstage, vim.tbl_extend("force", o, { desc = "Unstage" }))
	vim.keymap.set("n", "a", stage_unstage_all, vim.tbl_extend("force", o, { desc = "Stage/unstage all" }))
	vim.keymap.set("n", "x", discard, vim.tbl_extend("force", o, { desc = "Discard" }))
	vim.keymap.set("n", "d", show_diff, vim.tbl_extend("force", o, { desc = "Diff" }))
	vim.keymap.set("n", "D", function()
		local e = entry_at_cursor()
		if e then
			require("legit.diff").open(e.file)
		end
	end, vim.tbl_extend("force", o, { desc = "Side-by-side diff" }))
	vim.keymap.set("n", "c", do_commit, vim.tbl_extend("force", o, { desc = "Commit" }))
	vim.keymap.set("n", "r", refresh, vim.tbl_extend("force", o, { desc = "Refresh" }))
end

return M
