# TestFlight Degisiklik Notlari

Her TestFlight surumunden ONCE en uste yeni bir `## ` bolumu ekleyin.
CI (`scripts/ci/make_release_notes.sh`) yalnizca en ustteki bolumu TestFlight "What to Test" alanina koyar.

## 1.0.0 – V1 ilk test sürümü

**Neler var**
- İlk açılış: ad, araç tipi, çalıştığın platformlar, konum izni bilgisi
- Bugün: net kazanç (brüt + bonus − giderler), net TL/saat, çalışma süresi, mesafe
- "Çalışmaya başla / bitir": yalnızca bu mod açıkken konum takibi; bitirince süre, km ve ilçe dolu kazanç formu açılır
- Kazanç ekle: elle giriş veya ekran görüntüsünden otomatik doldurma (Trendyol GO, Getir). Emin olunamayan alanlar turuncu işaretlenir
- Gider ekle: yakıt, bakım, lastik, amortisman, diğer. Km başına otomatik tahmin (Ayarlar'dan değiştirilebilir)
- Geçmiş: gün/hafta/ay özeti, günlük grafik, platform bazında toplam; kayda dokun = düzenle, sola kaydır = sil
- Ayarlar: km başı maliyet, konum izni, anonim veri paylaşımı (varsayılan kapalı, açık onaylı)

**Mutlaka gerçek cihazda test et**
1. OCR: Trendyol GO ve Getir kazanç ekranlarının görüntüsünü yükle. Tutar, bonus, paket sayısı ve tarih doğru mu? Yanlış okunan ekranın görüntüsünü (kişisel bilgileri kapatarak) geliştiriciye gönder.
2. Arka plan konumu: "Çalışmaya başla" → telefonu kilitle, 15-20 dk motorla dolaş → "Çalışmayı bitir". Km makul mü? Pil tüketimi normal mi? Üstte mavi konum göstergesi görünüyor mu?
3. Bitirince açılan formda ilçe/semt doğru mu?
4. Gece yarısını geçen vardiya (ör. 20:00–02:00) doğru süreyle kaydediliyor mu?
5. Uygulamayı "Çalışıyorum" modundayken kapatıp aç: süre ve km devam ediyor mu?

**Bilinen sınırlamalar**
- OCR şablonları gerçek ekran görüntüleriyle kalibre ediliyor; ilk sürümde bazı ekranlar "kontrol et" uyarısıyla gelebilir
- Uygulama ikonu geçici
- Veri paylaşımı onayı kaydedilir ama bu sürümde hiçbir veri cihazdan gönderilmez

## 0.1.0 – İlk iskelet

- Ana ekran taslağı ve yerel veritabanı
