# Phase 9: Trigger System - Slash Commands & Inline Completions

## Executive Summary

Notion-tarzı inline trigger sistemi. TDD yaklaşımıyla, mevcut registry pattern ve picker altyapısını kullanarak.

## API Constraints (Notion API Sınırları)

### Desteklenen Mention Türleri
| Type | API Support | Implementation |
|------|-------------|----------------|
| `page` | Full | Phase 9.1 |
| `database` | Full | Phase 9.2+ |
| `date` | Full | Phase 9.3+ |
| `user` | Limited* | Deferred |
| `link_preview` | Full | Phase 9.3+ |

> *User mention: API'de user ID gerekli, ama workspace users listesi için ayrı endpoint gerekiyor ve integration permissions farklı.

### Desteklenen Renkler (Annotations)
**Text:** default, gray, brown, orange, yellow, green, blue, purple, pink, red
**Background:** *_background versiyonları (gray_background, blue_background, etc.)

### Mevcut Block Types (registry.lua)
```lua
paragraph, heading_1, heading_2, heading_3, divider, quote, bulleted_list_item, code
-- Phase 9+: numbered_list_item, to_do, toggle, callout
```

---

## Trigger Activation Rules

```
KURAL 1: Satır başında → Aktif
KURAL 2: Solunda whitespace varsa → Aktif
KURAL 3: Solunda non-whitespace varsa → Pasif
KURAL 4: Sağında whitespace olması gerekmiyor
```

**Examples:**
```
/heading     ✓ (satır başı)
text /cmd   ✓ (solda boşluk)
text/cmd    ✗ (solda boşluk yok)
word[[      ✗ (solda boşluk yok)
word [[     ✓ (solda boşluk)
```

---

## Trigger Types & Transformations

```
┌─────────────────────────────────────────────────────────────┐
│                    TRIGGER SYSTEM                           │
├─────────────────────────────────────────────────────────────┤
│  /  Slash Command                                           │
│  ├── Block Types (paragraph, heading, bullet, quote, code) │
│  ├── Text Colors (red, blue, green, etc.)                  │
│  ├── → "Link to page" transforms to [[                     │
│  ├── → "Mention page" transforms to @                       │
│  └── → "Date" transforms to @date picker                    │
├─────────────────────────────────────────────────────────────┤
│  [[  Link to Page                                           │
│  └── Page search + frecency                                 │
├─────────────────────────────────────────────────────────────┤
│  @  Mention (page/date only - user API limited)            │
│  ├── Page mention (@page search)                            │
│  └── Date mention (@today, @tomorrow, date picker)          │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture

### Module Structure
```
lua/neotion/input/
├── init.lua                    # Orchestrator (existing)
├── triggers.lua                # Enhanced: State machine + registry
├── trigger/                    # NEW
│   ├── init.lua               # Trigger type definitions
│   ├── detection.lua          # Multi-char trigger detection
│   ├── state.lua              # State machine
│   ├── slash.lua              # / command handler
│   ├── link.lua               # [[ page link handler
│   └── mention.lua            # @ mention handler
└── completion/                 # NEW
    ├── init.lua               # Completion orchestrator
    ├── blocks.lua             # Block type items (from registry)
    ├── colors.lua             # Color items
    └── pages.lua              # Page search (reuse live_search)
```

### State Machine
```
         ┌───────────────────────────────────────┐
         │                                       │
         ▼                                       │
    ┌─────────┐     char input      ┌──────────┐│
    │  IDLE   │ ──────────────────► │ DETECTING││
    └─────────┘                     └──────────┘│
         ▲                               │      │
         │                               │ match│
         │ cancel/confirm                ▼      │
         │                          ┌──────────┐│
         │                          │ TRIGGERED││
         │                          └──────────┘│
         │                               │      │
         │                               │ show │
         │                               ▼      │
         │                          ┌──────────┐│
         └────────────────────────  │COMPLETING│┘
                                    └──────────┘
                                         │ transform
                                         └─────────►
```

### Types (LuaCATS)
```lua
---@class neotion.TriggerContext
---@field bufnr integer
---@field line integer (1-indexed)
---@field col integer (1-indexed)
---@field line_content string
---@field trigger_start integer
---@field trigger_text string  -- "/", "[[", "@"

---@class neotion.CompletionItem
---@field label string
---@field icon? string
---@field description? string
---@field value any
---@field action? fun(ctx: neotion.TriggerContext, item: neotion.CompletionItem)

---@alias neotion.TriggerState 'idle'|'detecting'|'triggered'|'completing'
```

---

## Implementation Phases (TDD)

### Phase 9.0: Foundation & Detection (TDD)

**Tests First:**
```lua
-- spec/unit/input/trigger/detection_spec.lua
describe('trigger detection', function()
  describe('is_valid_position', function()
    it('returns true at line start', function() end)
    it('returns true after whitespace', function() end)
    it('returns false mid-word', function() end)
  end)

  describe('detect_trigger', function()
    it('detects / at line start', function() end)
    it('detects / after space', function() end)
    it('detects [[ after space', function() end)
    it('detects @ at line start', function() end)
    it('does not detect / mid-word', function() end)
  end)
end)
```

**Implementation:**
- [ ] `trigger/detection.lua` - Trigger pattern detection
- [ ] `trigger/state.lua` - State machine
- [ ] Tests: detection_spec.lua, state_spec.lua

### Phase 9.1: `[[` Link Completion (TDD)

**Tests First:**
```lua
-- spec/unit/input/trigger/link_spec.lua
describe('[[ link trigger', function()
  it('activates on second bracket', function() end)
  it('opens picker with cached pages', function() end)
  it('inserts markdown link on selection', function() end)
  it('replaces [[ with link text', function() end)
end)
```

**Implementation:**
- [ ] `trigger/link.lua` - Link handler
- [ ] `completion/pages.lua` - Page completion source
- [ ] Reuse `ui/picker.lua` and `ui/live_search.lua`
- [ ] Insert format: `[Page Title](notion://page/id)`

**Buffer Transformation:**
```
Before: "Check the [[meeting notes"
                    ▲ cursor
After:  "Check the [Meeting Notes](notion://page/abc123)"
```

### Phase 9.2: `/` Slash Commands - Blocks (TDD)

**Tests First:**
```lua
-- spec/unit/input/trigger/slash_spec.lua
describe('/ slash trigger', function()
  describe('block commands', function()
    it('lists all supported block types', function() end)
    it('filters by query', function() end)
    it('inserts heading prefix on selection', function() end)
    it('inserts bullet prefix on selection', function() end)
  end)
end)
```

**Implementation:**
- [ ] `trigger/slash.lua` - Slash command handler
- [ ] `completion/blocks.lua` - Block items from registry
- [ ] Dynamic generation from `registry.get_supported_types()`

**Slash Menu Items (from registry):**
```lua
{ label = 'Text', icon = 'Aa', value = 'paragraph', description = 'Plain text' }
{ label = 'Heading 1', icon = 'H1', value = 'heading_1', description = '# Large heading' }
{ label = 'Heading 2', icon = 'H2', value = 'heading_2', description = '## Medium heading' }
{ label = 'Heading 3', icon = 'H3', value = 'heading_3', description = '### Small heading' }
{ label = 'Bullet list', icon = '-', value = 'bulleted_list_item', description = '- List item' }
{ label = 'Quote', icon = '|', value = 'quote', description = '| Quote block' }
{ label = 'Code', icon = '</>', value = 'code', description = '``` Code block' }
{ label = 'Divider', icon = '---', value = 'divider', description = 'Horizontal line' }
```

### Phase 9.3: `/` Slash Commands - Colors (TDD)

**Tests First:**
```lua
-- spec/unit/input/completion/colors_spec.lua
describe('color completion', function()
  it('lists all API-supported colors', function() end)
  it('applies color annotation to selection', function() end)
  it('shows color preview in menu', function() end)
end)
```

**Implementation:**
- [ ] `completion/colors.lua` - Color items
- [ ] Color syntax: `<c:red>text</c>` (mevcut render syntax)

**Color Menu Items:**
```lua
{ label = 'Red', icon = '', value = { type = 'color', color = 'red' } }
{ label = 'Blue', icon = '', value = { type = 'color', color = 'blue' } }
-- ... tüm API destekli renkler
{ label = 'Red background', icon = '', value = { type = 'color', color = 'red_background' } }
```

### Phase 9.4: `/` Slash Commands - Transforms (TDD)

**Tests First:**
```lua
-- spec/unit/input/trigger/slash_spec.lua (continued)
describe('transform commands', function()
  it('"Link to page" transforms to [[ trigger', function() end)
  it('"Mention page" transforms to @ trigger', function() end)
  it('"Date" opens date picker', function() end)
end)
```

**Implementation:**
- [ ] Transform items in slash.lua
- [ ] State machine transition: COMPLETING -> transform -> TRIGGERED (new trigger)

**Transform Items:**
```lua
{ label = 'Link to page', icon = '', value = { type = 'transform', trigger = '[[' } }
{ label = 'Mention page', icon = '@', value = { type = 'transform', trigger = '@' } }
{ label = 'Date', icon = '', value = { type = 'transform', trigger = '@date' } }
```

### Phase 9.5: `@` Mention (TDD)

**Tests First:**
```lua
-- spec/unit/input/trigger/mention_spec.lua
describe('@ mention trigger', function()
  describe('page mention', function()
    it('opens page search', function() end)
    it('inserts page mention on selection', function() end)
  end)

  describe('date mention', function()
    it('suggests today, tomorrow, etc.', function() end)
    it('opens date picker for custom date', function() end)
    it('inserts date mention', function() end)
  end)
end)
```

**Implementation:**
- [ ] `trigger/mention.lua` - Mention handler
- [ ] Page mention: Reuse page search
- [ ] Date mention: Predefined dates + picker

**Mention Syntax (buffer representation):**
```
@[Page Title](notion://page/id)     -- page mention
@[2025-01-06]                        -- date mention
```

### Phase 9.6: UI Polish

**Implementation:**
- [ ] Highlight groups: `NeotionTrigger*`
- [ ] Extmark for active trigger indicator
- [ ] Menu header showing trigger type
- [ ] Keyboard navigation: `<C-n>`, `<C-p>`, `<CR>`, `<Esc>`

---

## Test Organization

```
spec/unit/input/
├── triggers_spec.lua              # Existing (enhance)
├── trigger/
│   ├── detection_spec.lua         # NEW
│   ├── state_spec.lua             # NEW
│   ├── slash_spec.lua             # NEW
│   ├── link_spec.lua              # NEW
│   └── mention_spec.lua           # NEW
└── completion/
    ├── blocks_spec.lua            # NEW
    ├── colors_spec.lua            # NEW
    └── pages_spec.lua             # NEW
```

---

## Keybindings (Menu Active)

| Key | Action |
|-----|--------|
| `<C-n>` | Next item |
| `<C-p>` | Previous item |
| `<CR>` | Confirm selection |
| `<Esc>` | Cancel (keep typed text) |
| `<C-e>` | Close menu |
| `<BS>` | Continue filtering (auto-close if trigger deleted) |

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `/` in code block | No activation (context-aware, future) |
| `[[` inside existing link | No activation |
| Backspace past trigger | Auto-close menu |
| No matches | Show "No results" + allow custom input |
| Rapid typing | Debounce detection |

---

## Dependencies

- **Mevcut:** `ui/picker.lua`, `ui/live_search.lua`, `cache/pages.lua`
- **Yeni:** Telescope veya native float menu
- **Optional:** nvim-cmp integration (Phase 10+)

---

## Success Criteria

- [ ] All tests pass (TDD)
- [ ] `/` shows block types from registry
- [ ] `/` shows colors from API spec
- [ ] `[[` opens page search with frecency
- [ ] `@` opens page/date completion
- [ ] Trigger transforms work (`/` -> `[[`)
- [ ] Cancel preserves typed text
- [ ] Works at line start and after whitespace

---

## Progress Tracker

### Phase 9.0: Foundation
- [x] Write `detection_spec.lua` tests
- [x] Implement `trigger/detection.lua`
- [x] Write `state_spec.lua` tests
- [x] Implement `trigger/state.lua`
- [x] Run tests, all green

### Phase 9.1: `[[` Link Completion
- [x] Write `link_spec.lua` tests
- [x] Implement `trigger/link.lua`
- [x] Implement `completion/pages.lua`
- [x] Integration with picker
- [x] Run tests, all green

### Phase 9.2: `/` Blocks
- [x] Write `slash_spec.lua` tests (blocks)
- [x] Implement `trigger/slash.lua`
- [x] Implement `completion/blocks.lua`
- [x] Run tests, all green

### Phase 9.3: `/` Colors
- [x] Write `colors_spec.lua` tests
- [x] Implement `completion/colors.lua`
- [x] Integrate colors into slash.lua
- [x] Run tests, all green

### Phase 9.4: `/` Transforms
- [ ] Write transform tests in `slash_spec.lua`
- [ ] Implement transform logic
- [ ] Run tests, all green

### Phase 9.5: `@` Mention
- [ ] Write `mention_spec.lua` tests
- [ ] Implement `trigger/mention.lua`
- [ ] Page mention integration
- [ ] Date mention + picker
- [ ] Run tests, all green

### Phase 9.6: UI Polish
- [ ] Highlight groups
- [ ] Extmark indicators
- [ ] Menu header
- [ ] Final integration test
