import Foundation

enum Gesture: String, CaseIterable, Sendable {
    case threeFingerTap
    case threeFingerSwipeRight
    case threeFingerSwipeLeft
    case fourFingerTap

    var title: String {
        switch self {
        case .threeFingerTap: "Three Finger Tap"
        case .threeFingerSwipeRight: "Three Finger Swipe Right"
        case .threeFingerSwipeLeft: "Three Finger Swipe Left"
        case .fourFingerTap: "Four Finger Tap"
        }
    }

    var defaultAction: GestureAction {
        switch self {
        case .threeFingerTap: .middleClick
        case .threeFingerSwipeRight: .shortcut(.init(keyCode: 48, modifiers: .control))
        case .threeFingerSwipeLeft: .shortcut(.init(keyCode: 48, modifiers: [.control, .shift]))
        case .fourFingerTap: .shortcut(.init(keyCode: 13, modifiers: .command))
        }
    }
}

struct ShortcutModifiers: OptionSet, Codable, Sendable {
    let rawValue: UInt8

    static let command = Self(rawValue: 1 << 0)
    static let control = Self(rawValue: 1 << 1)
    static let shift = Self(rawValue: 1 << 2)
    static let option = Self(rawValue: 1 << 3)
}

struct KeyboardShortcut: Equatable, Codable, Sendable {
    let keyCode: UInt16
    let modifiers: ShortcutModifiers
}

enum GestureAction: Equatable, Codable, Sendable {
    case middleClick
    case shortcut(KeyboardShortcut)
}

struct GestureMapping: Equatable, Codable {
    var enabled: Bool
    var action: GestureAction
}

struct GestureConfiguration {
    private enum Key {
        static let enabled = "gesturesEnabled"
        static let mappings = "gestureMappings"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults
    private var mappings: [String: GestureMapping]

    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Key.enabled) }
    }
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        if let data = defaults.data(forKey: Key.mappings),
           let stored = try? PropertyListDecoder().decode([String: GestureMapping].self, from: data) {
            mappings = stored
        } else {
            mappings = [:]
        }
    }

    subscript(gesture: Gesture) -> GestureMapping {
        get { mappings[gesture.rawValue] ?? .init(enabled: true, action: gesture.defaultAction) }
        set {
            mappings[gesture.rawValue] = newValue
            if let data = try? PropertyListEncoder().encode(mappings) {
                defaults.set(data, forKey: Key.mappings)
            }
        }
    }

    var hasEnabledMapping: Bool {
        enabled && Gesture.allCases.contains { self[$0].enabled }
    }

    func action(for gesture: Gesture) -> GestureAction? {
        let mapping = self[gesture]
        return enabled && mapping.enabled ? mapping.action : nil
    }
}
