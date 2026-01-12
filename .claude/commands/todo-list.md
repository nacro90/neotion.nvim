---
description: List inline TODO items from codebase using grep
allowed-tools: Bash, Read, Grep
---

Kod icindeki TODO'lari grep ile bul ve listele.

Arguments: $ARGUMENTS

HEMEN su komutu calistir:

```bash
grep -rn "TODO(neotion:" --include="*.lua" lua/
```

Sonuclari goster. Her TODO icin:
- Dosya:satir numarasi
- TODO metni
- Varsa altindaki detay satirlarini da oku (-- ile baslayan)

Eger $ARGUMENTS "next" ise, sadece ilk CRITICAL veya HIGH priority olani goster.
Eger $ARGUMENTS bir ID iceriyorsa (ornek: 11.3), sadece o ID'yi goster.

TODO format: `-- TODO(neotion:ID:PRIORITY): Aciklama`
Priority sirasi: CRITICAL > HIGH > MEDIUM > LOW
