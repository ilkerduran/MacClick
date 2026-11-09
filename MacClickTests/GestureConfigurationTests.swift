import Foundation
import XCTest

final class GestureConfigurationTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suite = "com.macclick.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testInitialMappings() {
        let configuration = GestureConfiguration(defaults: defaults)
        XCTAssertTrue(configuration.enabled)
        XCTAssertFalse(configuration.launchAtLogin)
        XCTAssertEqual(configuration.action(for: .threeFingerTap), .middleClick)
        XCTAssertEqual(configuration.action(for: .fourFingerTap), .shortcut(.init(keyCode: 13, modifiers: .command)))
        XCTAssertEqual(configuration.action(for: .threeFingerSwipeRight), .shortcut(.init(keyCode: 48, modifiers: .control)))
        XCTAssertEqual(configuration.action(for: .threeFingerSwipeLeft), .shortcut(.init(keyCode: 48, modifiers: [.control, .shift])))
    }

    func testPerGestureAndMasterDisable() {
        var configuration = GestureConfiguration(defaults: defaults)
        configuration[.threeFingerTap].enabled = false
        XCTAssertNil(configuration.action(for: .threeFingerTap))
        XCTAssertNotNil(configuration.action(for: .fourFingerTap))
        configuration.enabled = false
        XCTAssertFalse(configuration.hasEnabledMapping)
        XCTAssertTrue(Gesture.allCases.allSatisfy { configuration.action(for: $0) == nil })
        configuration.enabled = true
        for gesture in Gesture.allCases { configuration[gesture].enabled = false }
        XCTAssertFalse(configuration.hasEnabledMapping)
    }

    func testPreferencesReloadFromAnotherDefaultsInstance() throws {
        var configuration = GestureConfiguration(defaults: defaults)
        configuration.enabled = false
        configuration.launchAtLogin = true
        let custom = GestureMapping(
            enabled: false,
            action: .shortcut(.init(keyCode: 123, modifiers: [.command, .option, .control, .shift]))
        )
        configuration[.threeFingerTap] = custom
        configuration[.fourFingerTap].action = .middleClick

        let reopened = GestureConfiguration(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertFalse(reopened.enabled)
        XCTAssertTrue(reopened.launchAtLogin)
        XCTAssertEqual(reopened[.threeFingerTap], custom)
        XCTAssertEqual(reopened[.fourFingerTap].action, .middleClick)
        XCTAssertEqual(reopened[.threeFingerSwipeRight].action, Gesture.threeFingerSwipeRight.defaultAction)
    }

    func testUnreadableMappingsFallBackToDefaults() {
        defaults.set(Data([0xff]), forKey: "gestureMappings")
        XCTAssertEqual(GestureConfiguration(defaults: defaults).action(for: .threeFingerTap), .middleClick)
    }
}
