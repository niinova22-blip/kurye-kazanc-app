import Foundation
import SwiftData

/// SwiftUI onizlemeleri ve UI testleri icin ornek veri.
/// Beklenen bugun ozeti (costPerKm = 2.5 ile):
///   brut 1000 + bonus 50 = 1050, mesafe 60 km -> tahmini gider 150, manuel gider 50
///   net = 850 TL, calisma suresi 6 saat (09-13 ve 12-15 cakisiyor) -> 141,67 TL/saat
enum SampleData {
    @MainActor
    static func insert(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        DataSeeder.seedPlatformsIfNeeded(in: context)
        let platforms = (try? context.fetch(FetchDescriptor<Platform>())) ?? []
        func platform(_ code: String) -> Platform? { platforms.first { $0.code == code } }

        let today = calendar.startOfDay(for: now)
        func at(_ hour: Int) -> Date { calendar.date(byAdding: .hour, value: hour, to: today)! }

        context.insert(EarningRecord(
            startTime: at(9), endTime: at(13), platform: platform("yemeksepeti"),
            province: "İstanbul", district: "Kadıköy",
            grossEarning: 600, bonus: 50, distanceKm: 40, packageCount: 14, source: .manual
        ))
        context.insert(EarningRecord(
            startTime: at(12), endTime: at(15), platform: platform("migros_hemen"),
            province: "İstanbul", district: "Ataşehir",
            grossEarning: 400, bonus: 0, distanceKm: 20, packageCount: 9, source: .ocr, verification: .ocrUnverified
        ))
        context.insert(ExpenseRecord(date: today, type: .other, amount: 50, note: "Otopark"))

        if (try? context.fetchCount(FetchDescriptor<Courier>())) == 0 {
            context.insert(Courier(
                name: "Örnek Kurye", vehicleType: .motorcycle,
                defaultPlatforms: [platform("yemeksepeti"), platform("migros_hemen")].compactMap { $0 }
            ))
        }
        try? context.save()
    }

    @MainActor
    static var previewContainer: ModelContainer {
        let container = ModelContainerFactory.make(inMemory: true)
        insert(into: container.mainContext)
        return container
    }
}
