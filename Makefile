.PHONY: test test-file lint format check deps clean

DEPS_DIR := .deps
PLENARY_DIR := $(DEPS_DIR)/plenary.nvim

# Install test dependencies (plenary for now, will migrate to busted)
deps: $(PLENARY_DIR)

$(PLENARY_DIR):
	@mkdir -p $(DEPS_DIR)
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR)

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

# Run linter
lint:
	selene lua/

# Format code
format:
	stylua lua/ plugin/ ftplugin/ spec/

# Check formatting without modifying
check:
	stylua --check lua/ plugin/ ftplugin/ spec/

# Run all checks (format check + lint + test)
ci: check lint test

# Clean dependencies
clean:
	rm -rf $(DEPS_DIR)
