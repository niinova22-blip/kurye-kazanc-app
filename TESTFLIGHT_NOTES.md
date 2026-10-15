# TestFlight Degisiklik Notlari

Her TestFlight surumunden ONCE en uste yeni bir `## ` bolumu ekleyin.
CI (`scripts/ci/make_release_notes.sh`) yalnizca en ustteki bolumu TestFlight "What to Test" alanina koyar.

## 1.12.0

Yeni:
- Çökme düzeltmesi: uygulama uzun süre arka planda kalıp açılınca kapanmasına yol açabilecek durumlar giderildi (telefon yeniden başladıktan sonra kilit açılmadan arka planda çalışma, bozuk süre/yüzde değerleri, boş listeler, üst üste senkron).
- Çalışma hızın: kurulumda hedef ekranında "Saatte kaç paket atıyorsun?" (varsayılan 2,5). Profil > Çalışma hızın'dan istediğin zaman değiştir; kayıtlarından ölçülen hızı tek dokunuşla kullan.
- Çalıştığın bölge: Profil > Çalıştığın bölge'den elle seç ya da "Konumumdan bul" (elle hesap yapanlar için).
- Otomatik vardiya artık kurulumda konum izninden sonra doğrudan soruluyor.
- Bildirim izni kurulumda soruluyor. Hedef kayıtlıysa gün içinde (12:00, 16:00, 19:00) "Bugünkü hedefe 20 paket var · 1.250 TL daha kazanalım", geç kalıyorsan "saatte 6 paket atman lazım"; haftalık/aylık hedefte ertesi sabah tempon. Profil > Bildirimler'den kapatılabilir.
- Kilit ekranından paket sayma: vardiya sürerken Canlı Etkinlikte "Paket bıraktım" (+1), "Geri al" ve "Bitir". Dynamic Island'da paket sayısı.
- Otomatik vardiya başlayınca paket sayma da başlar; 20 dk durunca vardiya kendiliğinden hesaplanıp kaydedilir.
- Widget: ana ekran ve kilit ekranı için "Paket say" (+1 paket, vardiya yoksa başlatır; orta boyda "Vardiya" ekranı). iOS 18'de Denetim Merkezi / kilit ekranı kontrolü "Paket bıraktım".

Lütfen test et:
- Uygulamayı uzun süre arka planda bırakıp aç (özellikle otomatik vardiya açıkken).
- Silip kur: hedef ekranında hızı değiştir, konum adımında otomatik vardiya sorusu ve bildirim izni.
- Vardiya başlat → telefonu kilitle → kilit ekranında "Paket bıraktım"a birkaç kez bas, Geri al, Bitir.
- Ana ekrana "Kurye Kazanç" widget'ı ekle, +1 pakete bas.

## 1.9.0

Yeni:
- Artık yalnızca iki firma: Yemeksepeti Express ve Paket Taxi. Paket Taxi seçilince kol sorulur: Restoran, Migros ya da Migros Hemen (her kolun tarifesi ayrı). Getir ve Trendyol GO kaldırıldı; bu firmayı seçmiş olanlar ilk açılışta firmasını yeniden seçer (eski kayıtlar durur).
- Yemeksepeti 2026: gün ve saate göre paket ücreti (Pzt–Per / Cuma / Cumartesi / Pazar × 6 saat bandı), Pazar 17:00 sonrası ve gece 01:00 sonrası +15 TL, km 3,70 TL, günlük bonus 17–60+ paket, haftalık bonus şehir grubuna göre (İstanbul / Ankara–İzmir / 3. grup iller / diğer iller, resmî sitedeki baremler). Yan haklar: çalışma saati zorunluluğu yok, online bahşiş, muhasebe desteği.
- Paket Taxi 2026 (resmî paylaşım): 1. / 2–3. / 4. bölge. Restoran: günlük saate (9–12) göre sabit ücret, kıdem primi, 21./26. paketten itibaren paket primi. Migros ve Migros Hemen: sabit 55.223 TL, bölgeye göre günlük paket primi, aylık bonus 700–1.800+ paket; Hemen'de km desteği (4–6 km 25 TL, 6+ km 35 TL); öğle yemeği, 1,5 saat mola.
- Bölge konumdan: Paket Taxi'de ilçe / semte göre 1., 2–3. ya da 4. bölge; Yemeksepeti'nde şehir grubu.
- Canlı vardiya: Bugün > "Vardiya başlat". Her paketi bırakınca ekrana bir kez dokun; tüm ekran marka rengine döner, her dokunuşta paketin tarifedeki yeri yazar (ör. "4–6 km bandı · 1 paket eklendi", "Akşam bandı · paket başı 67,50–78,50 TL"). Yanlış dokunuşta "Geri al".
- İlk "Vardiya başlat"ta kısa tanıtım filmi; sonra Bugün'deki "Nasıl çalışır?", vardiya ekranındaki "?" ya da Profil > "Vardiya tanıtımını izle" ile tekrar.
- Konumdan bölge: vardiya başlayınca il bulunur. Yemeksepeti'nde Ankara/İzmir haftalık bonusu, Paket Taxi'de İstanbul/Ankara dışında standart bölge kendiliğinden seçilir; İstanbul/Ankara'da Plus mı standart mı bir kez sorulur.
- Vardiyayı bitir: hesap kendiliğinden yapılır ve kaydedilir (paketler, km, saat, sabit ücretin günlük payı, yakıt, cebine kalan). Bugün'deki hedef çubuğu her dokunuşta dolar.
- Kazanç: "Hızlı tahmin" ve "Detaylı kayıt" kalktı. Vardiyalar kendiliğinden düşer; unuttuğun günler için "Elle hesapla" (paket, km, süre; günlük, haftalık ya da aylık).
- Ayrıntılı döküm: Plan, vardiya özeti ve Elle hesapla'da açılır bölüm; paketlerden, km'den, bonuslardan ve aylık sabit ücretin güne düşen payından ayrı ayrı.
- "Daha iyi yollar": tüm öneriler dokununca uygulanır ("Hedefimi buna yükselt", "Akşam saatleriyle planla").
- Konum izni kurulumda doğrudan sorulur.

Lütfen test et:
- Uygulamayı silip kur: Paket Taxi seç → kol → bölge (Restoran'da saat) ya da Yemeksepeti → şehir grubu.
- Paket Taxi Migros, 1. bölge, Plan'da aylık hedef: günde 38 paket × 26 gün ≈ 144.103 TL brüt (resmî örnekle aynı).
- Bugün > Vardiya başlat: tanıtım filmi → vardiya ekranı. Birkaç paket dokun (farklı yerlerde), Geri al, küçült (Bugün'de "Vardiya sürüyor" kartı), tekrar aç, bitir → özet ve "Ayrıntılı döküm".
- Kazanç > Elle hesapla: günlük, haftalık, aylık.
- Plan > Daha iyi yollar: bir öneriye dokun, hedefin değiştiğini gör.

## 1.8.0

Yeni:
- İlk ekran: "Hangi firmayla çalışıyorsun?" — firma tanıtımdan önce seçilir; tanıtım ve tüm hesaplar o firmaya göre.
- Yeni tanıtım: hareketli marka zemini, cam kartlar, her sayfaya yeni animasyon, "Daha iyi yollar" sayfası.
- Yeni tasarım ve renkler (indigo/mor marka, nane yeşili para), yeni uygulama ikonu, Bugün ekranında yeni ana kart.
- Tarifeler internetten araştırılıp güncellendi:
  - Paket Taxi: firmanın kendi sitesindeki 2026 ücretleri — sabit ücret İstanbul/Ankara Plus 65.223 TL, diğer bölgeler 53.223 TL; aylık paket bonusu (700 → 12.000 … 1.700 → 55.600, 1.800+ → 66.870 TL); 4–6 km teslimata +25 TL, 6 km üzerine +35 TL. Paket başı ayrı ücret ve kıdem tarifesi kalktı.
  - Yemeksepeti: 2026 tablosu — saate/güne göre paket ücreti (59–78,5 TL), km 3,7 TL, günlük 17–60+ paket bonusu, Ankara/İzmir haftalık bonusu (kurulumda sorulur).
  - Getir ve Trendyol GO: güncel kaynaklarla karşılaştırıldı, değerler aynı.
- Plan ekranı: tutar girince klavye "Bitti" ile ve kaydedince kapanır; günlük hedefte gün seçimi yok; haftalık/aylıkta çalışacağın günleri (Pzt–Paz) seçersin (hafta sonu bonusu buna göre).
- Plan sonucu sade Türkçe: "Hedefine ulaşmak için günde X paket, Y saat", "Paket yapmasan da alacakların", "Firmadan alacağın − yakıt = cebine kalan".
- "Daha iyi yollar": aynı paraya daha az saatle (gün sayısı, bonus eşiği, akşam saatleri) ya da sonraki aylık kademeyle daha çok net; "Bu planı uygula".
- Kaldırıldı: kurulumdaki "bölgendeki kuryelerle karşılaştır" (anonim paylaşım) adımı ve Profil'deki paylaşım bölümü; kurulumda tekrar eden araç sorusu; uzun açıklamalar kısaltıldı.

Lütfen test et:
- Uygulamayı silip kur: firma seç → tanıtım → sorular → yakıt → hedef.
- Plan: Günlük/Haftalık/Aylık geçişi, gün çipleri, klavye kapanması, "Daha iyi yollar" ve "Bu planı uygula".
- Paket Taxi seçip aylık 70.000 TL hedef: 700 paket civarı ve "Ayda 1.700 pakete çık" önerisi.

## 1.7.0

Yeni:
- Tanıtım: ilk açılışta 6 sayfalık animasyonlu tanıtım; her ekrandaki soru balonu (?) > "Uygulamayı tanı" ya da Profil > "Tanıtımı izle" ile tekrar.
- Kurulum: "Hangi firmayla çalışıyorsun?" (Getir, Trendyol GO, Yemeksepeti, Paket Taxi). Firmanın tarifesine göre bölge, kıdem, kadın istihdam desteği, araç soruları; yakıt fiyatı ve hedef. Profil > Ayarlar > Çalıştığım firma ile değişir.
- Hedef planı: günlük/haftalık/aylık NET hedef (yakıt düşülmüş). Sonuç kartı: zaten alacakların (sabit ücret, destekler), bölge, ayda/günde paket, günde saat, brüt − yakıt = net, sonraki kademe ipucu. Bugün ekranında günlük pay.
- Firmalar sekmesi (Topluluk yerine): aynı işi diğer firmalarda yapsan ne kazanırdın (yeni başlayan kademesiyle), tarife detayı, kampanyalar, tarife–yakıt ilişkisi; tarifeler değişip başka firma ≥%5 kazançlı olursa bildirim.
- Yakıt: Profil > Araç ve yakıt (fiyat + tarih + tüketim, geçmiş). Km gideri = km × tüketim × fiyat. Fiyat 7 günden eskiyse hatırlatma.
- Kazanç sekmesi: Hakediş + Analiz tek sekmede. Teknik ekranlar Profil > Gelişmiş'te.
- "Doğrulanmamış" uyarıları artık her sayfanın altında tek not.
- Giriş alanları: odak çerçevesi, titreşim, kaydetme onay animasyonu, −/+ seçiciler.
- Kaldırıldı: Vardiyayı başlat düğmesi (otomatik vardiya sürerken yalnızca "Vardiyayı bitir"), Topluluk, ekran kaydı eklentisi.
- Test sürümü: Profil > Test araçları > Test senaryoları (4 hazır senaryo) ve Veritabanı görüntüleyici.

Lütfen test et:
- Test senaryoları > "Paket Taxi · 30 gün" yükle → Plan: aylık 100.000 TL için paket/saat/bölge kartı; Veritabanı'nda 26 kazanç satırı; "Senaryoyu sil".
- "Tarife değişti + yakıt arttı" → Firmalar'da bildirim şeridi ve Trendyol GO detayında "Yakıt değişimiyle uyumlu".
- Soru balonu > Uygulamayı tanı; Profil > Çalıştığım firma ile firma değiştir.

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
