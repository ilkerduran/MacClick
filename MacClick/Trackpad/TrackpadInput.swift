import CoreGraphics
import Dispatch
import Foundation
import Synchronization

@MainActor
final class TrackpadInput {
    private struct ButtonEvent {
        let number: Int64
        let position: CGPoint
        let timestamp: UInt64
    }

    private var generation: UInt = 0
    private var interruptedAt: TimeInterval = 0
    private var clickTap: CFMachPort?
    private var clickSource: CFRunLoopSource?
    private var remappedPress: ButtonEvent?
    private var canRemapClick: ((Gesture) -> Bool)?
    private(set) var status: MacClickTrackpadStatus?
    var clickCaptureAvailable: Bool { clickTap != nil }

    @discardableResult
    func start(
        canRemapClick: @escaping @MainActor (Gesture) -> Bool,
        onGesture: @escaping @MainActor @Sendable (Gesture) -> Void
    ) -> MacClickTrackpadStatus {
        if let status, status == MacClickTrackpadReady { return status }

        generation &+= 1
        let session = generation
        recognition.withLock { state in
            state = CaptureSession(id: session) { [weak self] gesture in
                let recognizedAt = ProcessInfo.processInfo.systemUptime
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == session,
                          self.status == MacClickTrackpadReady,
                          recognizedAt >= self.interruptedAt,
                          ProcessInfo.processInfo.systemUptime - recognizedAt < 0.15 else { return }
                    onGesture(gesture)
                }
            }
        }
        let result = MacClickTrackpadStart(session)
        status = result
        if result == MacClickTrackpadReady {
            self.canRemapClick = canRemapClick
            retryClickCapture()
        } else {
            recognition.withLock { $0 = nil }
        }
        return result
    }

    func interrupt() {
        recognition.withLock { $0?.recognizer.interrupt() }
        interruptedAt = ProcessInfo.processInfo.systemUptime
    }

    func stop() {
        guard status != nil else { return }
        if let clickSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), clickSource, .commonModes) }
        if let clickTap { CFMachPortInvalidate(clickTap) }
        clickSource = nil
        clickTap = nil
        remappedPress = nil
        canRemapClick = nil
        recognition.withLock { $0 = nil }
        MacClickTrackpadStop()
        status = nil
        generation &+= 1
    }

    func retryClickCapture() {
        guard clickTap == nil, status == MacClickTrackpadReady else { return }
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged].reduce(CGEventMask(0)) {
            $0 | (1 << $1.rawValue)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let input = Unmanaged<TrackpadInput>.fromOpaque(context).takeUnretainedValue()
                let disabled = type == .tapDisabledByTimeout || type == .tapDisabledByUserInput
                guard disabled || event.getIntegerValueField(.eventSourceUnixProcessID) == 0 else {
                    return Unmanaged.passUnretained(event)
                }
                let button = ButtonEvent(
                    number: disabled ? 0 : event.getIntegerValueField(.mouseEventNumber),
                    position: disabled ? .zero : event.location,
                    timestamp: disabled ? 0 : event.timestamp
                )
                // The tap's source is installed on the main run loop.
                let suppress = MainActor.assumeIsolated {
                    input.handleClick(type, button)
                }
                return suppress ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }
        clickTap = tap
        clickSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func handleClick(_ type: CGEventType, _ event: ButtonEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            remappedPress = nil
            recognition.withLock {
                $0?.recognizer.interrupt()
                _ = $0?.recognizer.releasePrimaryButton()
            }
            if let clickTap { CGEvent.tapEnable(tap: clickTap, enable: true) }
            return false
        }
        switch type {
        case .leftMouseDown:
            let candidate = recognition.withLock { state in
                // Recover if the previous mouse-up was lost while the tap was disabled.
                _ = state?.recognizer.releasePrimaryButton()
                return state?.recognizer.clickCandidate
            }
            let mapping = candidate.flatMap { canRemapClick?($0) == true ? $0 : nil }
            let didRemap = recognition.withLock { state in
                guard state != nil else { return false }
                // Recheck after the settings lookup in case a contact changed meanwhile.
                let current = state?.recognizer.clickCandidate
                let gesture = current == mapping ? mapping : nil
                state?.recognizer.pressPrimaryButton(remapping: gesture)
                return gesture != nil
            }
            remappedPress = didRemap ? event : nil
            return didRemap

        case .leftMouseDragged:
            guard let press = remappedPress else { return false }
            if movedSincePress(event, press: press) {
                recognition.withLock { $0?.recognizer.cancel() }
            }
            return true

        case .leftMouseUp:
            let press = remappedPress
            remappedPress = nil
            let matched = press?.number == event.number
            recognition.withLock { state in
                let gesture = state?.recognizer.releasePrimaryButton()
                if let press, matched, let gesture,
                   event.timestamp >= press.timestamp, event.timestamp - press.timestamp <= 650_000_000,
                   !movedSincePress(event, press: press) {
                    state?.onGesture(gesture)
                }
            }
            return matched

        default:
            return false
        }
    }

    private func movedSincePress(_ event: ButtonEvent, press: ButtonEvent) -> Bool {
        let dx = event.position.x - press.position.x
        let dy = event.position.y - press.position.y
        return dx * dx + dy * dy > 64
    }
}

private struct CaptureSession {
    let id: UInt
    let onGesture: @Sendable (Gesture) -> Void
    var recognizer = GestureRecognizer()
}

private let recognition = Mutex<CaptureSession?>(nil)

// The driver owns the frame buffer and may call on a non-main thread.
// Only a recognized gesture is dispatched to AppKit.
@_cdecl("MacClickReceiveContacts")
func receiveContacts(
    session: UInt, contacts: UnsafePointer<MacClickContact>?, count: Int32, timestamp: Double
) {
    recognition.withLock { state in
        guard state?.id == session else { return }
        guard (0...4).contains(count), count == 0 || contacts != nil else {
            state?.recognizer.cancel()
            return
        }
        let frame = UnsafeBufferPointer(start: contacts, count: Int(count))
        if let gesture = state?.recognizer.consume(frame, at: timestamp) {
            state?.onGesture(gesture)
        }
    }
}
