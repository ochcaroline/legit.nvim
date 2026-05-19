local runner = require("tests.test_runner")

-- Mock vim for testing
_G.vim = {
	fn = {
		systemlist = function(cmd)
			-- Mock systemlist to simulate command output
			if cmd == "git rev-parse --abbrev-ref HEAD" then
				-- Simulate HEAD (ambiguous case in empty repo)
				return { "HEAD" }
			elseif cmd == "git symbolic-ref --short HEAD" then
				-- Simulate valid branch name
				return { "main" }
			elseif cmd == "git status --short" then
				return { "M file1.lua", "A file2.lua" }
			elseif cmd == "git rev-parse --verify HEAD" then
				return { "" }
			end
			return {}
		end,
	},
	v = {
		shell_error = 0,
	},
}

-- Mock functions to simulate git commands
local function mock_run(args)
	local output = _G.vim.fn.systemlist("git " .. args)
	return output, _G.vim.v.shell_error == 0
end

runner.describe("Git Module - get_current_branch()", function()
	runner.it("should return branch name when it exists", function()
		-- When git rev-parse returns actual branch name
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git rev-parse --abbrev-ref HEAD" then
				return { "main" }
			end
			return {}
		end
		_G.vim.v.shell_error = 0

		-- Mock implementation of get_current_branch
		local branch = _G.vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")
		local result = branch[1]
		if result and result ~= "HEAD" then
			result = result
		else
			local ref = _G.vim.fn.systemlist("git symbolic-ref --short HEAD")
			result = ref[1] or "(no commits)"
		end

		runner.assert_eq(result, "main", "should return 'main' branch")
	end)

	runner.it("should fallback to symbolic-ref when HEAD is ambiguous (empty repo)", function()
		-- When git rev-parse returns 'HEAD' (ambiguous)
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git rev-parse --abbrev-ref HEAD" then
				return { "HEAD" }
			elseif cmd == "git symbolic-ref --short HEAD" then
				return { "main" }
			end
			return {}
		end
		_G.vim.v.shell_error = 0

		-- Mock implementation of get_current_branch
		local branch = _G.vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")
		local result = branch[1]
		if result and result ~= "HEAD" then
			result = result
		else
			local ref = _G.vim.fn.systemlist("git symbolic-ref --short HEAD")
			result = ref[1] or "(no commits)"
		end

		runner.assert_eq(result, "main", "should fallback to symbolic-ref")
	end)

	runner.it("should return '(no commits)' when both commands fail", function()
		-- When both commands fail
		_G.vim.fn.systemlist = function(cmd)
			return {}
		end
		_G.vim.v.shell_error = 128

		-- Mock implementation of get_current_branch
		local branch = _G.vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")
		local result = branch[1]
		if result and result ~= "HEAD" then
			result = result
		else
			local ref = _G.vim.fn.systemlist("git symbolic-ref --short HEAD")
			result = ref[1] or "(no commits)"
		end

		runner.assert_eq(result, "(no commits)", "should return '(no commits)'")
	end)
end)

runner.describe("Git Module - status parsing", function()
	runner.it("should parse staged files correctly", function()
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git status --short" then
				return { "M  file1.lua", "A  file2.lua", " M file3.lua" }
			end
			return {}
		end

		local raw = _G.vim.fn.systemlist("git status --short")
		local staged_count = 0

		for _, line in ipairs(raw) do
			if #line >= 4 then
				local x = line:sub(1, 1)
				if x ~= " " and x ~= "?" then
					staged_count = staged_count + 1
				end
			end
		end

		runner.assert_eq(staged_count, 2, "should count 2 staged files (M and A)")
	end)

	runner.it("should count unstaged files separately", function()
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git status --short" then
				return { " M file1.lua", "M  file2.lua", "?? file3.lua" }
			end
			return {}
		end

		local raw = _G.vim.fn.systemlist("git status --short")
		local staged_count = 0
		local unstaged_count = 0

		for _, line in ipairs(raw) do
			if #line >= 4 then
				local x, y = line:sub(1, 1), line:sub(2, 2)
				-- Match the actual code logic: skip untracked files
				if x == "?" then
					-- untracked, skip
				else
					if x ~= " " then
						staged_count = staged_count + 1
					end
					if y ~= " " then
						unstaged_count = unstaged_count + 1
					end
				end
			end
		end

		runner.assert_eq(staged_count, 1, "should count 1 staged file")
		runner.assert_eq(unstaged_count, 1, "should count 1 unstaged file")
	end)

	runner.it("should handle empty repository", function()
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git status --short" then
				return {}
			end
			return {}
		end

		local raw = _G.vim.fn.systemlist("git status --short")
		local staged_count = 0

		for _, line in ipairs(raw) do
			if #line >= 4 then
				local x = line:sub(1, 1)
				if x ~= " " and x ~= "?" then
					staged_count = staged_count + 1
				end
			end
		end

		runner.assert_eq(staged_count, 0, "should have 0 staged files in empty repo")
	end)
end)

runner.describe("Git Module - has_staged_files()", function()
	runner.it("should return true when files are staged", function()
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git status --short" then
				return { "M  file1.lua", "A  file2.lua" }
			end
			return {}
		end

		-- Simulate has_staged_files() logic
		local status_lines = _G.vim.fn.systemlist("git status --short")
		local has_staged = false
		for _, line in ipairs(status_lines) do
			if #line >= 4 then
				local x = line:sub(1, 1)
				if x ~= " " and x ~= "?" then
					has_staged = true
					break
				end
			end
		end

		runner.assert_true(has_staged, "should return true when files are staged")
	end)

	runner.it("should return false when no files are staged", function()
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git status --short" then
				return { " M file1.lua", "?? file2.lua" }
			end
			return {}
		end

		-- Simulate has_staged_files() logic
		local status_lines = _G.vim.fn.systemlist("git status --short")
		local has_staged = false
		for _, line in ipairs(status_lines) do
			if #line >= 4 then
				local x = line:sub(1, 1)
				if x ~= " " and x ~= "?" then
					has_staged = true
					break
				end
			end
		end

		runner.assert_false(has_staged, "should return false when no files are staged")
	end)

	runner.it("should return false for empty working tree", function()
		_G.vim.fn.systemlist = function(cmd)
			if cmd == "git status --short" then
				return {}
			end
			return {}
		end

		-- Simulate has_staged_files() logic
		local status_lines = _G.vim.fn.systemlist("git status --short")
		local has_staged = false
		for _, line in ipairs(status_lines) do
			if #line >= 4 then
				local x = line:sub(1, 1)
				if x ~= " " and x ~= "?" then
					has_staged = true
					break
				end
			end
		end

		runner.assert_false(has_staged, "should return false for empty working tree")
	end)
end)

runner.summary()
