import Foundation

/// SwiftData modellerinden saf hesaplama girdilerine donusum (Core, SwiftData bilmez).

extension EarningRecord {
    var entry: EarningEntry {
        EarningEntry(
            start: startTime, end: endTime, gross: grossEarning, bonus: bonus,
            distanceKm: distanceKm, platformCode: platform?.code, packageCount: packageCount
        )
    }
}

extension ExpenseRecord {
    var entry: ExpenseEntry { ExpenseEntry(type: type, amount: amount) }
}
