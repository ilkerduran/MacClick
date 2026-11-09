import AppKit
import ServiceManagement

@main
@MainActor
final class MacClickApp: NSObject, NSApplicationDelegate {
    private let input = TrackpadInput()
    private let login = SMAppService.mainApp
    private var statusItem: NSStatusItem?
    private var settings: SettingsController?
    private var sessionActive = true
    private var awake = true
    private var launchError: String?

    private(set) var configuration = GestureConfiguration()
    private(set) var hasPostPermission = false

    static func main() {
        let app = NSApplication.shared
        let delegate = MacClickApp()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(size: NSSize(width: 18, height: 15), flipped: false) { bounds in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 3, yRadius: 3)
            outline.lineWidth = 1.3
            outline.stroke()
            NSBezierPath.strokeLine(from: NSPoint(x: 2, y: 5), to: NSPoint(x: 16, y: 5))
            return true
        }
        icon.isTemplate = true
        icon.accessibilityDescription = "MacClick"
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "MacClick"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem

        let notifications = NSWorkspace.shared.notificationCenter
        notifications.addObserver(self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
        notifications.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        notifications.addObserver(self, selector: #selector(sessionDidResign), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        notifications.addObserver(self, selector: #selector(sessionDidActivate), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        notifications.addObserver(self, selector: #selector(frontmostAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)

        reconcileLogin()
        retryInput()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        reconcileLogin()
        retryInput()
    }

    func applicationWillTerminate(_ notification: Notification) {
        input.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func updateInput(retry: Bool = false) {
        if retry {
            hasPostPermission = CGPreflightPostEventAccess()
            if let status = input.status, status != MacClickTrackpadReady { input.stop() }
        }
        if configuration.hasEnabledMapping, hasPostPermission, sessionActive, awake {
            if input.status == nil {
                input.start(canRemapClick: { [weak self] gesture in
                    self?.canRemapClick(gesture) == true
                }, onGesture: { [weak self] gesture in
                    self?.perform(gesture)
                })
            } else if retry {
                input.retryClickCapture()
            }
        } else {
            input.stop()
        }
        settings?.refreshStatus()
    }

    private func canRemapClick(_ gesture: Gesture) -> Bool {
        guard settings?.window?.isKeyWindow != true,
              configuration.action(for: gesture) != nil else { return false }
        guard gesture == .threeFingerTap else { return true }
        // Three Finger Drag also produces a primary-button event from the trackpad.
        let threeFingerDrag = CFPreferencesCopyAppValue(
            "TrackpadThreeFingerDrag" as CFString, "com.apple.AppleMultitouchTrackpad" as CFString
        ) as? Bool ?? false
        return !threeFingerDrag
    }

    private func perform(_ gesture: Gesture) {
        guard settings?.window?.isKeyWindow != true,
              let action = configuration.action(for: gesture) else { return }
        guard CGPreflightPostEventAccess() else {
            hasPostPermission = false
            updateInput()
            return
        }
        ActionExecutor.execute(action)
    }

    @objc private func frontmostAppChanged() {
        input.interrupt()
    }

    @objc private func sleep() {
        awake = false
        updateInput()
    }

    @objc private func wake() {
        awake = true
        retryInput()
    }

    @objc private func sessionDidResign() {
        sessionActive = false
        updateInput()
    }

    @objc private func sessionDidActivate() {
        sessionActive = true
        retryInput()
    }

    var inputMessage: String {
        if !hasPostPermission {
            return "Allow MacClick in Privacy & Security → Device Control and Data Access so it can send mouse clicks and keyboard shortcuts."
        }
        if !configuration.enabled { return "Gestures are disabled." }
        if !configuration.hasEnabledMapping { return "All gestures are disabled." }
        switch input.status {
        case MacClickTrackpadReady:
            if !input.clickCaptureAvailable {
                return "Taps and swipes are available. To enable physical clicks, check Device Control and Data Access and click Retry."
            }
            return "Built-in trackpad connected. Gestures pause while this window is active."
        case MacClickTrackpadFrameworkUnavailable: return "Raw trackpad input is unavailable on this macOS version."
        case MacClickTrackpadNotFound: return "MacClick couldn’t find a built-in trackpad."
        case MacClickTrackpadStartFailed: return "MacClick couldn’t start trackpad input. Use Retry to reconnect."
        default: return "Trackpad input is paused."
        }
    }

    @objc func retryInput() {
        updateInput(retry: true)
    }

    @objc func requestPermission() {
        if !CGRequestPostEventAccess(),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        retryInput()
    }

    @objc private func openSettings() {
        if settings == nil {
            settings = SettingsController(app: self)
        }
        retryInput()
        NSApp.activate()
        settings?.showWindow(nil)
        if !NSApp.isActive {
            settings?.window?.orderFrontRegardless()
        }
    }

    func settingsDidClose() {
        settings = nil
    }

    @objc func toggleGestures() {
        configuration.enabled.toggle()
        retryInput()
    }

    func setMapping(_ mapping: GestureMapping, for gesture: Gesture) {
        configuration[gesture] = mapping
        updateInput()
    }

    var loginState: NSControl.StateValue {
        switch login.status {
        case .enabled: .on
        case .requiresApproval: .mixed
        default: .off
        }
    }

    var loginMessage: String {
        if let launchError { return launchError }
        switch login.status {
        case .enabled: return "MacClick is registered to open at login."
        case .requiresApproval: return "Approve MacClick in General → Login Items & Extensions."
        case .notFound: return "macOS couldn’t find MacClick’s login item. Move the app to Applications and open it there."
        default: return "MacClick is set to open manually."
        }
    }

    private func reconcileLogin() {
        switch login.status {
        case .enabled, .requiresApproval:
            if !configuration.launchAtLogin { configuration.launchAtLogin = true }
        case .notRegistered:
            if configuration.launchAtLogin { configuration.launchAtLogin = false }
        default: break
        }
        settings?.refreshStatus()
    }

    @objc func toggleLogin() {
        launchError = nil
        do {
            switch login.status {
            case .enabled: try login.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try login.register()
            }
        } catch {
            launchError = "Couldn’t update Launch at Login (error \((error as NSError).code))."
        }
        reconcileLogin()
    }

    @objc func removePendingLogin() {
        launchError = nil
        do {
            try login.unregister()
        } catch {
            launchError = "Couldn’t remove the login item (error \((error as NSError).code))."
        }
        reconcileLogin()
    }

    @objc func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension MacClickApp: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        reconcileLogin()
        updateInput(retry: !hasPostPermission)
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
            return item
        }
        _ = add("Open Settings", #selector(openSettings), key: ",")
        _ = add(configuration.enabled ? "Disable Gestures" : "Enable Gestures", #selector(toggleGestures))
        let item = add("Launch at Login", #selector(toggleLogin))
        item.state = loginState
        menu.addItem(.separator())
        _ = add("Quit MacClick", #selector(quit), key: "q")
    }
}
