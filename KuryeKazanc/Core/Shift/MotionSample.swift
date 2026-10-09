import Foundation

/// CoreMotion'in bildirdigi bir hareket durumu. Bir ornek, bir sonraki ornege (veya simdiye) kadar surer.
struct MotionSample: Equatable, Codable {
    enum Kind: String, Codable {
        case automotive, cycling, walking, running, stationary, unknown
    }

    enum Confidence: Int, Codable, Comparable {
        case low, medium, high

        static func < (lhs: Confidence, rhs: Confidence) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var start: Date
    var kind: Kind
    var confidence: Confidence

    /// Vardiya sayilan hareket: arac veya bisiklet, guven orta/yuksek.
    var isMoving: Bool {
        (kind == .automotive || kind == .cycling) && confidence >= .medium
    }
}
