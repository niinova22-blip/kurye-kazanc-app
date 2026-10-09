# TestFlight Degisiklik Notlari

Her TestFlight surumunden ONCE en uste yeni bir `## ` bolumu ekleyin.
CI (`scripts/ci/make_release_notes.sh`) yalnizca en ustteki bolumu TestFlight "What to Test" alanina koyar.

## 1.3.0

1.2 hiç yayınlanmadı; onun yenilikleri de bu sürümde.

Yeni (otomatik vardiya):
- Hareketle otomatik vardiya: çalışma saatlerinde ~3 dk araç/bisiklet hareketi olunca vardiya kendiliğinden başlar, bildirim gelir ("Bu bir vardiya değil" ile iptal). 20 dk hareketsizlikte biter.
- Otomatik km: vardiya boyunca GPS ile mesafe toplanır (tam konum saklanmaz).
- Canlı Etkinlik / Dynamic Island: süre, km, bugünkü net, ~₺/saat ve "Vardiyayı bitir".
- Bugün'de "Biten vardiyalar": kazancı girilmemiş vardiyalar burada bekler.

Yeni (sunucu, hepsi isteğe bağlı):
- Anonim kazanç paylaşımı açıksa, ekran görüntüsünden okunup değiştirilmeyen kayıtların vardiya özeti gönderilir. Görsel asla gönderilmez; internet yoksa sonra gönderilir.
- Apple ile Giriş: kayıtlar ve ayarlar günde en fazla bir kez otomatik yedeklenir; "Yedekle" ve "Geri yükle".
- Kalibrasyon: formda "Kalibrasyona gönder" ile maskelenmiş ekran metni gönderilir.
- Ekran şablonları sunucudan güncellenir.
- Profil > Verilerimi sil; Profil > Gizlilik ve KVKK.

Lütfen test et:
1. 1.1'den güncelle: eski kayıtlar duruyor mu?
2. Profil > Otomatik vardiya'yı aç, izinleri ver ("Her zaman" konum + Hareket). Motorla 5+ dk sür: vardiya kendiliğinden başlıyor mu, bildirim geliyor mu?
3. Kilit ekranında ve Dynamic Island'da süre/km görünüyor mu? "Vardiyayı bitir" sonrası "Vardiya bitti" bildirimi kazanç formunu açıyor mu?
4. 20 dk dur: vardiya bitiyor mu, "Biten vardiyalar"da görünüyor mu? Km makul mü? Pil tüketimi normal mi?
5. Yürürken veya otobüste yanlışlıkla başlıyor mu? "Bu bir vardiya değil" iptal ediyor mu?
6. Paylaşımı açık değilken ve giriş yapmamışken uygulama normal çalışıyor mu?
7. Paylaşımı aç, ekran görüntüsünden kazanç kaydet; uçak modunda kaydedip interneti açınca sorun çıkıyor mu?
8. Apple ile giriş yap → Yedekle → (mümkünse başka cihazda) Geri yükle: kayıtlar geliyor mu?
9. Kalibrasyonu aç, formda "Kalibrasyona gönder": "Gönderildi" yazıyor mu?
10. Verilerimi sil: paylaşım kapanıyor mu, telefondaki kayıtlar duruyor mu?

## 1.1.0

Yeni:
- Yeni, sade arayüz: Bugün / Analiz / Topluluk / Profil.
- Kazanç ekranının ekran görüntüsünü Fotoğraflar > Paylaş > Kurye Kazanç ile gönderebilirsin.
- "Ekran görüntülerini otomatik bul": son 48 saatin kazanç ekranlarını önerir.
- Analiz: en kârlı saatlerin, gün×saat ısı haritası, platform karşılaştırması (₺/saat, ₺/sipariş, ₺/km).
- Haftalık ve günlük net hedef; Bugün ekranında halka.
- Kayıtlarda doğrulama rozeti (Elle / Ekran görüntüsü / Doğrulandı).

Lütfen test et:
1. Güncellemeden sonra eski kayıtların duruyor mu? (1.0.0 kayıtları korunmalı)
2. Trendyol GO / Getir / Yemeksepeti / Migros kazanç ekranının görüntüsünü Paylaş menüsüyle gönder; uygulamayı açınca form doluyor mu?
3. Profil > Hedefler'e haftalık hedef gir; Bugün'deki halka doğru mu?
4. Analiz > Hafta: en kârlı saatler mantıklı mı?
5. Yanlış okunan ekranlarda "okunan metni geliştiriciye gönder" ile rapor yolla — şablonları bu raporlarla kalibre ediyoruz.

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
1. OCR: Trendyol GO ve Getir kazanç ekranlarının görüntüsünü yükle. Tutar, bonus, paket sayısı ve tarih doğru mu? Yanlış okursa formdaki "okunan metni geliştiriciye gönder" düğmesiyle raporu paylaş ve doğru değerleri rapora yaz (göndermeden önce ad/telefon gibi bilgileri silebilirsin).
2. Arka plan konumu: "Çalışmaya başla" → telefonu kilitle, 15-20 dk motorla dolaş → "Çalışmayı bitir". Km makul mü? Pil tüketimi normal mi? Üstte mavi konum göstergesi görünüyor mu?
3. Bitirince açılan formda ilçe/semt doğru mu?
4. Gece yarısını geçen vardiya (ör. 20:00–02:00) doğru süreyle kaydediliyor mu?
5. Uygulamayı "Çalışıyorum" modundayken kapatıp aç: süre ve km devam ediyor mu?

**Bilinen sınırlamalar**
- OCR şablonları gerçek ekran görüntüleriyle kalibre ediliyor; ilk sürümde bazı ekranlar "kontrol et" uyarısıyla gelebilir
- Uygulama ikonu: ilk tasarım (geri bildirime açık)
- Veri paylaşımı onayı kaydedilir ama bu sürümde hiçbir veri cihazdan gönderilmez

## 0.1.0 – İlk iskelet

- Ana ekran taslağı ve yerel veritabanı
