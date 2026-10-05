# TestFlight Degisiklik Notlari

Her TestFlight surumunden ONCE en uste yeni bir `## ` bolumu ekleyin.
CI (`scripts/ci/make_release_notes.sh`) yalnizca en ustteki bolumu TestFlight "What to Test" alanina koyar.

## 0.1.0 – İlk iskelet

**Neler eklendi**
- Ana ekran taslağı: bugünün net kazancı, net TL/saat, çalışma süresi, mesafe
- "Çalışmaya başla / bitir" düğmesi (henüz konum takibi bağlı değil, yalnızca süre sayar)
- Yerel veritabanı (SwiftData) ve varsayılan platformlar (Trendyol GO, Getir, Yemeksepeti, Migros Hemen)

**Neler test edilmeli**
- Uygulama açılıyor mu, ana ekran düzgün görünüyor mu (küçük ekranlı iPhone'larda da)?
- "Çalışmaya başla"ya basınca süre görünüyor mu; uygulamayı kapatıp açınca mod korunuyor mu?
- "+" menüsü açılıyor mu? (Kazanç/gider ekleme ekranları henüz "yakında")

**Bilinen eksikler**
- Kazanç/gider ekleme, OCR, onboarding, geçmiş/analiz ve ayarlar sonraki sürümlerde
- Uygulama ikonu geçici
