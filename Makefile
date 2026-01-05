.PHONY: test test-file format check deps clean ci

DEPS_DIR := .deps
PLENARY_DIR := $(DEPS_DIR)/plenary.nvim
SQLITE_DIR := $(DEPS_DIR)/sqlite.lua

# Install test dependencies
deps: $(PLENARY_DIR) $(SQLITE_DIR)

$(PLENARY_DIR):
	@mkdir -p $(DEPS_DIR)
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR)

$(SQLITE_DIR):
	@mkdir -p $(DEPS_DIR)
	git clone --depth 1 https://github.com/kkharji/sqlite.lua $(SQLITE_DIR)

# Run all tests with plenary (TODO: migrate to busted with nvim -l)
test: deps
	nvim --headless -u spec/minimal_init.lua \
		-c "lua require('plenary.busted')" \
		-c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/minimal_init.lua'}" \
		-c "qa!"

# Run a single test file
test-file: deps
	nvim --headless -u spec/minimal_init.lua \
		-c "lua require('plenary.busted')" \
		-c "PlenaryBustedFile $(FILE)" \
		-c "qa!"

# Format code
format:
	stylua lua/ plugin/ ftplugin/ spec/

# Check formatting without modifying
check:
	stylua --check lua/ plugin/ ftplugin/ spec/

# Run all checks (format check + test)
ci: check test

# Clean dependencies
clean:
	rm -rf $(DEPS_DIR)
