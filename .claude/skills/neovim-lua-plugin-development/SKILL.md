---
name: neovim-lua-plugin-development
description: Best practices for developing Neovim Lua plugins. Use when creating, refactoring, or reviewing Neovim plugins written in Lua. Covers type safety with LuaCATS, user commands, keymaps, lazy loading, configuration patterns, health checks, testing with busted, and documentation.
---

# Neovim Lua Plugin Development Best Practices

This skill provides guidance for creating high-quality, maintainable Neovim plugins using Lua, following modern conventions and the Neovim 0.10+ API.

## Type Safety

Use LuaCATS annotations with lua-language-server to catch bugs before users do.

```lua
---@class MyPlugin.Config
---@field enabled boolean
---@field timeout integer

---@param opts MyPlugin.Config
---@return boolean
local function setup(opts)
    -- Implementation
end
```

**Tools for type checking:**
- lua-language-server
- luacheck for linting
- emmylua-analyzer-rust

## User Commands

### DON'T: Pollute command namespace
```lua
-- Bad: Multiple top-level commands
:RocksInstall {arg}
:RocksPrune {arg}
:RocksUpdate
```

### DO: Use subcommands with completions
```lua
-- Good: Single command with subcommands
:Rocks install {arg}
:Rocks prune {arg}
:Rocks update
```

**Implementation pattern:**

```lua
---@class MyCmdSubcommand
---@field impl fun(args:string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, MyCmdSubcommand>
local subcommand_tbl = {
    update = {
        impl = function(args, opts)
            -- Implementation
        end,
    },
    install = {
        impl = function(args, opts)
            -- Implementation
        end,
        complete = function(subcmd_arg_lead)
            local install_args = { "neorg", "rest.nvim", "rustaceanvim" }
            return vim.iter(install_args)
                :filter(function(arg)
                    return arg:find(subcmd_arg_lead) ~= nil
                end)
                :totable()
        end,
    },
}

---@param opts table
local function my_cmd(opts)
    local fargs = opts.fargs
    local subcommand_key = fargs[1]
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommand_tbl[subcommand_key]
    if not subcommand then
        vim.notify("Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
        return
    end
    subcommand.impl(args, opts)
end

vim.api.nvim_create_user_command("Rocks", my_cmd, {
    nargs = "+",
    desc = "Command with subcommand completions",
    complete = function(arg_lead, cmdline, _)
        local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*Rocks[!]*%s(%S+)%s(.*)$")
        if subcmd_key and subcmd_arg_lead and subcommand_tbl[subcmd_key] and subcommand_tbl[subcmd_key].complete then
            return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
        end
        if cmdline:match("^['<,'>]*Rocks[!]*%s+%w*$") then
            local subcommand_keys = vim.tbl_keys(subcommand_tbl)
            return vim.iter(subcommand_keys)
                :filter(function(key)
                    return key:find(arg_lead) ~= nil
                end)
                :totable()
        end
    end,
    bang = true,
})
```

## Keymaps

### DON'T: Create automatic keymaps that conflict with user mappings

### DO: Provide `<Plug>` mappings

**In your plugin:**
```lua
vim.keymap.set("n", "<Plug>(MyPluginAction)", function()
    print("Hello")
end)

-- Multi-mode support
vim.keymap.set("n", "<Plug>(SayHello)", function()
    print("Hello from normal mode")
end)

vim.keymap.set("v", "<Plug>(SayHello)", function()
    print("Hello from visual mode")
end)
```

**In user's config:**
```lua
vim.keymap.set("n", "<leader>h", "<Plug>(MyPluginAction)")
vim.keymap.set({"n", "v"}, "<leader>h", "<Plug>(SayHello)")
```

**Benefits:**
- Users define their own keymaps (one line of code)
- No error if plugin is not installed or disabled
- Can enforce options like `expr = true`
- Handle different modes differently with single mapping

## Initialization

### DON'T: Force users to call `setup()` to use the plugin

### DO: Separate configuration from initialization

**Configuration approaches:**
1. A Lua function `setup(opts)` or `configure(opts)` that **only** overrides defaults (no init logic)
2. A `vim.g` or `vim.b` table for Vimscript compatibility

**Automatic initialization** should be in `plugin/` or `ftplugin/` scripts.

```lua
-- ftplugin/rust.lua
if vim.g.loaded_my_rust_plugin then
    return
end
vim.g.loaded_my_rust_plugin = true

local bufnr = vim.api.nvim_get_current_buf()
vim.keymap.set("n", "<Plug>(MyPluginBufferAction)", function()
    print("Hello")
end, { buffer = bufnr })
```

## Lazy Loading

### DON'T: Rely on plugin managers for lazy loading

### DO: Implement lazy loading yourself

**Defer `require` calls:**

```lua
-- Bad: Eager loading
local foo = require("foo")
vim.api.nvim_create_user_command("MyCommand", function()
    foo.do_something()
end, {})

-- Good: Lazy loading
vim.api.nvim_create_user_command("MyCommand", function()
    local foo = require("foo")
    foo.do_something()
end, {})
```

**Use `ftplugin/` for filetype-specific functionality:**
```lua
-- ftplugin/rust.lua
if not vim.g.loaded_my_rust_plugin then
    -- Initialize once
end
vim.g.loaded_my_rust_plugin = true
```

## Configuration

### Split config options and internal config values

```lua
-- config/meta.lua (for user config with optional fields)
---@class myplugin.Config
---@field do_something_cool? boolean
---@field strategy? "random" | "periodic"

---@type myplugin.Config | fun():myplugin.Config | nil
vim.g.my_plugin = vim.g.my_plugin

-- config/internal.lua (internal with required fields)
---@class myplugin.InternalConfig
local default_config = {
    ---@type boolean
    do_something_cool = true,
    ---@type "random" | "periodic"
    strategy = "random",
}

local user_config = type(vim.g.my_plugin) == "function"
    and vim.g.my_plugin()
    or vim.g.my_plugin
    or {}

---@type myplugin.InternalConfig
local config = vim.tbl_deep_extend("force", default_config, user_config)
```

### Validate configs

```lua
---@param path string
---@param tbl table
---@return boolean is_valid
---@return string|nil error_message
local function validate_path(path, tbl)
    local ok, err = pcall(vim.validate, tbl)
    return ok, err and path .. "." .. err
end

---@param cfg myplugin.InternalConfig
---@return boolean is_valid
---@return string|nil error_message
function validate(cfg)
    return validate_path("vim.g.my_plugin", {
        do_something_cool = { cfg.do_something_cool, "boolean" },
        strategy = { cfg.strategy, "string" },
    })
end
```

## Health Checks

Provide health checks in `lua/{plugin}/health.lua`:

```lua
local M = {}

function M.check()
    vim.health.start("myplugin")

    -- Check configuration
    local ok, err = validate(config)
    if ok then
        vim.health.ok("Configuration is valid")
    else
        vim.health.error("Invalid configuration: " .. err)
    end

    -- Check dependencies
    if vim.fn.executable("rg") == 1 then
        vim.health.ok("ripgrep is installed")
    else
        vim.health.warn("ripgrep not found (optional)")
    end
end

return M
```

## Versioning

### DON'T: Use 0ver or omit versioning

### DO: Use SemVer and `vim.deprecate()`

```lua
-- Deprecation warning
vim.deprecate("old_function()", "new_function()", "2.0.0", "myplugin")
```

**Automate releases:**
- luarocks-tag-release
- release-please-action
- Publish to luarocks.org

## Documentation

### DO: Provide vimdoc in `doc/` directory

**Tools:**
- vimCATS - Generate vimdoc from LuaCATS annotations
- panvimdoc - Convert Markdown to vimdoc

## Testing

### DON'T: Use plenary.nvim for testing

### DO: Use busted with luarocks

```lua
-- spec/my_plugin_spec.lua
describe("my_plugin", function()
    it("should do something", function()
        local result = require("my_plugin").do_something()
        assert.are.equal("expected", result)
    end)
end)
```

**Run tests with `nvim -l`** (Neovim 0.9+)

**Tools:**
- nvim-busted-action for CI
- nlua for Neovim as Lua interpreter
- neotest-busted for IDE integration

## Lua Compatibility

### DON'T: Use LuaJIT extensions without explicit requirement

### DO: Use Lua 5.1 API for maximum compatibility

```json
// .luarc.json
{
    "runtime.version": "Lua 5.1"
}
```

**If you need LuaJIT:**
```lua
if jit then
    -- LuaJIT-specific code
else
    -- Fallback for Lua 5.1
end
```

## Plugin Integration

Consider integrating with:
- telescope.nvim (extensions)
- lualine.nvim (components)
- nvim-treesitter (queries)

**Tip:** Expose your own API for others to hook into if you don't want to maintain compatibility with other plugin APIs.

## Project Structure

```
my-plugin/
├── lua/
│   └── my_plugin/
│       ├── init.lua
│       ├── config.lua
│       └── health.lua
├── plugin/
│   └── my_plugin.lua      # Auto-loaded, defines commands/mappings
├── ftplugin/
│   └── {filetype}.lua     # Filetype-specific initialization
├── doc/
│   └── my_plugin.txt      # Vimdoc
├── tests/
│   └── my_plugin_spec.lua # Busted tests
├── .luarc.json            # lua-language-server config
└── README.md
```

## Key Principles Summary

1. **Type Safety:** Use LuaCATS annotations
2. **Commands:** Use subcommands, not multiple top-level commands
3. **Keymaps:** Provide `<Plug>` mappings, let users define their keymaps
4. **Initialization:** Don't force `setup()`, separate config from init
5. **Lazy Loading:** Defer `require`, use `ftplugin/` for filetype-specific code
6. **Configuration:** Split user options (optional) from internal config (required)
7. **Health:** Provide `:checkhealth` support
8. **Versioning:** Use SemVer, deprecate properly
9. **Documentation:** Provide vimdoc
10. **Testing:** Use busted, not plenary.nvim
11. **Compatibility:** Target Lua 5.1 API
