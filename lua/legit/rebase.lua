local M = {}

local window = require("legit.window")
local git = require("legit.git")

function M.open()
	local ref = vim.fn.input("Rebase onto (branch/commit, empty = abort): ")
	vim.cmd("redraw")

	if ref == "" then
		vim.notify("[legit] rebase aborted", vim.log.levels.WARN)
		return
	end

	if not ref:match("^[a-zA-Z0-9._/-]+$") then
		vim.notify("[legit] invalid ref name", vim.log.levels.ERROR)
		return
	end

	local verify_out, verify_ok = git.run("rev-parse --verify " .. vim.fn.shellescape(ref))
	if not verify_ok then
		vim.notify("[legit] ref not found: " .. ref, vim.log.levels.ERROR)
		return
	end

	local out, ok = git.rebase(ref)
	local lines = {
		" Git Rebase: " .. ref,
		" ─────────────────────────────────────────────────",
	}
	vim.list_extend(lines, out)

	local buf, _ = window.open(lines, { title = "legit rebase" })
	local lvl = ok and vim.log.levels.INFO or vim.log.levels.ERROR
	vim.notify(ok and "Rebase succeeded" or "Rebase failed", lvl)
	vim.bo[buf].filetype = "legit-output"
end

return M
