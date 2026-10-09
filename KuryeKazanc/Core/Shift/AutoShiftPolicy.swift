import Foundation

/// Otomatik vardiya kurallari (spec 4). Saf: zaman ve ornekler disaridan verilir.
struct AutoShiftPolicy {
    /// Baslatmak icin gereken kesintisiz hareket.
    var requiredMovement: TimeInterval = 180
    /// Geriye bakilan pencere.
    var lookback: TimeInterval = 600
    /// Bu sureden kisa durmalar (kirmizi isik) hareketi bolmez.
    var stopTolerance: TimeInterval = 60
    /// Otomatik vardiya bu kadar duragan kalinca biter.
    var stationaryLimit: TimeInterval = 1200
    /// "Bu bir vardiya degil" sonrasi yeniden baslatma yasagi.
    var cancelCooldown: TimeInterval = 1800
    var minimumDuration: TimeInterval = 300
    var minimumDistanceKm: Double = 1

    enum StartDecision: Equatable {
        case wait
        case start(at: Date)
    }

    func startDecision(
        samples: [MotionSample],
        now: Date,
        workHours: WorkHours,
        calendar: Calendar,
        lastCancel: Date?
    ) -> StartDecision {
        if let lastCancel, now.timeIntervalSince(lastCancel) < cancelCooldown { return .wait }
        guard workHours.contains(now, calendar: calendar) else { return .wait }

        let windowStart = now.addingTimeInterval(-lookback)
        let sorted = samples.sorted { $0.start < $1.start }

        var runStart: Date?
        var moving: TimeInterval = 0
        for index in sorted.indices {
            let sample = sorted[index]
            let rawEnd = index + 1 < sorted.count ? sorted[index + 1].start : now
            let end = min(rawEnd, now)
            let start = max(sample.start, windowStart)
            guard end > start else { continue }
            let duration = end.timeIntervalSince(start)

            if sample.isMoving {
                if runStart == nil {
                    runStart = start
                    moving = 0
                }
                moving += duration
            } else if runStart != nil, duration >= stopTolerance {
                runStart = nil
                moving = 0
            }
        }

        guard let runStart, moving >= requiredMovement else { return .wait }
        return .start(at: runStart)
    }

    func shouldStop(lastMovement: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastMovement) >= stationaryLimit
    }

    /// Hem kisa hem yakin vardiya sessizce atilir.
    func isTooShort(duration: TimeInterval, distanceKm: Double) -> Bool {
        duration < minimumDuration && distanceKm < minimumDistanceKm
    }
}
