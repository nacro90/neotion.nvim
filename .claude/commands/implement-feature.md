---
description: Implement a new feature with test-driven development approach
allowed-tools: mcp, Bash, Read, Write, Edit, MultiEdit, TodoRead, TodoWrite
---

# Feature Implementation: $ARGUMENTS

Selamlar, **$ARGUMENTS** implement etmeye başlıyoruz.

## Pre-Implementation

1. **Plan Kontrolü**: Konuyla ilgili mevcut bir plan varsa referans al
2. **Agent Danışma**: Detaylar için ilgili agentlara danışabilirsin
3. **Serena Activate:** Serena'yı aktif et

## Implementation Guidelines

### Yaklaşım
- **Test-Driven Development (TDD)** odaklı ilerle
- **ultrathink** modunda çalış
- Gerekli **neovim skills**'lerini kullan

### Davranışsal Kararlar
- **AskUserQuestion** tool'unu aktif kullan
- Her önemli karar noktasında seçenek sun
- Kullanıcıya ekleme/çıkarma yapma imkanı ver
- Varsayımlarla ilerleme, sor ve teyit al

### Test Stratejisi
- ✅ **Otomatik testlere** yoğunlaş
- ✅ Uygun durumlarda **neovim integration testlerini** kullan
- ✅ **Manuel test case'leri** oluştur (basit, 1-3 adet)

### Standartlar
- Neovim standart kullanımına ters düşmeyecek şekilde implement et
- TUI ortamında neovim standartlarına uygun geliştirme yap

## Karar Noktaları (Sor!)

Şu durumlarda **mutlaka** kullanıcıya sor:

| Durum | Örnek Soru |
|-------|------------|
| Birden fazla çözüm yolu | "A mı B mi yaklaşımını kullanalım?" |
| Performance vs simplicity | "Performans mı basitlik mi öncelikli?" |
| Breaking change riski | "Bu mevcut davranışı değiştirir, onaylıyor musun?" |
| Scope genişlemesi | "Bunu da ekleyelim mi yoksa ayrı issue mı?" |
| UX kararları | "Kullanıcı deneyimi nasıl olsun?" |

## Agent Consultation

| Durum | Agent |
|-------|-------|
| Mimari değişiklik | `architect-agent` |
| Yorum/tasarım kararları | `architect-agent` |
| TUI/UX fikirleri | `ui-ux-agent` |
| Kod review | `code-reviewer` |

## Deliverables

Lütfen şunları hazırla:

1. **İmplementasyon Planı**
   - Ne yapacağını detaylı anlat
   - Aşamaları listele

2. **Beklenen Sonuçlar**
   - Geliştirme sonunda ne beklediğimizi açıkla
   - Test senaryolarını belirt

3. **Test Stratejisi**
   - Otomatik test planı
   - Sonuçları kendinden edinmeye çalış

4. **Manuel Test Case'leri**
   - 1-3 basit test case oluştur
   - Her case için: Adımlar, Beklenen Sonuç, Başarısız Görünüm

## Workflow

```
[Feature Seçimi] → [Plan + Kullanıcı Onayı] → [Implement + Ara Sorular] → [Otomatik Test] → [Code Review] → [Manuel Test Case] → [Kullanıcı Test] → [Commit]
```

## ⚠️ Önemli Kurallar

- [ ] **İnteraktif ol** - Kararları tek başına alma, sor
- [ ] Commit yapmadan önce **bana son bir danış**
- [ ] Her aşamada ilerlemeyi raporla
- [ ] Otomatik test sonuçlarını paylaş
- [ ] Manuel test için basit case'ler oluştur
- [ ] Kullanıcı manuel testi onayladıktan sonra commit
