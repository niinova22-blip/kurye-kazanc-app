import Foundation

/// Gorselin gercek bir iPhone ekran goruntusu olup olmadigi.
enum ScreenshotAuthenticity {
    /// Portre piksel boyutlari (genislik x yukseklik). Yeni iPhone ciktikca eklenir.
    static let knownScreenSizes: Set<[Int]> = [
        [640, 1136], [750, 1334], [828, 1792], [1080, 1920], [1080, 2340],
        [1125, 2436], [1170, 2532], [1179, 2556], [1206, 2622], [1242, 2208],
        [1242, 2688], [1260, 2736], [1284, 2778], [1290, 2796], [1320, 2868],
    ]

    /// - Parameter assetIsScreenshot: PhotoKit'in `.photoScreenshot` bilgisi; erisim yoksa nil.
    static func isGenuine(assetIsScreenshot: Bool?, pixelWidth: Int, pixelHeight: Int, hasCameraMetadata: Bool) -> Bool {
        if let assetIsScreenshot { return assetIsScreenshot }
        guard !hasCameraMetadata else { return false }
        let portrait = [min(pixelWidth, pixelHeight), max(pixelWidth, pixelHeight)]
        return knownScreenSizes.contains(portrait)
    }
}

/// Bir ekran goruntusunun dogrulama degerlendirmesi. `candidate`, kullanici degeri degistirmezse alinacak seviyedir.
struct ScreenshotAssessment: Equatable {
    var isGenuine: Bool
    var templateActive: Bool
    var fingerprintOK: Bool
    var dateRecent: Bool
    var isDailyScreen: Bool
    var internallyConsistent: Bool
    var candidate: VerificationLevel
    /// Kullaniciya gosterilecek kisa aciklamalar (neden dogrulanmadi).
    var issues: [String]
}

struct ScreenshotVerifier {
    var calendar: Calendar
    var maxAgeDays = 14

    func assess(_ parsed: ParsedEarning, template: OCRTemplate?, isGenuine: Bool, referenceDate: Date) -> ScreenshotAssessment {
        var issues: [String] = []

        let templateActive = template?.status == .active && parsed.templateID == template?.id
        if template == nil {
            issues.append("Platform ekranı tanınmadı.")
        } else if !templateActive {
            issues.append("Bu platformun ekranı henüz kalibre ediliyor.")
        }

        let fingerprintOK = template.map { parsed.fingerprintMatches >= $0.minFingerprintMatches } ?? false
        if template != nil, !fingerprintOK {
            issues.append("Kazanç ekranına özgü yazılar bulunamadı.")
        }

        if !isGenuine {
            issues.append("Görsel bir iPhone ekran görüntüsü değil.")
        }

        let today = calendar.startOfDay(for: referenceDate)
        let day = calendar.startOfDay(for: parsed.date)
        let age = calendar.dateComponents([.day], from: day, to: today).day ?? Int.max
        let dateRecent = (0...maxAgeDays).contains(age)
        if !dateRecent {
            issues.append("Tarih son \(maxAgeDays) gün içinde değil.")
        }

        let isDailyScreen = parsed.period == .day || parsed.period == .unknown
        if parsed.period == .week {
            issues.append("Haftalık ekran: vardiya için günlük kazanç ekranını kullan.")
        } else if parsed.period == .order {
            issues.append("Tek sipariş ekranı: günlük kazanç ekranını kullan.")
        }

        let readsCore = !parsed.fieldsToReview.contains(.totalEarning) && !parsed.fieldsToReview.contains(.platform)
        if !readsCore {
            issues.append("Toplam tutar veya platform kesin okunamadı.")
        }

        let consistent = isConsistent(parsed, template: template)
        if !consistent {
            issues.append("Paket sayısı ile toplam tutar uyuşmuyor.")
        }

        let allPass = templateActive && fingerprintOK && isGenuine && dateRecent && isDailyScreen && readsCore && consistent
        return ScreenshotAssessment(
            isGenuine: isGenuine, templateActive: templateActive, fingerprintOK: fingerprintOK,
            dateRecent: dateRecent, isDailyScreen: isDailyScreen, internallyConsistent: consistent,
            candidate: allPass ? .verified : .ocrUnverified, issues: issues
        )
    }

    /// Paket basi ucret araligi toplam tutari aciklayabiliyor mu? Bonus ust sinira eklenir.
    private func isConsistent(_ parsed: ParsedEarning, template: OCRTemplate?) -> Bool {
        guard parsed.totalEarning > 0 else { return false }
        guard parsed.packageCount > 0,
              let minFee = template?.minPackageFee, let maxFee = template?.maxPackageFee else { return true }
        let count = Double(parsed.packageCount)
        let lower = count * minFee * 0.8
        let upper = count * maxFee * 1.5 + parsed.bonus
        return (lower...upper).contains(parsed.totalEarning)
    }
}
