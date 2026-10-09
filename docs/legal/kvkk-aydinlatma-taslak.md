# Kurye Kazanç — KVKK Aydınlatma Metni (TASLAK)

> **Taslak — hukuki inceleme bekliyor.** Bu metin geliştirici tarafından hazırlanmış bir taslaktır; yayımlanmadan önce bir hukukçu tarafından incelenmelidir. Köşeli parantezli alanlar doldurulacaktır.

Sürüm: 1.3 taslağı · Tarih: [Tarih]

Bu aydınlatma metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("KVKK") 10. maddesi ve Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ uyarınca, Kurye Kazanç uygulamasını ("Uygulama") kullanan kuryeleri bilgilendirmek amacıyla hazırlanmıştır.

## 1. Veri sorumlusu

- **Veri sorumlusu:** [Veri sorumlusu] (ad / unvan)
- **Adres:** [Adres]
- **İletişim (e-posta):** [Başvuru e-postası]

## 2. Cihazda kalan veriler (işleme yok)

Aşağıdaki veriler yalnızca kurye'nin kendi telefonunda saklanır ve veri sorumlusuna aktarılmaz:

- Kazanç ve gider kayıtları, profil adı, araç türü, hedefler, ayarlar
- Vardiya sırasında kullanılan konum (mesafe ve ilçe hesabı için; tam konum saklanmaz)
- Ekran görüntüleri: cihazda metne çevrilir; görselin kendisi saklanmaz ve hiçbir zaman gönderilmez

## 3. İşlenen kişisel veriler

Kişisel veriler **yalnızca kurye ilgili özelliği açıp açık rıza verdiğinde** sunucuya gönderilir. Her özellik için ayrı rıza alınır.

### 3.1 Anonim kazanç paylaşımı ("Kazançlarımı anonim paylaş")

Yalnızca ekran görüntüsünden okunup değiştirilmeyen kayıtlar (doğrulama seviyesi `verified` veya `ocrUnverified`) gönderilir. Elle girilen veya OCR sonrası düzeltilen kayıtlar gönderilmez.

| Veri | Açıklama |
|---|---|
| Kullanıcı kimliği | Cihazda rastgele oluşturulan anonim oturum kimliği; kurye Apple ile giriş yaptıktan sonra Apple hesabına bağlı hesap kimliği (ad, telefon, e-posta ile bağlantısı yoktur) |
| Kayıt kimliği | Kaydın rastgele kimliği (aynı kaydın tekrar gönderilmemesi için) |
| Platform | Ör. Trendyol GO, Getir, Yemeksepeti, Migros |
| İl, ilçe | Semt / mahalle ve tam konum gönderilmez |
| Araç türü | Motosiklet, bisiklet vb. |
| Zaman | Haftanın günü ve 15 dakikalık başlangıç dilimi; vardiya süresi (dakika) |
| Tutarlar | Brüt kazanç, bonus, paket sayısı |
| Mesafe | 0,5 km'ye yuvarlanmış |
| Doğrulama | Doğrulama seviyesi, tanınan ekran şablonu ve sürümü |
| Metin özeti | Ekran metninin SHA-256 özeti (aynı ekran görüntüsünün iki kez sayılmaması için; metnin kendisi gönderilmez) |
| Gönderim zamanı | Sunucunun kaydı aldığı an |

### 3.2 Kalibrasyon ("Kalibrasyona katıl")

Yalnızca kurye kazanç formunda "Kalibrasyona gönder"e dokunduğunda gönderilir.

| Veri | Açıklama |
|---|---|
| Kullanıcı kimliği | Anonim oturum kimliği (veya Apple ile girişliyse hesap kimliği) |
| OCR satırları | Ekran görüntüsünden okunan metin satırları ve ekrandaki konumları; IBAN, telefon numarası, T.C. kimlik numarası ve e-posta adresi gönderilmeden önce cihazda maskelenir |
| Platform ve şablon | Tanınan platform ve ekran şablonu |
| Gönderim zamanı | Sunucunun örneği aldığı an |

Gönderilmeyenler: ekran görüntüsünün kendisi, uygulamadaki ad ve profil bilgileri. **Not:** Ekranda kurye adı veya kurye numarası yazıyorsa bunlar otomatik maskelenmez; uygulama kuryeyi bu konuda uyarır.

### 3.3 Hesap ve yedek ("Apple ile Giriş")

| Veri | Açıklama |
|---|---|
| Hesap kimliği | Apple'ın bu uygulamaya özel verdiği kullanıcı kimliği (ad ve e-posta istenmez) |
| Yedek | Cihazdaki tüm kazanç ve gider kayıtları (il, ilçe, semt ve gider notları dahil; ekran görüntüsünden okunan metin hariç), hedefler ve ayarlar |
| Yedek zamanı | Son yedeğin güncellendiği an |

## 4. İşleme amaçları

- Kuryelerin bölge ve platform bazında gerçek net kazançlarını karşılaştırabilmesi için anonim istatistik üretilmesi (3.1)
- Platform kazanç ekranlarının uygulama tarafından daha doğru tanınması (3.2)
- Kurye'nin kayıtlarını yeni telefona taşıyabilmesi (3.3)
- Kötüye kullanımın önlenmesi (günlük gönderim sınırı, tekrar eden kayıtların ayıklanması)

## 5. Hukuki sebep

Kişisel veriler KVKK m.5/1 uyarınca **açık rızaya** dayanılarak işlenir. Rıza her özellik için ayrı ayrı, uygulama içindeki onay ekranıyla alınır ve Profil ekranından istenildiği an geri alınabilir. Rıza verilmemesi uygulamanın temel işlevlerini etkilemez.

## 6. Aktarım ve yurt dışına aktarım

Veriler, hizmet sağlayıcı **Supabase** altyapısında, **Avrupa Birliği'nde (Frankfurt, Almanya — `eu-central-1`)** barındırılır. Bu durum KVKK m.9 kapsamında yurt dışına aktarım niteliğindedir ve **ayrıca açık rızaya** dayanır; ilgili özellik açılırken alınan rıza bu aktarımı da kapsar.

Veriler bunun dışında üçüncü kişilerle paylaşılmaz ve satılmaz. Topluluk istatistikleri (gelecek sürüm) yalnızca toplulaştırılmış biçimde gösterilir.

## 7. Saklama süresi

- Paylaşılan vardiyalar ve kalibrasyon örnekleri: kurye "Verilerimi sil" ile silene veya hizmet sona erene kadar; en fazla [Saklama süresi]
- Yedek: kurye "Verilerimi sil" ile silene, yeni yedekle değiştirilene veya hesap kapanana kadar
- Rıza geri alındığında cihazda bekleyen (henüz gönderilmemiş) veriler gönderilmeden silinir

## 8. İlgili kişinin hakları (KVKK m.11)

Kurye, veri sorumlusuna başvurarak:

1. Kişisel verilerinin işlenip işlenmediğini öğrenme,
2. İşlenmişse buna ilişkin bilgi talep etme,
3. İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,
4. Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,
5. Eksik veya yanlış işlenmişse düzeltilmesini isteme,
6. KVKK m.7'deki şartlar çerçevesinde silinmesini veya yok edilmesini isteme,
7. 5. ve 6. bentlerdeki işlemlerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
8. Münhasıran otomatik sistemlerle analiz edilmesi suretiyle aleyhine bir sonucun ortaya çıkmasına itiraz etme,
9. Kanuna aykırı işleme sebebiyle zarara uğraması hâlinde zararın giderilmesini talep etme

haklarına sahiptir.

## 9. Başvuru yolu ve "Verilerimi sil"

- **Uygulama içinden:** Profil > Hesap ve yedek > **"Verilerimi sil"**. Bu cihazdan kullanılan tüm kimliklerle (anonim kimlik ve Apple hesabına bağlı kimlik) gönderilmiş vardiyalar, kalibrasyon örnekleri ve yedek sunucudan silinir; tüm paylaşım rızaları kapatılır. Bu amaçla cihazda daha önce kullanılan kimliklerin oturum anahtarları, yalnızca bu cihazda ve silme tamamlanana kadar saklanır. Telefondaki kayıtlar silinmez (bunun için Profil > "Tüm kayıtları sil").
- **Yazılı başvuru:** [Adres] adresine veya [Başvuru e-postası] adresine, Veri Sorumlusuna Başvuru Usul ve Esasları Hakkında Tebliğ'e uygun olarak. Başvurular en geç 30 gün içinde ücretsiz sonuçlandırılır.
- Anonim kimlikle gönderilen veriler kişiyle eşleştirilemediğinden, uygulama dışı başvurularda kimliğin doğrulanabilmesi için uygulamanın "Verilerimi sil" seçeneğinin kullanılması önerilir.
