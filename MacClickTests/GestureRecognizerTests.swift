import XCTest

final class GestureRecognizerTests: XCTestCase {
    private var recognizer = GestureRecognizer()

    private func frame(_ ids: [Int32], at time: Double, dx: Float = 0, dy: Float = 0) -> Gesture? {
        send(ids.map { contact($0, dx: dx, dy: dy) }, at: time)
    }

    private func contact(_ id: Int32, dx: Float = 0, dy: Float = 0) -> MacClickContact {
        .init(id: id, x: 0.20 + Float(id) * 0.09 + dx, y: 0.45 + dy)
    }

    private func send(_ contacts: [MacClickContact], at time: Double) -> Gesture? {
        contacts.withUnsafeBufferPointer { recognizer.consume($0, at: time) }
    }

    func testThreeFingerTapFiresOnceOnRelease() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(frame([3, 1, 2], at: 0.05, dx: 0.018))
        XCTAssertEqual(frame([], at: 0.11), .threeFingerTap)
        XCTAssertNil(frame([], at: 0.12))
    }

    func testStaggeredFourFingerTapDoesNotEmitThreeFingerTap() {
        XCTAssertNil(frame([1], at: 0))
        XCTAssertNil(frame([1, 2, 3], at: 0.035))
        XCTAssertNil(frame([1, 2, 3, 4], at: 0.07))
        XCTAssertNil(frame([1, 2, 4], at: 0.10))
        XCTAssertNil(frame([4], at: 0.13))
        XCTAssertEqual(frame([], at: 0.16), .fourFingerTap)
    }

    func testStaggeredThreeFingerTap() {
        XCTAssertNil(frame([1, 2], at: 0))
        XCTAssertNil(frame([1, 2, 3], at: 0.05))
        XCTAssertNil(frame([2, 3], at: 0.08))
        XCTAssertNil(frame([2], at: 0.09))
        XCTAssertEqual(frame([], at: 0.11), .threeFingerTap)
    }

    func testFourFingerTapAllowsStaggerAndSmallLiftDrift() {
        XCTAssertNil(frame([1], at: 0))
        XCTAssertNil(frame([1, 2, 3], at: 0.09))
        XCTAssertNil(frame([1, 2, 3, 4], at: 0.125))
        XCTAssertNil(frame([1, 2, 4], at: 0.17, dx: 0.04))
        XCTAssertNil(frame([4], at: 0.23))
        XCTAssertEqual(frame([], at: 0.31), .fourFingerTap)
    }

    func testPhysicalPressFiresOnceEvenAfterFingersLift() {
        for (ids, gesture) in [([Int32(1), 2, 3], Gesture.threeFingerTap), ([1, 2, 3, 4], .fourFingerTap)] {
            XCTAssertNil(frame(ids, at: 0))
            XCTAssertNil(frame(ids, at: 0.7, dx: 0.02))
            XCTAssertEqual(recognizer.clickCandidate, gesture)
            recognizer.pressPrimaryButton(remapping: gesture)
            XCTAssertNil(frame([], at: 0.8))
            XCTAssertEqual(recognizer.releasePrimaryButton(), gesture)
            XCTAssertNil(recognizer.releasePrimaryButton())
            XCTAssertNil(frame([], at: 0.85))
        }
    }

    func testPhysicalPressRejectsLateExtraFingerAndInterruption() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        recognizer.pressPrimaryButton(remapping: recognizer.clickCandidate)
        XCTAssertNil(frame([1, 2, 3, 4], at: 0.04))
        XCTAssertNil(recognizer.releasePrimaryButton())
        XCTAssertNil(frame([], at: 0.10))

        XCTAssertNil(frame([1, 2, 3, 4], at: 1))
        recognizer.pressPrimaryButton(remapping: recognizer.clickCandidate)
        recognizer.interrupt()
        XCTAssertNil(recognizer.releasePrimaryButton())
        XCTAssertNil(frame([], at: 1.10))
    }

    func testReleasingButtonBeforeFingersDoesNotAlsoTap() {
        XCTAssertNil(frame([1, 2, 3, 4], at: 0))
        recognizer.pressPrimaryButton(remapping: recognizer.clickCandidate)
        XCTAssertEqual(recognizer.releasePrimaryButton(), .fourFingerTap)
        XCTAssertNil(frame([2, 3, 4], at: 0.08))
        XCTAssertNil(frame([], at: 0.12))
    }

    func testNativeClickAndMovedChordCannotTriggerTap() {
        XCTAssertNil(frame([1, 2], at: 0))
        XCTAssertNil(recognizer.clickCandidate)
        recognizer.pressPrimaryButton(remapping: nil)
        XCTAssertNil(frame([1, 2, 3], at: 0.04))
        XCTAssertNil(recognizer.releasePrimaryButton())
        XCTAssertNil(frame([], at: 0.10))

        XCTAssertNil(frame([1, 2, 3], at: 1))
        XCTAssertNil(frame([1, 2, 3], at: 1.08, dx: 0.08))
        XCTAssertNil(recognizer.clickCandidate)
        XCTAssertNil(frame([], at: 1.15))
    }

    func testTapToleranceDoesNotWidenSwipeAssemblyWindow() {
        XCTAssertNil(frame([1, 2], at: 0))
        XCTAssertNil(frame([1, 2, 3], at: 0.13))
        XCTAssertNil(frame([1, 2, 3], at: 0.25, dx: 0.16))
        XCTAssertNil(frame([], at: 0.29))
    }

    func testSwipesRequireReleaseAndFireOnceInEachDirection() {
        for (direction, expected) in [(Float(1), Gesture.threeFingerSwipeRight), (-1, .threeFingerSwipeLeft)] {
            XCTAssertNil(frame([1, 2, 3], at: 0))
            XCTAssertNil(frame([1, 2, 3], at: 0.11, dx: direction * 0.14, dy: 0.02))
            XCTAssertNil(frame([1, 2, 3], at: 0.18, dx: direction * 0.19))
            XCTAssertNil(frame([2, 3], at: 0.22, dx: direction * 0.20))
            XCTAssertEqual(frame([], at: 0.27), expected)
            XCTAssertNil(frame([], at: 0.28))
        }
    }

    func testWrongFingerCountsNeverFire() {
        for ids: [Int32] in [[1], [1, 2], [1, 2, 3, 4, 5]] {
            XCTAssertNil(frame(ids, at: 0))
            XCTAssertNil(frame(ids, at: 0.05))
            XCTAssertNil(frame([], at: 0.09))
        }
    }

    func testExcessContactCancelsEvenAfterReturningToThree() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(frame([1, 2, 3, 4, 5], at: 0.04))
        XCTAssertNil(frame([1, 2, 3], at: 0.07))
        XCTAssertNil(frame([], at: 0.10))
    }

    func testFourFingerSwipeDoesNotBecomeThreeFingerSwipe() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(frame([1, 2, 3], at: 0.05, dx: 0.14))
        XCTAssertNil(frame([1, 2, 3, 4], at: 0.08, dx: 0.16))
        XCTAssertNil(frame([1, 2, 3], at: 0.12, dx: 0.18))
        XCTAssertNil(frame([], at: 0.16))
    }

    func testSubThresholdDiagonalAndVerticalMotionAreRejected() {
        for (dx, dy): (Float, Float) in [(0.08, 0), (0.16, 0.10), (0, 0.16)] {
            XCTAssertNil(frame([1, 2, 3], at: 0))
            XCTAssertNil(frame([1, 2, 3], at: 0.08, dx: dx, dy: dy))
            XCTAssertNil(frame([], at: 0.13))
        }
    }

    func testMovingOnlyOneFingerDoesNotTriggerTapOrSwipe() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(send([contact(1), contact(2), contact(3, dx: 0.16)], at: 0.07))
        XCTAssertNil(frame([], at: 0.15))
    }

    func testExcursionAndReversalAreNotTapsOrSwipes() {
        for finalX: Float in [0.005, 0.12] {
            XCTAssertNil(frame([1, 2, 3], at: 0))
            XCTAssertNil(frame([1, 2, 3], at: 0.07, dx: 0.21))
            XCTAssertNil(frame([1, 2, 3], at: 0.14, dx: finalX))
            XCTAssertNil(frame([], at: 0.20))
        }
    }

    func testLateFingersReplacementAndRecontactCancel() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(frame([1, 2, 3, 4], at: 0.16))
        XCTAssertNil(frame([], at: 0.21))

        XCTAssertNil(frame([1, 2, 3], at: 1))
        XCTAssertNil(frame([1, 2, 4], at: 1.04))
        XCTAssertNil(frame([], at: 1.09))

        XCTAssertNil(frame([1, 2, 3], at: 2))
        XCTAssertNil(frame([1, 2], at: 2.04))
        XCTAssertNil(frame([1, 2, 3], at: 2.06))
        XCTAssertNil(frame([], at: 2.09))
    }

    func testLongHoldSlowReleaseAndSlowSwipeAreRejected() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(frame([], at: 0.36))

        XCTAssertNil(frame([1, 2, 3], at: 1))
        XCTAssertNil(frame([1, 2], at: 1.05))
        XCTAssertNil(frame([], at: 1.24))

        XCTAssertNil(frame([1, 2, 3], at: 2))
        XCTAssertNil(frame([1, 2, 3], at: 2.5, dx: 0.17))
        XCTAssertNil(frame([], at: 2.65))
    }

    func testExplicitCancellationWaitsForAllFingersToLift() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        recognizer.cancel()
        XCTAssertNil(frame([1, 2, 3], at: 0.05))
        XCTAssertNil(frame([], at: 0.08))
        XCTAssertNil(frame([1, 2, 3], at: 0.15))
        XCTAssertEqual(frame([], at: 0.22), .threeFingerTap)
    }

    func testForegroundChangeCancelsOnlyAnInProgressSequence() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        recognizer.interrupt()
        XCTAssertNil(frame([], at: 0.08))
        recognizer.interrupt()
        XCTAssertNil(frame([1, 2, 3], at: 0.15))
        XCTAssertEqual(frame([], at: 0.22), .threeFingerTap)
    }

    func testMalformedFramesCancel() {
        XCTAssertNil(frame([1, 2, 3], at: 0))
        XCTAssertNil(frame([1, 1, 2], at: 0.03))
        XCTAssertNil(frame([], at: 0.06))

        XCTAssertNil(frame([1, 2, 3], at: 1))
        XCTAssertNil(frame([1, 2, 3], at: 0.99))
        XCTAssertNil(frame([], at: 1.07))

        XCTAssertNil(frame([1, 2, 3], at: 2))
        XCTAssertNil(frame([1, 2, 3], at: 2.03, dx: .nan))
        XCTAssertNil(frame([], at: 2.07))
    }
}
