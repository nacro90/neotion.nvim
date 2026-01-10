# TDD Workflow for Neovim Lua Plugins

Use this skill when implementing new features or fixing bugs with Test-Driven Development.

## Activation

Activate when user mentions:
- "tdd", "test-driven", "red green refactor"
- "implement with tests", "add feature with tests"
- "write tests first"

## The TDD Cycle

```
   ┌─────────────────────────────────────────┐
   │                                         │
   ▼                                         │
┌──────┐     ┌───────┐     ┌──────────┐     │
│ RED  │ ──▶ │ GREEN │ ──▶ │ REFACTOR │ ────┘
└──────┘     └───────┘     └──────────┘
  Write       Make it       Improve
  failing     pass          quality
  test
```

## Phase 1: RED (Test Writer)

**Goal**: Write a failing test that defines expected behavior.

**Agent**: `.claude/agents/lua-test-writer.md`

**Process**:
1. Understand the feature requirement
2. Determine test location (`spec/unit/` or `spec/integration/`)
3. Write ONE focused test that will fail
4. Run `make test` to confirm it fails
5. The test failure message should be clear

**Checklist**:
- [ ] Test describes ONE behavior
- [ ] Test name is descriptive (`should X when Y`)
- [ ] Test follows AAA pattern (Arrange, Act, Assert)
- [ ] Test actually fails (not passing by accident)
- [ ] Failure message is helpful

## Phase 2: GREEN (Implementer)

**Goal**: Write minimum code to make the test pass.

**Agent**: `.claude/agents/lua-implementer.md`

**Process**:
1. Read the failing test carefully
2. Write ONLY enough code to pass
3. Do NOT add extra features
4. Run `make test` to confirm it passes
5. Resist the urge to refactor yet

**Checklist**:
- [ ] Code makes the test pass
- [ ] No extra functionality added
- [ ] Follows project code style
- [ ] Has LuaCATS annotations (public functions)
- [ ] All tests pass (not just the new one)

## Phase 3: REFACTOR

**Goal**: Improve code quality without changing behavior.

**Agent**: `.claude/agents/lua-refactorer.md`

**Process**:
1. Review the GREEN phase implementation
2. Identify improvement opportunities
3. Make ONE small refactoring
4. Run `make test` after each change
5. Continue until satisfied
6. Run `make ci` for final check

**Checklist**:
- [ ] All tests still pass
- [ ] Code is more readable
- [ ] Duplication removed (if any)
- [ ] Naming is clear
- [ ] No unnecessary complexity
- [ ] `make ci` passes

## Orchestration Commands

```bash
# Run tests (RED/GREEN verification)
make test

# Run specific test file
make test SPEC=spec/unit/path/to_spec.lua

# Full CI (format + lint + test)
make ci

# Format code
make format

# Check linting
selene lua/
```

## Example Session

**User**: "Add a function to check if a page is archived"

### RED Phase
```lua
-- spec/unit/model/page_spec.lua
describe("Page", function()
  describe("is_archived", function()
    it("should return true when page is archived", function()
      local page = require("neotion.model.page")
      local data = { archived = true }

      assert.is_true(page.is_archived(data))
    end)
  end)
end)
```

```bash
$ make test
# FAIL: page.is_archived does not exist
```

### GREEN Phase
```lua
-- lua/neotion/model/page.lua
---Check if page is archived
---@param page_data table
---@return boolean
function M.is_archived(page_data)
  return page_data.archived == true
end
```

```bash
$ make test
# PASS: All tests pass
```

### REFACTOR Phase
```lua
-- Maybe add nil check if needed, or leave as is if simple enough
---Check if page is archived
---@param page_data table
---@return boolean
function M.is_archived(page_data)
  return page_data and page_data.archived == true or false
end
```

```bash
$ make ci
# PASS: Format, lint, tests all pass
```

## Important Notes

1. **Context Isolation**: Each phase uses a separate agent to prevent context pollution
2. **Small Increments**: One test → one implementation → one refactor cycle
3. **Tests Are Documentation**: Well-written tests explain expected behavior
4. **No Shortcuts**: Resist writing implementation before tests

## When NOT to Use TDD

- Exploring/prototyping ideas
- Simple config changes
- Documentation updates
- Trivial one-line fixes with existing test coverage
