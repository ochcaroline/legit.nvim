.PHONY: test test-git test-status test-signs test-all help lint clean

help:
	@echo "Legit.nvim - Available targets:"
	@echo ""
	@echo "  test              Run all tests"
	@echo "  test-git          Run git module tests"
	@echo "  test-status       Run status module tests"
	@echo "  test-signs        Run signs module tests"
	@echo "  test-all          Run all tests (same as 'test')"
	@echo "  lint              Check Lua syntax"
	@echo "  clean             Remove test artifacts"
	@echo "  help              Show this help message"
	@echo ""

# Run all tests
test: test-all

# Run specific test modules
test-git:
	@echo "Running git module tests..."
	lua -e "package.path = '$(PWD)/?.lua;' .. package.path" tests/test_git.lua

test-status:
	@echo "Running status module tests..."
	lua -e "package.path = '$(PWD)/?.lua;' .. package.path" tests/test_status.lua

test-signs:
	@echo "Running signs module tests..."
	lua -e "package.path = '$(PWD)/?.lua;' .. package.path" tests/test_signs.lua

# Run all tests
test-all: test-git test-status test-signs
	@echo ""
	@echo "All tests completed!"

# Lint Lua files
lint:
	@echo "Checking Lua syntax..."
	@for file in lua/legit/*.lua plugin/*.lua; do \
		echo "  Checking $$file..."; \
		lua -l debug -e "assert(loadfile('$$file'))" 2>&1 || exit 1; \
	done
	@echo "✓ All Lua files have valid syntax"

# Clean up test artifacts
clean:
	@find . -name "*.swp" -o -name "*~" -delete
	@echo "Clean completed"

.PHONY: test test-git test-status test-signs test-all help lint clean
