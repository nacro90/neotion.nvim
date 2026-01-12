---
description: Add a TODO comment to the codebase (English only)
allowed-tools: Bash, Read, Grep, Edit, Write, AskUserQuestion, mcp__serena__activate_project, mcp__serena__get_symbols_overview, mcp__serena__find_symbol
---

Add a new TODO comment to the project. **All TODOs must be written in English.**

**Description:** $ARGUMENTS

## Task

1. **Scan existing TODOs** - Find IDs and determine next available ID:
```bash
grep -rn "TODO(neotion:" --include="*.lua" lua/ | head -20
```

2. **Infer category and priority** from description:
   - **Category**: Feature (FEAT-x.x) for new functionality, Bug (11.x) for fixes, Refactor for restructuring
   - **Priority**: CRITICAL (blocking), HIGH (important), MEDIUM (normal), LOW (nice-to-have)
   - Default: Feature with MEDIUM priority unless context suggests otherwise

3. **Generate ID**:
   - Bug: Increment highest 11.x number
   - Feature: Increment highest FEAT-x.x number (e.g., FEAT-12.1 -> FEAT-12.2)
   - Refactor: REFACTOR-[short_name]

4. **Determine target file** from description context:
   - Rendering related -> `render/init.lua`
   - Sync related -> `sync/init.lua`
   - Block types -> `model/block.lua`
   - API related -> `api/` directory
   - Input/keymaps -> `input/` directory
   - If unclear, pick the most relevant file

5. **Write TODO** - Format (ENGLISH ONLY):
```lua
-- TODO(neotion:ID:PRIORITY): Short description in English
-- Optional detail lines in English
```

6. **Show result** with file path and line number

**Only ask questions if:**
- Description is ambiguous about the feature scope
- Multiple valid target files exist and choice significantly matters
- Priority would be CRITICAL (confirm before marking critical)

**Important:** If user provides description in another language, translate it to English before writing.
