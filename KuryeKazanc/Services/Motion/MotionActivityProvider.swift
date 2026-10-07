import Foundation
import CoreMotion

protocol MotionActivityProviding {
    var isAvailable: Bool { get }
    var isAuthorized: Bool { get }
    /// Izin diyalogunu tetikler (CoreMotion icin ilk sorgu izni ister).
    func requestAccess() async -> Bool
    func samples(from start: Date, to end: Date) async -> [MotionSample]
}

/// CMMotionActivityManager sarmalayicisi. Gecmis sorgusu uygulama kapaliyken biriken hareketi de dondurur.
final class CoreMotionActivityProvider: MotionActivityProviding {
    private let manager = CMMotionActivityManager()
    private let queue = OperationQueue()

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    var isAuthorized: Bool { CMMotionActivityManager.authorizationStatus() == .authorized }

    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        let now = Date()
        _ = await samples(from: now.addingTimeInterval(-60), to: now)
        return isAuthorized
    }

    func samples(from start: Date, to end: Date) async -> [MotionSample] {
        guard isAvailable else { return [] }
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: start, to: end, to: queue) { activities, _ in
                let list: [CMMotionActivity] = activities ?? []
                continuation.resume(returning: list.map(Self.sample(from:)))
            }
        }
    }

    static func sample(from activity: CMMotionActivity) -> MotionSample {
        let kind: MotionSample.Kind
        if activity.automotive {
            kind = .automotive
        } else if activity.cycling {
            kind = .cycling
        } else if activity.running {
            kind = .running
        } else if activity.walking {
            kind = .walking
        } else if activity.stationary {
            kind = .stationary
        } else {
            kind = .unknown
        }
        let confidence: MotionSample.Confidence
        switch activity.confidence {
        case .high: confidence = .high
        case .medium: confidence = .medium
        default: confidence = .low
        }
        return MotionSample(start: activity.startDate, kind: kind, confidence: confidence)
    }
}
