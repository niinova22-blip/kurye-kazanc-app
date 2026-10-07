import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalsTests: XCTestCase {
    func testProgress() {
        let half = GoalProgress(target: 10_000, achieved: 5_000)
        XCTAssertEqual(half.fraction, 0.5)
        XCTAssertEqual(half.remaining, 5_000)
        XCTAssertFalse(half.isReached)

        let over = GoalProgress(target: 1_000, achieved: 1_500)
        XCTAssertEqual(over.fraction, 1)
        XCTAssertEqual(over.remaining, 0)
        XCTAssertTrue(over.isReached)

        let negative = GoalProgress(target: 1_000, achieved: -200)
        XCTAssertEqual(negative.fraction, 0)

        let unset = GoalProgress(target: 0, achieved: 300)
        XCTAssertFalse(unset.isSet)
        XCTAssertEqual(unset.fraction, 0)
    }
}
