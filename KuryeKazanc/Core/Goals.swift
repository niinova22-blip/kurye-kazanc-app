import Foundation

/// Net kazanc hedefi ilerlemesi (halka ve widget icin). Hedef 0 ise "ayarlanmadi".
struct GoalProgress: Equatable {
    var target: Double
    var achieved: Double

    var isSet: Bool { target > 0 }
    var fraction: Double { isSet ? min(1, max(0, achieved / target)) : 0 }
    var remaining: Double { max(0, target - achieved) }
    var isReached: Bool { isSet && achieved >= target }
}
