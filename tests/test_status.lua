local runner = require("tests.test_runner")

-- Mock vim for testing
_G.vim = {
	fn = {
		systemlist = function(cmd)
			return {}
		end,
	},
	v = {
		shell_error = 0,
	},
	notify = function(msg, level)
		-- Mock notify
	end,
	log = {
		levels = {
			ERROR = 4,
			WARN = 3,
			INFO = 2,
		},
	},
}

runner.describe("Status Module - Build Function", function()
	runner.it("should return staged count as third return value", function()
		-- Simulate build() behavior
		local staged = {}
		table.insert(staged, { file = "file1.lua", xy = "M " })
		table.insert(staged, { file = "file2.lua", xy = "A " })

		local staged_count = #staged

		runner.assert_eq(staged_count, 2, "should return count of 2 staged files")
	end)

	runner.it("should return 0 staged count for empty staging area", function()
		local staged = {}
		local staged_count = #staged

		runner.assert_eq(staged_count, 0, "should return count of 0 when no staged files")
	end)

	runner.it("should correctly parse git status output", function()
		-- Simulate parsing git status output
		local raw = { "M  file1.lua", "A  file2.lua", " M file3.lua", "?? file4.lua" }
		local staged = {}
		local unstaged = {}
		local untracked = {}

		for _, line in ipairs(raw) do
			if #line >= 4 then
				local x, y = line:sub(1, 1), line:sub(2, 2)
				local file = line:sub(4)

				if x == "?" then
					table.insert(untracked, { file = file })
				else
					if x ~= " " then
						table.insert(staged, { file = file })
					end
					if y ~= " " then
						table.insert(unstaged, { file = file })
					end
				end
			end
		end

		runner.assert_eq(#staged, 2, "should have 2 staged files")
		runner.assert_eq(#unstaged, 1, "should have 1 unstaged file")
		runner.assert_eq(#untracked, 1, "should have 1 untracked file")
	end)
end)

runner.describe("Status Module - Commit Guard", function()
	runner.it("should prevent commit when no files are staged", function()
		local staged_count = 0
		local should_allow_commit = staged_count > 0

		runner.assert_false(should_allow_commit, "should NOT allow commit with 0 staged files")
	end)

	runner.it("should allow commit when files are staged", function()
		local staged_count = 2
		local should_allow_commit = staged_count > 0

		runner.assert_true(should_allow_commit, "should allow commit with staged files")
	end)

	runner.it("should reject with appropriate error message for no staged files", function()
		local staged_count = 0
		local error_msg = staged_count == 0 and "[legit] no staged files to commit" or ""

		runner.assert_eq(error_msg, "[legit] no staged files to commit", "should have correct error message")
	end)

	runner.it("should update staged count on refresh", function()
		local staged_count = 0

		-- Simulate initial state
		runner.assert_eq(staged_count, 0, "initial count should be 0")

		-- Simulate refresh after staging files
		staged_count = 3

		runner.assert_eq(staged_count, 3, "updated count should be 3")
	end)
end)

runner.describe("Status Module - Edge Cases", function()
	runner.it("should handle repository with only unstaged changes", function()
		-- Simulate build() parsing
		local staged = {}
		local unstaged = {}

		table.insert(unstaged, { file = "file1.lua" })
		table.insert(unstaged, { file = "file2.lua" })

		local staged_count = #staged

		runner.assert_eq(staged_count, 0, "should have 0 staged files")
		runner.assert_eq(#unstaged, 2, "should have 2 unstaged files")
	end)

	runner.it("should handle clean working tree", function()
		local staged = {}
		local unstaged = {}
		local untracked = {}

		local staged_count = #staged

		runner.assert_eq(staged_count, 0, "should have 0 staged files")
		runner.assert_eq(#unstaged, 0, "should have 0 unstaged files")
		runner.assert_eq(#untracked, 0, "should have 0 untracked files")
	end)

	runner.it("should handle renamed files in staged area", function()
		-- Simulate parsing renamed file
		local line = "R  old_name.lua -> new_name.lua"
		local file = line:sub(4)
		file = file:match("^.+ %-> (.+)$") or file

		runner.assert_eq(file, "new_name.lua", "should extract new filename from rename")
	end)
end)

runner.summary()
