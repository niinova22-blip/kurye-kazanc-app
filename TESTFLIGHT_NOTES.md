# TestFlight Degisiklik Notlari

Her TestFlight surumunden ONCE en uste yeni bir `## ` bolumu ekleyin.
CI (`scripts/ci/make_release_notes.sh`) yalnizca en ustteki bolumu TestFlight "What to Test" alanina koyar.

## 1.6.0

Yeni: Hakediş sekmesi (Trendyol GO, Getir, Yemeksepeti Express, Paket Taxi / Migros Hemen).
- İlk açılışta çalıştığın platformu seç (Profil > "Hakediş platformu" ile değiştirilebilir). Platform değiştirince eski kayıtların kendi platformu ve tarife sürümüyle kalır.
- Dört yol: Hızlı tahmin (paket + süre), Detaylı günlük kayıt (gündüz/gece, birleşen paket, km, bahşiş, kesinti…), Dönem özeti (hafta/ay; kayıtlardan ya da toplamları girerek) ve Ödeme karşılaştırma (beklenen ↔ gerçekleşen, kontrol edilecek kalemler).
- Pano: bu ay tahmini brüt/net, paket, bonusa kalan, saat başına, gider, ödeme farkı + platforma özgü kart.
- Tarifeler: başlangıçtaki değerler ÖRNEK ve "Doğrulama gerekli" etiketli. Belirsiz kurallarda (km primi, bonus birleşmesi, kademe ücreti, bölge/kıdem) diğer yorumun sonucu da gösterilir. Yemeksepeti saatlik garantisi doğrulanana kadar hesaba katılmaz.
- Kendi tarifeni gir: form, CSV, ekran görüntüsü ya da PDF (taslak; onaylayınca kullanılır).
- Yeni tarife yayımlanınca yalnızca kendi platformun için bildirim. Eski kayıtlar sessizce değişmez; "Güncel tarifeyle yeniden hesapla" ayrı işlem olarak saklanır.
- Gider kategorileri: sigorta, telefon-internet, ekipman eklendi; gider ve net kazanç raporu.

Lütfen test et:
- Hakediş sekmesi > platform seç > Hızlı tahmin: 45 paket → Trendyol GO örnek tarifesiyle ~4.512 TL; kaydet → Bugün ekranında da görünmeli.
- Detaylı kayıt: teslimat başına km gir (ör. "2,5 7 4"); km satırları ve uyarılar.
- Dönem özeti ve Ödeme karşılaştırma ekranları.
- Platform değiştir → eski kayıt Geçmiş'te eski platform ve sürümüyle duruyor mu?

## 1.5.0

Bu sürüm 1.4.1'in (yayımlanmadı) her şeyini ve yeni planlama motorunu içerir.

Yeni (Plan öner):
- Bugün > "Plan öner" (ya da Profil > "Çalışma profili ve plan"): günün en kârlı, düşük riskli ve daha az saatli planı. Her planda saatler ve platformlar, brüt (düşük–yüksek), yakıt+bakım, Bağ-Kur/sabit gider, net, vergi sonrası, net/saat, km ve güven.
- Tahmin yalnızca senin kayıtlarından (son 8 hafta, aynı gün+saat) ya da platformun sana yazılı sunduğu saatlik ücretten. Veri yoksa tahmin uydurulmaz.
- Platform kuralları (slot, vardiya, iptal, devir, ücret, hakediş, askı, itiraz, çoklu platform) kaynaklı ve tarihli. Resmî kaynağı olmayan ya da 90 gündür kontrol edilmeyen koşul varsa plan "Kesin değil" görünür; koşulu kendi sözleşmene göre "Sözleşmemde var" / "Bende geçerli değil" diye işaretleyebilirsin.
- Çalışma profili: aktif platformlar, çalışma modeli, bölge, gün gün uygun saatler, aldığın slot/vardiyalar, vergi oranı, Bağ-Kur, günlük azami saat, platform geçiş süresi.
- Seçtiğin plan kurallar değişince yeniden denetlenir.

Kazanç taraması artık ekran kaydı istemiyor; ekran görüntülerinden çalışıyor.

Yeni:
- Bugün > "Kazanç taraması": kısa rehber açılır. Kullandığın uygulamalarda günlük kazanç ekranının görüntüsünü al, Kurye Kazanç'a dön. Fotoğraf izni varsa son 24 saatin ekran görüntüleri kendiliğinden okunur ve "Taramada bulunanlar" açılır. Daha önce kaydedilenler atlanır.
- Uber, TheKurye ve Banabikurye platform listesinde; bu kayıtlar artık kaydedilebiliyor.
- Haftalık özetler kaydedilmez (vardiya değil).
- Platform şablonları ekrandaki "Çalışma süresi"ni okur: saatler buna göre kurulur ve süre okunan kayıtlar (paylaşım açıksa) topluluğa gider.
- Kayıt, tarama anındaki ilçenle kaydedilir (yalnızca il/ilçe).

- Topluluk sekmesi: ilçende ₺/saat, senin ₺/saatinle karşılaştırma, gün × saat ısı haritası, platform karşılaştırması ve en iyi saatler. Paylaşım açık olmalı; bir hücre en az 5 farklı kuryeden veri gelmeden gösterilmez. Test için Sincan/Ankara'da sentetik (sahte, işaretli) kurye verisi var.

Test (yalnızca TestFlight): Profil > Test araçları > "Test: son 30 gün ve tüm fotoğraflar".

Lütfen test et:
1. Masaüstündeki Kurye-Test-30-Gun klasörünü telefona aktar (AirDrop / iCloud Drive > Fotoğraflara kaydet). Test ayarını aç, Kazanç taraması > Tara. Tek seferde en fazla 60 görüntü okunur; "Daha fazla görüntü var" yazıyorsa kaydedip tekrar tara.
2. Kaydedilen günler Analiz'de doğru günlere düşüyor mu? "Ne zaman çalışmalı" ısı haritası doluyor mu? Saatler (ör. 18:10–22:40) mantıklı mı?
3. Aynı taramayı tekrar yap: kaydedilenler yeniden listelenmemeli.
4. Test ayarı kapalıyken gerçek bir platform kazanç ekranının görüntüsünü al ve tara (kişisel bilgileri karartıp paylaşabilirsen çok iyi olur).
5. Fotoğraf iznini reddet: "Ayarlar'ı aç" görünüyor mu?
6. Topluluk: Profil'de paylaşımı aç, kayıtlarının ilçesi Sincan ise ilçe seçicide Sincan çıkıyor mu, ısı haritası ve platformlar doluyor mu? Senin ₺/saatinle karşılaştırma mantıklı mı?
7. Plan öner: 30 günlük test görüntülerini kaydettikten sonra Bugün > Plan öner. Planlar mantıklı mı? Çalışma profilinde platformları, saatleri ve Bağ-Kur'u değiştir; plan değişiyor mu?
8. Yemeksepeti'ni aktif et: slot girmeden plana alınmamalı ("slot girmedin"). Profilde bir slot ekle: plan o saati içermeli.
9. Platform kuralları ekranında kendi sözleşmene göre birkaç koşulu işaretle; "Kesin değil" uyarısı kalkıyor mu?

## 1.4.0

Yeni okuma motoru:
- Uber "Kazançlar" ekranı (platform adı olmadan), TheKurye faturalar listesi, Yemeksepeti ve Banabikurye sipariş kartları okunur. Ekrandaki çalışma süresi de okunur; KDV hariç notu gösterilir.
- Şablonlar hâlâ kalibrasyonda: gerçek ekran görüntüleri gelene kadar "Doğrulandı" çıkmaz.

Yeni (Kazanç taraması):
- Bugün > "Kazanç taraması" > Kurye Kazanç Tarama > Yayını Başlat. Platform uygulamasında kazanç panelini aç, birkaç saniye bekle, kapat. Yayını durdur, "Taramada bulunanlar"dan seç ve kaydet.
- Görüntü saklanmaz. Sipariş kartları gün + platform bazında birleşir. Haftalık özetler varsayılan seçili değildir.

Yeni (Kısayollar):
- "Kurye Kazanç'a ekran görüntüsü gönder" eylemi; tarifi Profil'de.

Lütfen test et:
1. Masaüstündeki taklit ekranları (Kurye-Senaryo-Gorselleri) Fotoğraflar'da açıp tarama yap: her ekran bir kez mi listeleniyor?
2. Tarama sürerken uygulamaya dön: sonuç ekranı açılmamalı; durdurunca açılmalı.
3. Aynı gün iki Yemeksepeti sipariş kartı tek satır mı ("2 sipariş")?
4. Bir kaydı kaydet, aynı ekranı tekrar tara: "Zaten kayıtlı" görünüyor mu?
5. Kısayollar'da "Kurye Kazanç'a ekran görüntüsü gönder" eylemi görünüyor mu, otomasyonla çalışıyor mu?
6. Pil: 5 dk taramada yüzde kaç düştü?
7. Gerçek bir platform kazanç ekranın varsa kişisel bilgileri karartıp paylaş.
8. Paneli açıp dokunmadan 5 sn bekle: Tarama günlüğü'nde "Kabul edilen" artıyor mu?

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
