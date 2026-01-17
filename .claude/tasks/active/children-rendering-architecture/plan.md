# Children Rendering Architecture - Strategic Plan

## Executive Summary

Notion block'larının children desteğini neotion.nvim'e eklemek. Toggle, quote, list item gibi block'lar child block'lara sahip olabilir. Bu children'lar indented olarak render edilmeli ve sync sırasında parent block'un children'ı olarak API'ye gönderilmeli.

## Current State

### What Exists
- `has_children` field Block base class'ta var ama her zaman `false` dönüyor
- `blocks_api.get_children()` ve `blocks_api.append()` API fonksiyonları hazır
- `parent_id` Block class'ta mevcut (`raw.parent.block_id`)
- Indented satırlar için editing behavior (2-space indent) toggle'da eklendi
- Tüm nested-capable block'lar (toggle, quote, bulleted_list, numbered_list) `has_children() = false` override ediyor

### Pain Points / Issues
1. **No children rendering**: API'den gelen `has_children: true` block'ların children'ları fetch edilmiyor
2. **Flat structure**: Tüm block'lar flat list olarak render ediliyor, hierarchy yok
3. **Orphan detection fails**: Indented satırlar sibling block olarak algılanıyor, parent'ın child'ı olarak değil
4. **Sync broken**: `  ` indented satırlar page-level sibling olarak sync ediliyor

### Log Evidence
```
New block to create from orphan | {"content_preview":"  icine","after_block_id":"temp_xxx","block_type":"paragraph"}
```
Bu satır toggle'ın child'ı olması gerekirken, sibling olarak oluşturuluyor.

## Proposed Solution

### Buffer Representation
```
> Toggle header          ← toggle block (line 1)
  Child paragraph 1      ← toggle's child (indented, lines 2-N)
  Child paragraph 2
  - Child bullet         ← also toggle's child
Normal paragraph         ← NOT toggle's child (no indent)
```

### Architecture
1. **Hierarchical Model**: Block'lar `children: Block[]` field'ına sahip olacak
2. **Indent-based Detection**: 2-space indent = parent'ın child'ı
3. **Recursive Rendering**: Parent render ederken children'ı da indented render et
4. **Parent-aware Sync**: Indented satırları parent'ın child'ı olarak sync et

### Key Decisions
- **Indent = 2 spaces** (consistent with current toggle behavior)
- **Children fetch on expand** (lazy loading, MVP: always fetch on page load)
- **Parent tracking via indentation** (buffer-level), `parent_id` (model-level)

## Implementation Phases

### Phase 1: Model Layer - Children Storage
- [ ] Add `children: Block[]` field to Block base class
- [ ] Implement `add_child(block)` and `remove_child(block)` methods
- [ ] Update `has_children()` to return `#self.children > 0`
- [ ] Add `get_children()` method

### Phase 2: API Integration - Fetch Children
- [ ] Modify `blocks_api.get_all_children()` to recursively fetch nested children
- [ ] Store fetched children in parent block's `children` field
- [ ] Update registry deserialize to handle nested structure

### Phase 3: Rendering - Indented Display
- [ ] Update `Block:format(opts)` to accept `depth` parameter
- [ ] Implement recursive rendering with indentation
- [ ] Update extmark system to track parent-child line ranges
- [ ] Handle multi-line children (soft breaks)

### Phase 4: Detection - Indent Parsing
- [ ] Create `detect_parent_from_indent(lines, line_num)` function
- [ ] Modify orphan detection to consider indent hierarchy
- [ ] Track indent-to-parent mapping in buffer model

### Phase 5: Sync - Parent-aware Creation
- [ ] Modify `create_from_orphans()` to detect parent from indent
- [ ] Use `blocks_api.append(parent_id, children)` for nested creates
- [ ] Handle moving blocks between parents (indent/dedent)

### Phase 6: Editing - Indent Navigation ✅
- [x] `Tab` to indent (become child of previous sibling)
- [x] `Shift+Tab` to dedent (become sibling of parent)
- [x] Unit tests (17 new tests, TDD approach)
- [ ] Update Enter behavior for nested contexts (deferred)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Deep nesting complexity | Medium | High | Limit to 3 levels initially |
| Extmark tracking breaks | Medium | High | Extensive testing, rebuild extmarks on sync |
| Performance with many children | Low | Medium | Lazy loading, virtualization future |
| Circular parent references | Low | Critical | Validate parent chain on add_child |

## Success Metrics

- [x] Toggle children render indented correctly
- [x] Enter in toggle creates child, not sibling
- [x] Sync creates children with correct parent_id
- [x] Tab/Shift+Tab changes parent correctly
- [x] Nested bulleted lists work
- [x] All existing tests pass (62 editing tests)

## Dependencies

- **Blocks on**: Toggle block support (DONE)
- **Blocked by this**: Toggle heading, Callout, deeply nested lists

## Estimated Effort

**Size: L (Large)**
- Model changes: 1-2 sessions ✅
- API integration: 1 session ✅
- Rendering: 2-3 sessions ✅
- Detection & Sync: 2-3 sessions ✅
- Editing: 1-2 sessions ✅
- Testing: 1-2 sessions ✅

**Total: 8-13 sessions** → **Actual: 6 sessions**

## Notes

- Start with toggle as primary use case, then generalize
- Keep backward compatibility with flat block list
- MVP: fetch all children on page load (no lazy loading)
- Future: collapse/expand UI, lazy fetch



