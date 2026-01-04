---
name: tree-sitter-grammar
description: Custom Tree-sitter grammar yazımı. Neovim entegrasyonu, highlight/conceal queries.
---

# Tree-sitter Grammar Skill

## Temel Yapı
```
tree-sitter-neotion/
├── grammar.js           # Grammar tanımı
├── src/
│   ├── parser.c         # Generated
│   ├── scanner.c        # External scanner (optional)
│   └── tree_sitter/
│       └── parser.h
├── queries/
│   ├── highlights.scm   # Syntax highlighting
│   ├── injections.scm   # Language injection
│   └── locals.scm       # Scope tanımları
├── bindings/
│   └── rust/            # Rust bindings
├── package.json
└── Cargo.toml
```

## grammar.js Temelleri
```javascript
module.exports = grammar({
  name: 'neotion',
  
  // External scanner (complex tokens için)
  externals: $ => [
    $.block_start,
    $.block_end,
  ],
  
  // Token precedence
  precedences: $ => [
    ['bold', 'italic'],
  ],
  
  // Conflict resolution
  conflicts: $ => [
    [$.paragraph, $.heading],
  ],
  
  // Inline vs block (whitespace handling)
  inline: $ => [
    $._inline,
  ],
  
  // Extra tokens (her yerde olabilir)
  extras: $ => [
    /\s/,
    $.comment,
  ],
  
  rules: {
    // Root rule
    document: $ => repeat($._block),
    
    // Block types
    _block: $ => choice(
      $.heading,
      $.paragraph,
      $.toggle_block,
      $.callout,
      $.code_block,
    ),
    
    // Heading
    heading: $ => seq(
      field('marker', $.heading_marker),
      field('content', $.inline_content),
    ),
    
    heading_marker: $ => token(prec(1, /#{1,3} /)),
    
    // Paragraph
    paragraph: $ => prec.right(repeat1($._inline)),
    
    // Inline content
    _inline: $ => choice(
      $.text,
      $.bold,
      $.italic,
      $.code_span,
      $.mention,
      $.link,
    ),
    
    // Bold
    bold: $ => seq(
      '**',
      repeat1($._inline),
      '**',
    ),
    
    // Block markers (concealed)
    block_id: $ => seq(
      '╔',
      field('type', $.identifier),
      ':',
      field('id', $.uuid),
      optional($.block_attributes),
    ),
    
    // External scanner tokens
    uuid: $ => /[0-9a-f]{32}/,
    identifier: $ => /[a-z_]+/,
  },
});
```

## External Scanner (scanner.c)

Karmaşık tokenlar için (nested blocks, context-aware parsing):
```c
#include <tree_sitter/parser.h>
#include <wctype.h>

enum TokenType {
  BLOCK_START,
  BLOCK_END,
};

void *tree_sitter_neotion_external_scanner_create() {
  return NULL;
}

void tree_sitter_neotion_external_scanner_destroy(void *payload) {}

unsigned tree_sitter_neotion_external_scanner_serialize(
  void *payload,
  char *buffer
) {
  return 0;
}

void tree_sitter_neotion_external_scanner_deserialize(
  void *payload,
  const char *buffer,
  unsigned length
) {}

bool tree_sitter_neotion_external_scanner_scan(
  void *payload,
  TSLexer *lexer,
  const bool *valid_symbols
) {
  if (valid_symbols[BLOCK_START]) {
    if (lexer->lookahead == L'╔') {
      lexer->advance(lexer, false);
      lexer->result_symbol = BLOCK_START;
      return true;
    }
  }
  
  if (valid_symbols[BLOCK_END]) {
    if (lexer->lookahead == L'╚') {
      lexer->advance(lexer, false);
      lexer->result_symbol = BLOCK_END;
      return true;
    }
  }
  
  return false;
}
```

## Neovim Entegrasyonu

### Parser Kayıt
```lua
-- after/plugin/neotion-treesitter.lua
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

parser_config.neotion = {
  install_info = {
    url = "https://github.com/user/tree-sitter-neotion",
    files = {"src/parser.c", "src/scanner.c"},
    branch = "main",
  },
  filetype = "neotion",
}
```

### Highlight Queries
```scheme
; queries/neotion/highlights.scm

; Headings
(heading
  marker: (heading_marker) @punctuation.special
  content: (_) @markup.heading)

((heading_marker) @markup.heading.1
  (#match? @markup.heading.1 "^# "))

((heading_marker) @markup.heading.2
  (#match? @markup.heading.2 "^## "))

; Inline formatting
(bold) @markup.strong
(italic) @markup.italic
(code_span) @markup.raw

; Block markers (to be concealed)
(block_id) @comment

; Mentions
(mention
  type: "user") @markup.link
(mention
  type: "page") @markup.link.url

; Colors
(colored_text
  color: "red") @neotion.red
(colored_text
  color: "blue") @neotion.blue
```

### Conceal Queries
```scheme
; queries/neotion/conceal.scm

; Block markers gizle
((block_id) @conceal
  (#set! conceal ""))

; Bold markers
(bold
  "**" @conceal
  (#set! conceal ""))

; Toggle marker -> icon
((toggle_marker) @conceal
  (#set! conceal "▶"))
```

### Injection Queries
```scheme
; queries/neotion/injections.scm

; Code block içine dil injection
((code_block
  language: (language_identifier) @injection.language
  content: (code_content) @injection.content))

; Markdown injection for paragraphs
((paragraph) @injection.content
  (#set! injection.language "markdown_inline"))
```

## Neovim'de Kullanım
```lua
-- Treesitter highlight'ı aç
vim.treesitter.start(buf, "neotion")

-- Query çalıştır
local query = vim.treesitter.query.parse("neotion", [[
  (heading
    content: (_) @heading.content)
]])

local parser = vim.treesitter.get_parser(buf, "neotion")
local tree = parser:parse()[1]

for id, node, metadata in query:iter_captures(tree:root(), buf) do
  local name = query.captures[id]
  local start_row, start_col, end_row, end_col = node:range()
  -- Process capture
end
```

## Test Etme
```bash
# Grammar build
cd tree-sitter-neotion
tree-sitter generate

# Parse test
tree-sitter parse example.neotion

# Highlight test
tree-sitter highlight example.neotion
```

## Best Practices

1. **Incremental parsing** - Büyük dosyalarda performans için
2. **Error recovery** - Hatalı syntax'ta da çalışmaya devam et
3. **Precedence** - Ambiguous grammar'da doğru öncelik
4. **Field names** - Node'lara isim ver, query'lerde kullan
5. **External scanner** - Context-aware tokenization gerektiğinde
