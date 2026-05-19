local M = {}

-- Run a git command, return list of output lines and success bool.
local function run(args)
	local output = vim.fn.systemlist("git " .. args)
	return output, vim.v.shell_error == 0
end

function M.run(args)
	return run(args)
end

function M.status()
	return run("status --short")
end

function M.stage(file)
	return run("add -- " .. vim.fn.shellescape(file))
end

local function has_head()
	vim.fn.systemlist("git rev-parse --verify HEAD")
	return vim.v.shell_error == 0
end

function M.unstage(file)
	if not has_head() then
		return run("rm --cached -- " .. vim.fn.shellescape(file))
	end
	return run("restore --staged -- " .. vim.fn.shellescape(file))
end

function M.discard(file)
	return run("restore -- " .. vim.fn.shellescape(file))
end

function M.stage_all()
	return run("add -A")
end

function M.unstage_all()
	if not has_head() then
		return run("rm --cached -r .")
	end
	return run("restore --staged :/")
end

function M.commit(msg)
	return run("commit -m " .. vim.fn.shellescape(msg))
end

function M.push()
	return run("push")
end

function M.pull()
	return run("pull")
end

function M.rebase(ref)
	if ref and ref ~= "" then
		return run("rebase " .. vim.fn.shellescape(ref))
	end
	return run("rebase")
end

function M.log(n)
	n = tonumber(n) or 30
	if n < 1 or n > 10000 then
		n = 30
	end
	return run(string.format("log --oneline --graph --decorate -n %d", n))
end

function M.blame(file)
	return run("blame --date=short --abbrev=8 " .. vim.fn.shellescape(file))
end

-- Returns unified diff with no context lines (for sign parsing).
function M.diff_hunks(file)
	local lines, ok = run("diff HEAD -U0 -- " .. vim.fn.shellescape(file))
	if not ok or #lines == 0 then
		-- fallback: diff against index (staged but not committed)
		lines, ok = run("diff -U0 -- " .. vim.fn.shellescape(file))
	end
	return lines, ok
end

function M.diff(file, staged)
	if file then
		if staged then
			return run("diff --cached -- " .. vim.fn.shellescape(file))
		else
			return run("diff -- " .. vim.fn.shellescape(file))
		end
	end
	return run("diff")
end

---@return string
function M.get_current_branch()
	local branch, ok = run("rev-parse --abbrev-ref HEAD")
	if ok and branch[1] and branch[1] ~= "HEAD" then
		return branch[1]
	end
	-- No commits yet or HEAD is ambiguous; try to get the branch name from symbolic-ref
	local ref, ok2 = run("symbolic-ref --short HEAD")
	if ok2 and ref[1] then
		return ref[1]
	end
	return "(no commits)"
end

---@return boolean
function M.has_staged_files()
	local status_lines = M.status()
	for _, line in ipairs(status_lines) do
		if #line >= 4 then
			local x = line:sub(1, 1)
			-- If first character is not space or ?, it's a staged file
			if x ~= " " and x ~= "?" then
				return true
			end
		end
	end
	return false
end

return M
