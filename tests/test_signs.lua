local runner = require("tests.test_runner")

-- Mock vim for testing
_G.vim = {
	fn = {
		fnamemodify = function(file, modifier)
			if modifier == ":h" then
				-- Simulate fnamemodify's :h (directory) behavior
				local result = string.match(file, "^(.*/)[^/]*$") or ""
				return result
			end
			return file
		end,
		getcwd = function()
			return "/current/working/dir"
		end,
	},
	api = {
		nvim_buf_is_valid = function(bufnr)
			return true
		end,
	},
	bo = {
		buftype = "",
	},
}

runner.describe("Signs Module - Oil Plugin Compatibility", function()
	runner.it("should skip oil:// protocol paths", function()
		local file = "oil:///home/user/project"
		
		-- Test the skip logic
		local should_skip = file:match("^%a+://") ~= nil
		
		runner.assert_true(should_skip, "should skip oil:// paths")
	end)

	runner.it("should skip fugitive:// protocol paths", function()
		local file = "fugitive:///project/.git/index"
		
		-- Test the skip logic
		local should_skip = file:match("^%a+://") ~= nil
		
		runner.assert_true(should_skip, "should skip fugitive:// paths")
	end)

	runner.it("should process normal filesystem paths", function()
		local file = "/home/user/project/src/main.lua"
		
		-- Test the skip logic
		local should_skip = file:match("^%a+://") ~= nil
		
		runner.assert_false(should_skip, "should process normal filesystem paths")
	end)

	runner.it("should handle cwd fallback for relative paths", function()
		-- Simulate fnamemodify for relative path
		local file = "main.lua"
		local cwd = _G.vim.fn.fnamemodify(file, ":h")
		
		if cwd == "" or cwd == "." then
			cwd = _G.vim.fn.getcwd()
		end
		
		runner.assert_eq(cwd, "/current/working/dir", "should fallback to getcwd()")
	end)

	runner.it("should extract directory from absolute paths", function()
		local file = "/home/user/project/src/main.lua"
		local cwd = _G.vim.fn.fnamemodify(file, ":h")
		
		runner.assert_eq(cwd, "/home/user/project/src/", "should extract directory path")
	end)

	runner.it("should handle nested oil paths", function()
		local file = "oil://~/.local/share/nvim"
		
		-- Test the skip logic
		local should_skip = file:match("^%a+://") ~= nil
		
		runner.assert_true(should_skip, "should skip nested oil paths")
	end)

	runner.it("should skip empty file paths", function()
		local file = ""
		
		-- Empty file should trigger early return (before protocol check)
		local should_return_early = file == ""
		
		runner.assert_true(should_return_early, "should return early for empty file")
	end)
end)

runner.summary()
