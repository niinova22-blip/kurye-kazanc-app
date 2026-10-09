# Fotoğraflardan kazanç taraması (v2) — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox syntax.

**Goal:** Kazanç taramasını ekran kaydı yerine "rehber + son 24 saatin ekran görüntülerini otomatik okuma" akışına çevirmek; ısı haritası için süre ve ilçe; test modu.
**Spec:** `docs/superpowers/specs/2026-10-09-surum-1-4a-kazanc-taramasi-design.md` §6 (ve §1–5).

## Global Constraints
- Önceki planın kısıtları geçerli (Core saf, ASCII yorum, görüntü saklanmaz — burada görüntüler kullanıcının Fotoğraflar'ında zaten var, uygulama kopyalamaz; yalnızca OCR satırları kanıt olarak).
- Normal kullanıcıda pencere her zaman 24 saat; test penceresi yalnızca `BuildEnvironment.showsTesterTools`.
- `.order`/`.week` gönderilmez; süresiz kayıt gönderilmez (I-1 kuralı korunur).

### Task 1 (Core): tarama penceresi ve süre etiketleri
- `KuryeKazanc/Core/Scan/ScanWindow.swift`: `struct ScanWindow { static let normal: TimeInterval = 24*3600; static let test: TimeInterval = 30*24*3600; static func start(now: Date, testMode: Bool) -> Date }` + test.
- `BundledTemplates`: trendyol_go, getir, yemeksepeti, migros_hemen şablonlarına `"durationLabels": ["calisma suresi", "cevrimici sure", "cevrimici", "online sure", "aktif sure"]`; her değişen şablonun `version` +1 (yemeksepeti.earnings v3). Testler: her biri için "Çalışma süresi 6 sa 20 dk" içeren satırlarla `workDuration` okunur ve `period == .day` (ekranda "Bugün" ya da tarih) — `NewTemplatesTests`'e.
- Senaryo görüntü tabanı etkilenmemeli (süre satırı yok); CI'da `ScenarioImageTests` yeşil kalmalı.

### Task 2 (App): fotoğraf tarayıcı ve sonuç modeli kaynağı
- `KuryeKazanc/Services/Screenshots/PhotoScanService.swift` (@MainActor @Observable): `ScreenshotLibrary` protokolünü kullanır; `func scan(since: Date, includeAllPhotos: Bool, knownIdentifiers: Set<String>, knownTextHashes: Set<String>) async -> [PhotoScanResult]`; `progress (done,total)`; her görüntü `ScreenshotImporter.importImage(data:assetIdentifier:capturedAt:)` ile; şablonu olmayan / toplamı 0 olanlar elenir; `PhotoScanResult { imported: ImportedScreenshot; input: ScanInput }`.
- `ScreenshotLibrary`'ye `recentImages(since:limit:)` (tüm fotoğraflar, yalnızca test modu için) eklenir; PhotoKit uygulaması `PHAsset.fetchAssets(with: .image, options:)`.
- `ScanResultsViewModel`'e ikinci kaynak: `init(photoResults: [PhotoScanResult], knownTextHashes:, existingDaily:, region: (province, district)?, …)` — dosya yok; kayıt kanıtına `assetIdentifier` gider (sonraki taramada atlanır); kayıt öncesi form `province/district` doldurulur. Mevcut yakalama kaynağı aynen kalır.
- Süre → saat: sonuç kalemi `.daily` ve `workDuration` varsa formun bitişi = `capturedAt`, başlangıç = bitiş − süre (form zaten süreyi uyguluyor; `now: capturedAt` ile kurulur — doğrula).
- Testler: sahte kütüphane ile pencere dışı elenir, bilinen kimlik atlanır, tanınmayan elenir; ilçe kayda yazılır; assetIdentifier kanıtta.

### Task 3 (UI): rehber, otomatik tarama, test ayarı
- `ScanButton` → yayın seçici yerine `ScanGuideView` sayfası (her basışta): başlık "Kazanç taraması", kurye platformları listesi (Courier.defaultPlatforms; yoksa tümü) her biri için "Kazanç / Günlük ekranı", talimat, "Ekran görüntülerini aldım — Tara" düğmesi; izin yoksa izin ister (reddedilmişse Ayarlar'a yönlendirir). Sayfa açıkken uygulama yeniden ön plana gelirse tarama kendiliğinden başlar. Tarama sırasında ilerleme ("3/7 okunuyor"); bitince `ScanResultsView` (fotoğraf kaynağıyla); sonuç yoksa "Son 24 saatte kazanç ekranı görüntüsü bulunamadı."
- Tarama başlarken konumdan ilçe çözülür (`LocationService.currentRegion()`; izin yoksa boş).
- Profil > Test araçları (yalnızca `showsTesterTools`): "Test: son 30 gün ve tüm fotoğraflar" anahtarı (`@AppStorage("scanTestWindow")`).
- Yayın (broadcast) düğmesi ve otomatik yakalama sonuç açılışı Bugün'den kaldırılır; eklenti hedefi ve kodu kalır (kullanılmıyor notu).
- Profil'deki "Kazanç taraması" açıklaması yeni akışa göre güncellenir.

### Task 4: sürüm 1.4.1, notlar, PR
- `MARKETING_VERSION: "1.4.1"`, `TESTFLIGHT_NOTES.md` `## 1.4.1` (yeni akış, test ayarı, masaüstündeki 30 günlük görseller nasıl eklenir), `PROGRESS.md`; push develop, CI yeşil; develop→main PR (kullanıcı birleştirir).
