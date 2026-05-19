-- Signs in the sign column indicating added / changed / deleted lines.
-- Parses `git diff HEAD -U0` hunks to avoid the overhead of running diff
-- on every keystroke — only refreshes on BufWritePost / BufReadPost / BufEnter.

local M = {}

local sign_group = "LegitSigns"

local function define_signs(cfg)
	vim.fn.sign_define("LegitAdd", { text = cfg.add.text, texthl = "LegitSignAdd" })
	vim.fn.sign_define("LegitChange", { text = cfg.change.text, texthl = "LegitSignChange" })
	vim.fn.sign_define("LegitDelete", { text = cfg.delete.text, texthl = "LegitSignDelete" })
end

-- Parse @@ -a,b +c,d @@ header. Omitted count defaults to 1.
local function parse_hunk(line)
	local os, oc, ns, nc = line:match("@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
	if not os then
		return nil
	end
	return {
		old_start = tonumber(os),
		old_count = oc ~= "" and tonumber(oc) or 1,
		new_start = tonumber(ns),
		new_count = nc ~= "" and tonumber(nc) or 1,
	}
end

local function place_signs(bufnr, diff_lines)
	vim.fn.sign_unplace(sign_group, { buffer = bufnr })

	local total = vim.api.nvim_buf_line_count(bufnr)
	local id = 1

	for _, line in ipairs(diff_lines) do
		if line:sub(1, 2) == "@@" then
			local h = parse_hunk(line)
			if h then
				local sign_name

				if h.old_count == 0 then
					-- pure addition
					sign_name = "LegitAdd"
					for i = 0, h.new_count - 1 do
						local lnum = h.new_start + i
						if lnum >= 1 and lnum <= total then
							vim.fn.sign_place(id, sign_group, sign_name, bufnr, { lnum = lnum, priority = 10 })
							id = id + 1
						end
					end
				elseif h.new_count == 0 then
					-- pure deletion — mark the adjacent line
					sign_name = "LegitDelete"
					local lnum = math.max(1, math.min(h.new_start, total))
					vim.fn.sign_place(id, sign_group, sign_name, bufnr, { lnum = lnum, priority = 10 })
					id = id + 1
				else
					-- modification
					sign_name = "LegitChange"
					for i = 0, h.new_count - 1 do
						local lnum = h.new_start + i
						if lnum >= 1 and lnum <= total then
							vim.fn.sign_place(id, sign_group, sign_name, bufnr, { lnum = lnum, priority = 10 })
							id = id + 1
						end
					end
				end
			end
		end
	end
end

function M.refresh(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	if vim.bo[bufnr].buftype ~= "" then
		return
	end

	local file = vim.api.nvim_buf_get_name(bufnr)
	if file == "" then
		return
	end

	-- Skip special buffers (oil, fugitive, etc.) with non-standard paths
	if file:match("^%a+://") then
		return
	end

	-- Get the directory for cwd; must be a valid directory
	local cwd = vim.fn.fnamemodify(file, ":h")
	if cwd == "" or cwd == "." then
		cwd = vim.fn.getcwd()
	end

	-- Run in background so we don't block the UI.
	vim.fn.jobstart({ "git", "diff", "HEAD", "-U0", "--", file }, {
		cwd = cwd,
		stdout_buffered = true,
		on_stdout = function(_, data)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					place_signs(bufnr, data or {})
				end
			end)
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				if not vim.api.nvim_buf_is_valid(bufnr) then
					return
				end
				-- Not committed yet — diff against the index instead.
				vim.fn.jobstart({ "git", "diff", "-U0", "--", file }, {
					cwd = cwd,
					stdout_buffered = true,
					on_stdout = function(_, data)
						vim.schedule(function()
							if vim.api.nvim_buf_is_valid(bufnr) then
								place_signs(bufnr, data or {})
							end
						end)
					end,
				})
			end
		end,
	})
end

function M.setup(cfg)
	define_signs(cfg)

	-- All legit highlight groups in one place.
	local groups = {
		-- sign column
		LegitSignAdd = { fg = "#57ab5a" },
		LegitSignChange = { fg = "#e3b341" },
		LegitSignDelete = { fg = "#e5534b" },
		-- status view: XY letters (bold + colour)
		LegitAdded = { fg = "#57ab5a", bold = true },
		LegitModified = { fg = "#e3b341", bold = true },
		LegitDeleted = { fg = "#e5534b", bold = true },
		LegitRenamed = { fg = "#79c0ff", bold = true },
		LegitUntracked = { fg = "#8b949e", bold = true },
		LegitConflict = { fg = "#ff7b72", bold = true },
		-- status view: filenames (same colour, no bold)
		LegitAddedFile = { fg = "#57ab5a" },
		LegitModifiedFile = { fg = "#e3b341" },
		LegitDeletedFile = { fg = "#e5534b" },
		LegitRenamedFile = { fg = "#79c0ff" },
		LegitUntrackedFile = { fg = "#8b949e" },
		LegitConflictFile = { fg = "#ff7b72" },
	}

	for name, hl in pairs(groups) do
		vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", hl, { default = true }))
	end

	local aug = vim.api.nvim_create_augroup("LegitSigns", { clear = true })

	vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "BufEnter" }, {
		group = aug,
		callback = function(ev)
			if vim.bo[ev.buf].buftype == "" then
				M.refresh(ev.buf)
			end
		end,
	})

	-- Re-apply after colorscheme changes.
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
