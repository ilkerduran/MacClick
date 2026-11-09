struct GestureRecognizer {
    struct Thresholds {
        var tapJoinTime = 0.145
        var tapTime = 0.33
        var tapReleaseTime = 0.16
        var tapTravel: Float = 0.045
        var swipeJoinTime = 0.105
        var swipeTime = 0.60
        var swipeReleaseTime = 0.12
        var swipeTravel: Float = 0.11
        var swipeAxisRatio: Float = 2
        var swipeRetreat: Float = 0.045
    }

    private struct Finger {
        let id: Int32
        let startX: Float
        let startY: Float
        var x: Float = 0
        var leftmost: Float = 0
        var rightmost: Float = 0
        var verticalTravel: Float = 0
        var tapDistanceSquared: Float = 0

        init(_ contact: MacClickContact) {
            id = contact.id
            startX = contact.x
            startY = contact.y
        }

        mutating func move(to contact: MacClickContact, releasing: Bool) {
            let dx = contact.x - startX
            let dy = contact.y - startY
            tapDistanceSquared = max(tapDistanceSquared, dx * dx + dy * dy)
            // Evaluate a swipe using the last frame with the full chord down.
            guard !releasing else { return }
            x = dx
            leftmost = min(leftmost, dx)
            rightmost = max(rightmost, dx)
            verticalTravel = max(verticalTravel, abs(dy))
        }
    }

    private let thresholds: Thresholds
    private var fingers: [Finger] = []
    private var startedAt: Double = 0
    private var assembledAt: Double = 0
    private var previousTime: Double = 0
    private var firstRelease: Double?
    private var down: UInt8 = 0
    private var cancelled = false
    private var primaryButtonDown = false
    private var pressedGesture: Gesture?

    init(thresholds: Thresholds = .init()) {
        self.thresholds = thresholds
        fingers.reserveCapacity(4)
    }

    mutating func cancel() {
        cancelled = true
        pressedGesture = nil
    }

    mutating func interrupt() {
        if down != 0 || primaryButtonDown { cancel() }
    }

    var clickCandidate: Gesture? {
        guard !primaryButtonDown, !cancelled, firstRelease == nil,
              isWithinTapTravel else { return nil }
        return tapGesture
    }

    mutating func pressPrimaryButton(remapping gesture: Gesture?) {
        primaryButtonDown = true
        cancelled = true
        pressedGesture = gesture
    }

    mutating func releasePrimaryButton() -> Gesture? {
        primaryButtonDown = false
        defer { pressedGesture = nil }
        return pressedGesture
    }

    mutating func consume(_ contacts: UnsafeBufferPointer<MacClickContact>, at time: Double) -> Gesture? {
        guard time.isFinite, contacts.count <= 4 else {
            cancel()
            return nil
        }
        if contacts.isEmpty {
            defer { reset() }
            return primaryButtonDown ? nil : recognize(at: time)
        }
        if primaryButtonDown {
            // Extra contacts after mouse-down make the original chord ambiguous.
            if pressedGesture != nil,
               contacts.contains(where: { contact in !fingers.contains(where: { $0.id == contact.id }) }) {
                pressedGesture = nil
            }
            cancelled = true
            return nil
        }
        guard !cancelled else { return nil }
        if fingers.isEmpty {
            startedAt = time
        } else if time < previousTime {
            cancel()
            return nil
        }
        previousTime = time

        let previousFingerCount = fingers.count
        var seen: UInt8 = 0
        for contact in contacts {
            guard contact.x.isFinite, contact.y.isFinite,
                  (-0.05...1.05).contains(contact.x), (-0.05...1.05).contains(contact.y) else {
                cancel()
                return nil
            }
            if let index = fingers.firstIndex(where: { $0.id == contact.id }) {
                let bit = UInt8(1) << index
                guard seen & bit == 0, down & bit != 0 else {
                    cancel()
                    return nil
                }
                seen |= bit
            } else {
                guard fingers.count < 4, firstRelease == nil,
                      time - startedAt <= thresholds.tapJoinTime else {
                    cancel()
                    return nil
                }
                seen |= UInt8(1) << fingers.count
                fingers.append(Finger(contact))
                assembledAt = time
            }
        }

        if down & ~seen != 0 {
            guard fingers.count == previousFingerCount else {
                cancel()
                return nil
            }
            firstRelease = firstRelease ?? time
        }
        down = seen
        for contact in contacts {
            if let index = fingers.firstIndex(where: { $0.id == contact.id }) {
                fingers[index].move(to: contact, releasing: firstRelease != nil)
            }
        }
        return nil
    }

    private var tapGesture: Gesture? {
        switch fingers.count {
        case 3: .threeFingerTap
        case 4: .fourFingerTap
        default: nil
        }
    }

    private var isWithinTapTravel: Bool {
        let tapLimit = thresholds.tapTravel * thresholds.tapTravel
        return fingers.allSatisfy { $0.tapDistanceSquared <= tapLimit }
    }

    private func recognize(at time: Double) -> Gesture? {
        guard !cancelled, time >= previousTime, let tapGesture else { return nil }

        let duration = time - startedAt
        let releaseDuration = time - (firstRelease ?? time)
        if duration <= thresholds.tapTime, releaseDuration <= thresholds.tapReleaseTime, isWithinTapTravel {
            return tapGesture
        }
        guard fingers.count == 3, duration <= thresholds.swipeTime,
              assembledAt - startedAt <= thresholds.swipeJoinTime,
              releaseDuration <= thresholds.swipeReleaseTime else { return nil }

        let direction: Float = fingers[0].x > 0 ? 1 : -1
        let isSwipe = fingers.allSatisfy { finger in
            let forward = direction * finger.x
            let peak = direction > 0 ? finger.rightmost : -finger.leftmost
            let reverse = direction > 0 ? -finger.leftmost : finger.rightmost
            return forward >= thresholds.swipeTravel &&
                forward >= finger.verticalTravel * thresholds.swipeAxisRatio &&
                peak - forward <= thresholds.swipeRetreat && reverse <= thresholds.swipeRetreat
        }
        guard isSwipe else { return nil }
        return direction > 0 ? .threeFingerSwipeRight : .threeFingerSwipeLeft
    }

    private mutating func reset() {
        fingers.removeAll(keepingCapacity: true)
        firstRelease = nil
        down = 0
        cancelled = false
    }
}
