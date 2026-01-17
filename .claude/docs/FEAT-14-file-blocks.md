# FEAT-14: File Block Desteği

**Tarih:** 2026-01-15  
**Durum:** Planned  
**Öncelik:** HIGH  

---

## Özet

Notion'daki file, image, video ve PDF bloklarının neotion.nvim'de görüntülenmesi ve etkileşimi.

---

## 1. Notion API Analizi

### 1.1 Media Block Tipleri

| Block Type | Notion Type | URL Türü | Expire |
|------------|-------------|----------|--------|
| `image` | Media | external/file | File: 1 saat |
| `video` | Media | external/file | File: 1 saat |
| `pdf` | Media | external/file | File: 1 saat |
| `file` | Attachment | external/file | File: 1 saat |
| `bookmark` | Link | - | Hayır |

### 1.2 API Response Yapısı

```json
// External URL (kalıcı)
{
  "type": "file",
  "file": {
    "type": "external",
    "external": { "url": "https://example.com/doc.pdf" },
    "name": "document.pdf",
    "caption": [...]
  }
}

// Notion Hosted (expiring - 1 SAAT!)
{
  "type": "file", 
  "file": {
    "type": "file",
    "file": {
      "url": "https://prod-files-secure.s3.us-west-2.amazonaws.com/...",
      "expiry_time": "2026-01-15T15:00:00.000Z"
    },
    "name": "uploaded.pdf"
  }
}
```

### 1.3 KRİTİK: URL Expiration

```
Notion Hosted URL'ler 1 SAAT sonra EXPIRE oluyor!

t=0        t=45min      t=60min       t=61min
│           │            │             │
▼           ▼            ▼             ▼
[FETCH]  [REFRESH]   [EXPIRED!]    [403 ERROR]

Çözüm: 45. dakikada background refresh
```

---

## 2. UX Tasarımı

### 2.1 Buffer Gösterimi

```
Buffer görünümü:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Normal metin içeriği burada...
  
  �� project-specification.pdf
  
  🖼️ architecture-diagram.png
  
  🎬 demo-video.mp4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Cursor üzerindeyken (K):
┌─────────────────────────────────────────┐
│ 📄 project-specification.pdf            │
│ ─────────────────────────────────────── │
│ Size:     2.4 MB                        │
│ Type:     application/pdf               │
│ Source:   Notion hosted                 │
│ Cached:   ✓ Fresh (12 min ago)          │
│ ─────────────────────────────────────── │
│ <CR> Open │ d Download │ y Yank URL    │
└─────────────────────────────────────────┘
```

### 2.2 Icon Mapping

```lua
local file_icons = {
  -- Nerd Font
  nerd = {
    pdf = " ", image = " ", video = " ",
    audio = " ", archive = " ", default = " ",
  },
  -- Emoji fallback
  emoji = {
    pdf = "📄", image = "🖼️", video = "🎬",
    audio = "🎵", archive = "📦", default = "📎",
  },
}
```

### 2.3 Tiered Opening Stratejisi

```
ENTER / gf tuşu
      │
      ▼
┌─────────────┐
│Cache kontrol│
└─────────────┘
      │
      ├─── FRESH ──────► Anında aç
      │
      ├─── STALE ──────► Aç + BG refresh
      │
      └─── NO CACHE ───► Boyut kontrol
                              │
                              ├─── < 5 MB ────► Progress ile indir
                              │
                              ├─── 5-50 MB ───► Onay al, indir
                              │
                              └─── > 50 MB ───► Uyarı + explicit
```

### 2.4 Dosya Tipine Göre Handler

| Tip | Extensions | Aksiyon |
|-----|------------|---------|
| Text | txt, md, json, yaml | Neovim buffer |
| PDF | pdf | xdg-open (veya custom) |
| Image | png, jpg, gif, webp | xdg-open / terminal preview |
| Video | mp4, webm, mov | xdg-open |
| Audio | mp3, wav, ogg | xdg-open |
| Archive | zip, tar, gz | İçerik listele |

### 2.5 Keymap'ler

| Key | Aksiyon | Açıklama |
|-----|---------|----------|
| `<CR>` | smart_open | Tiered açma (default) |
| `gf` | smart_open | Vim convention |
| `go` | external_open | Her zaman OS handler |
| `gp` | preview | Floating preview |
| `gd` | download_only | İndir, açma |
| `K` | file_info | Hover bilgi |
| `gy` | yank_url | URL'i clipboard'a |
| `gD` | delete_cache | Cache'ten sil |

---

## 3. Cache Stratejisi

### 3.1 Hybrid Cache Mimarisi

```
┌─────────────────────────────────────────────────────────┐
│                    CACHE SYSTEM                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │
│  │ URL Cache   │   │ File Cache  │   │ Meta Store  │   │
│  │ (Memory)    │   │ (Disk)      │   │ (SQLite)    │   │
│  ├─────────────┤   ├─────────────┤   ├─────────────┤   │
│  │ TTL: 45min  │   │ ~/.cache/   │   │ file_id     │   │
│  │             │   │ neotion/    │   │ name, size  │   │
│  │             │   │ files/      │   │ cached_at   │   │
│  └─────────────┘   └─────────────┘   └─────────────┘   │
│                                                         │
│  Policy:                                                │
│  - Max cache size: 500 MB (configurable)               │
│  - Eviction: LRU (Least Recently Used)                 │
│  - URL refresh: 45 dakikada                            │
│  - File TTL: image 7d, pdf 3d, other 1d                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.2 SQLite Schema

```sql
CREATE TABLE file_cache (
  file_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  size_bytes INTEGER,
  mime_type TEXT,
  source_type TEXT CHECK(source_type IN ('external', 'notion_hosted')),
  
  current_url TEXT,
  url_fetched_at INTEGER,
  url_expires_at INTEGER,
  
  local_path TEXT,
  cached_at INTEGER,
  last_accessed_at INTEGER,
  
  page_id TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_file_cache_accessed ON file_cache(last_accessed_at);
CREATE INDEX idx_file_cache_page ON file_cache(page_id);
```

### 3.3 URL Refresh Akışı

```lua
local function get_valid_url(file_id, callback)
  local cached = db.get_file_meta(file_id)
  
  if not cached then
    -- İlk kez, API'den al
    api.get_block(file_id, function(block, err)
      -- ...
    end)
    return
  end
  
  -- External URL'ler expire olmaz
  if cached.source_type == "external" then
    callback(cached.current_url)
    return
  end
  
  -- Notion hosted: expire kontrolü
  local age_minutes = (os.time() - cached.url_fetched_at) / 60
  
  if age_minutes < 45 then
    callback(cached.current_url)          -- Fresh
  elseif age_minutes < 60 then
    callback(cached.current_url)          -- Stale, kullan
    refresh_url_async(file_id)            -- BG refresh
  else
    refresh_url_async(file_id, callback)  -- Expired, yeni al
  end
end
```

---

## 4. Edge Case Çözümleri

### 4.1 Büyük Dosyalar (>10MB)

- Boyut göster ve onay al
- Background download seçeneği
- İptal mekanizması

### 4.2 Offline Mode

- Cache'te varsa uyarı ile aç
- Cache'te yoksa hata göster

### 4.3 Download Progress

- Async download with progress bar
- Cancellable
- Notification on complete

---

## 5. Dosya Yapısı

```
YENİ EKLENECEK:
lua/neotion/
├── model/blocks/
│   ├── file.lua            # File attachment block
│   ├── image.lua           # Image block  
│   ├── video.lua           # Video block
│   └── pdf.lua             # PDF block
├── cache/
│   └── files.lua           # File download & cache manager
├── ui/
│   └── file_preview.lua    # Floating preview
└── util/
    └── download.lua        # Async download
```

---

## 6. Implementasyon Fazları

### Phase 1: MVP (2-3 gün)
- [ ] File block model (read-only)
- [ ] Basic rendering (icon + name)
- [ ] Enter/gf → xdg-open
- [ ] Simple disk cache

### Phase 2: Smart Cache (2-3 gün)
- [ ] SQLite metadata storage
- [ ] URL expiration handling
- [ ] TTL-based cache invalidation
- [ ] LRU eviction

### Phase 3: Rich UX (2-3 gün)
- [ ] Hover info (K keymap)
- [ ] Download progress UI
- [ ] Large file confirmation
- [ ] Offline mode handling

### Phase 4: Advanced (opsiyonel)
- [ ] Terminal image preview (kitty/sixel)
- [ ] PDF text preview
- [ ] Archive content listing
- [ ] Batch download

---

## 7. Config

```lua
require("neotion").setup({
  files = {
    cache = {
      enabled = true,
      dir = vim.fn.stdpath("cache") .. "/neotion/files",
      max_size = "500MB",
      ttl = { image = "7d", pdf = "3d", video = "1d", other = "1d" },
    },
    large_file_threshold = "10MB",
    open_strategy = "tiered",  -- "tiered" | "always_download" | "always_external"
    handlers = {
      pdf = "zathura",         -- Custom viewer (nil = xdg-open)
    },
    icons = "nerd",            -- "nerd" | "emoji" | "ascii"
  },
})
```

---

## 8. Referanslar

- Notion API: https://developers.notion.com/reference/file-object
- İlgili TODO: `FEAT-14` (bu dosya)
- Serena memory: (oluşturulacak)
