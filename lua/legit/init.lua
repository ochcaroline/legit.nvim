local M = {}

local defaults = {
	keymaps = {
		status = "<leader>gs",
		commit = "<leader>gc",
		push = "<leader>gp",
		pull = "<leader>gf",
		log = "<leader>gl",
		blame = "<leader>gb",
		rebase = "<leader>gr",
	},
	signs = {
		enabled = true,
		add = { text = "▎" },
		change = { text = "▎" },
		delete = { text = "▁" },
	},
}

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})
	local km = opts.keymaps

	-- Persist full config for other modules to read.
	local cfg = require("legit.config")
	cfg.keymaps = km
	cfg.signs = opts.signs

	if opts.signs.enabled then
		require("legit.signs").setup(opts.signs)
	end

	vim.api.nvim_create_user_command("Legit", function(cmd)
		local sub = cmd.args:lower()
		if sub == "help" then
			require("legit.help").open()
		else
			vim.notify("[legit] unknown subcommand: " .. cmd.args .. "  (try :Legit help)", vim.log.levels.WARN)
		end
	end, {
		nargs = 1,
		complete = function()
			return { "help" }
		end,
		desc = "legit commands",
	})

	local function map(key, fn, desc)
		if key then
			vim.keymap.set("n", key, fn, { desc = "[legit] " .. desc, silent = true })
		end
	end

	map(km.status, function()
		require("legit.status").open()
	end, "status")
	map(km.log, function()
		require("legit.log").open()
	end, "log")
	map(km.blame, function()
		require("legit.blame").open()
	end, "blame")
	map(km.rebase, function()
		require("legit.rebase").open()
	end, "rebase")

	map(km.commit, function()
		if not require("legit.git").has_staged_files() then
			vim.notify("[legit] no staged files to commit", vim.log.levels.WARN)
			return
		end
		require("legit.commit").open()
	end, "commit")

	map(km.push, function()
		vim.notify("[legit] pushing...", vim.log.levels.INFO)
		local out, ok = require("legit.git").push()
		vim.notify(table.concat(out, "\n"), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
	end, "push")

	map(km.pull, function()
		vim.notify("[legit] pulling...", vim.log.levels.INFO)
		local out, ok = require("legit.git").pull()
		vim.notify(table.concat(out, "\n"), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
	end, "pull")
end

return M
