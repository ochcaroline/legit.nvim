-- Simple test runner for legit tests
local TestRunner = {}
TestRunner.tests = {}
TestRunner.passed = 0
TestRunner.failed = 0

function TestRunner.describe(name, fn)
	print("\n" .. name)
	print(string.rep("─", #name))
	fn()
end

function TestRunner.it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		TestRunner.passed = TestRunner.passed + 1
		print("  ✓ " .. name)
	else
		TestRunner.failed = TestRunner.failed + 1
		print("  ✗ " .. name)
		print("    Error: " .. tostring(err))
	end
end

function TestRunner.assert_eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "assertion failed") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
	end
end

function TestRunner.assert_true(value, msg)
	if not value then
		error(msg or "assertion failed: expected true")
	end
end

function TestRunner.assert_false(value, msg)
	if value then
		error(msg or "assertion failed: expected false")
	end
end

function TestRunner.assert_nil(value, msg)
	if value ~= nil then
		error(msg or "assertion failed: expected nil")
	end
end

function TestRunner.assert_not_nil(value, msg)
	if value == nil then
		error(msg or "assertion failed: expected non-nil value")
	end
end

function TestRunner.assert_contains(str, substring, msg)
	if not string.find(str, substring, 1, true) then
		error((msg or "assertion failed") .. " (expected string to contain '" .. substring .. "')")
	end
end

function TestRunner.summary()
	print("\n" .. string.rep("═", 40))
	print("Tests: " .. (TestRunner.passed + TestRunner.failed))
	print("Passed: " .. TestRunner.passed)
	print("Failed: " .. TestRunner.failed)
	print(string.rep("═", 40))
	
	if TestRunner.failed > 0 then
		os.exit(1)
	end
end

return TestRunner
