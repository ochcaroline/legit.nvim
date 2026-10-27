-- Highlight TODO/FIXME-style comment tags in buffers and list them project-wide.

local M = {}

local ns = vim.api.nvim_create_namespace("LegitTodos")

-- tag -> highlight group
local tags = {
	FIXME = "LegitTodoFix",
	BUG = "LegitTodoFix",
	FIX = "LegitTodoFix",
	XXX = "LegitTodoFix",
	HACK = "LegitTodoWarn",
	WARN = "LegitTodoWarn",
	WARNING = "LegitTodoWarn",
	TODO = "LegitTodoTodo",
	NOTE = "LegitTodoNote",
	INFO = "LegitTodoNote",
	PERF = "LegitTodoPerf",
	OPTIMIZE = "LegitTodoPerf",
}

local comment_prefixes = { "//", "#", "--", "/*", ";", "%", "<!--" }

local groups = {
	LegitTodoFix = { fg = "#ffffff", bg = "#e5534b", bold = true },
	LegitTodoWarn = { fg = "#1c1c1c", bg = "#e3b341", bold = true },
	LegitTodoTodo = { fg = "#ffffff", bg = "#6e7681", bold = true },
	LegitTodoNote = { fg = "#1c1c1c", bg = "#79c0ff", bold = true },
	LegitTodoPerf = { fg = "#1c1c1c", bg = "#d2a8ff", bold = true },
	-- whole-row backgrounds in the list window
	LegitTodoFixRow = { bg = "#4a2326" },
	LegitTodoWarnRow = { bg = "#4a3d1a" },
	LegitTodoTodoRow = { bg = "#30363d" },
	LegitTodoNoteRow = { bg = "#1f3a52" },
	LegitTodoPerfRow = { bg = "#3b2d52" },
}

local function comment_prefix(bufnr)
	local cs = vim.bo[bufnr].commentstring
	local lead = cs and cs:match("^(.-)%%s") or ""
	lead = vim.trim(lead)
	return lead ~= "" and lead or nil
end

local function has_comment_prefix(line, before, lead)
	if lead then
		local start = 1
		while true do
			local s = line:find(lead, start, true)
			if not s or s >= before then
				break
			end
			if s == 1 or line:sub(s - 1, s - 1):match("%s") then
				return true
			end
			start = s + #lead
		end
		return false
	end

	for _, prefix in ipairs(comment_prefixes) do
		local start = 1
		while true do
			local s = line:find(prefix, start, true)
			if not s or s >= before then
				break
			end
			if s == 1 or line:sub(s - 1, s - 1):match("%s") then
				return true
			end
			start = s + #prefix
		end
	end
	local star = line:find("*", 1, true)
	return line:match("^%s*%*") ~= nil and star ~= nil and star < before
end

function M.refresh(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	local lead = comment_prefix(bufnr)
	if not lead then
		return
	end
	for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		local cstart = line:find(lead, 1, true)
		if cstart and has_comment_prefix(line, cstart + 1, lead) then
			local init = cstart + #lead
			while true do
				local s, e, tag = line:find("%f[%w_](%u+)%f[^%w_]", init)
				if not s then
					break
				end
				if tags[tag] then
					-- include trailing "(user):" or ":" in the highlight
					local _, ce = line:find("^%b():?", e + 1)
					if not ce then
						_, ce = line:find("^:", e + 1)
					end
					vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1, {
						end_row = i,
						end_col = 0,
						hl_group = tags[tag] .. "Row",
						hl_eol = true,
						priority = 4000,
					})
					vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, s - 1, {
						end_col = ce or e,
						hl_group = tags[tag],
					})
					break
				end
				init = e + 1
			end
		end
	end
end

function M.list()
	local pat = table.concat(vim.tbl_keys(tags), "|")
	vim.fn.system({ "git", "rev-parse", "--is-inside-work-tree" })
	local cmd = { "git", "grep", "-nIEw", "--untracked" }
	if vim.v.shell_error ~= 0 then
		table.insert(cmd, "--no-index")
	end
	vim.list_extend(cmd, { "-e", "(" .. pat .. ")" })
	local items = {}
	for _, l in ipairs(vim.fn.systemlist(cmd)) do
		local file, lnum, text = l:match("^(.-):(%d+):(.*)$")
		local tag_start
		if text then
			local init = 1
			while true do
				local s, e, tag = text:find("%f[%w_](%u+)%f[^%w_]", init)
				if not s then
					break
				end
				if tags[tag] and has_comment_prefix(text, s) then
					tag_start = s
					break
				end
				init = e + 1
			end
		end
		if file and tag_start then
			table.insert(items, { filename = file, lnum = tonumber(lnum), text = vim.trim(text) })
		end
	end
	if #items == 0 then
		vim.notify("[legit] no todos found", vim.log.levels.INFO)
		return
	end
	vim.fn.setqflist({}, " ", { title = "Todos", items = items })
	vim.cmd("copen")

	local buf = vim.api.nvim_get_current_buf()
	vim.keymap.set("n", "<CR>", function()
		vim.cmd("cc " .. vim.api.nvim_win_get_cursor(0)[1])
		vim.cmd("cclose")
	end, { buffer = buf, silent = true })
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local text_start = select(2, line:find("|[^|]*|")) or 0
		local init = text_start + 1
		while true do
			local s, e, tag = line:find("%f[%w_](%u+)%f[^%w_]", init)
			if not s then
				break
			end
			if tags[tag] then
				vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { line_hl_group = tags[tag] .. "Row" })
				vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s - 1, { end_col = e, hl_group = tags[tag] })
				break
			end
			init = e + 1
		end
	end
end

function M.setup()
	for name, hl in pairs(groups) do
		vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", hl, { default = true }))
	end
	local aug = vim.api.nvim_create_augroup("LegitTodos", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "BufEnter", "BufWinEnter", "BufReadPost", "BufWritePost", "TextChanged", "InsertLeave", "FileType", "LspAttach" },
		{
			group = aug,
			callback = function(ev)
				M.refresh(ev.buf)
			end,
		}
	)
	vim.schedule(function()
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			M.refresh(b)
		end
	end)
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = aug,
		callback = function()
			for name, hl in pairs(groups) do
				vim.api.nvim_set_hl(0, name, hl)
			end
		end,
	})
end

return M
