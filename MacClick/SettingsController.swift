import AppKit

@MainActor
final class SettingsController: NSWindowController, NSWindowDelegate {
    private static let websiteAddress = "https://ilkerduran.github.io/MacClick/"
    private static let githubAddress = "https://github.com/ilkerduran/MacClick"

    private unowned let app: MacClickApp
    private var selectedGesture = Gesture.threeFingerTap
    private var shortcutMonitor: Any?
    private var captureHint = ""

    private let trackpadButton = NSButton(title: "Trackpad", target: nil, action: nil)
    private let settingsButton = NSButton(title: "Settings", target: nil, action: nil)
    private let aboutButton = NSButton(title: "About", target: nil, action: nil)
    private let trackpadPage = NSStackView()
    private let settingsPage = NSStackView()
    private let aboutPage = NSStackView()
    private var pages: [(button: NSButton, view: NSStackView)] {
        [(trackpadButton, trackpadPage), (settingsButton, settingsPage), (aboutButton, aboutPage)]
    }
    private var rows: [(gesture: NSButton, action: NSButton, toggle: NSButton)] = []
    private let editorTitle = NSTextField(labelWithString: "")
    private let editorToggle = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
    private let actionPicker = NSPopUpButton()
    private let captureButton = NSButton(title: "Record Shortcut", target: nil, action: nil)
    private let hintLabel = NSTextField(wrappingLabelWithString: "")
    private let trackpadStatus = NSTextField(wrappingLabelWithString: "")
    private let inputStatus = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton(title: "Open Privacy Settings", target: nil, action: nil)
    private let masterToggle = NSButton(checkboxWithTitle: "Enable Gestures", target: nil, action: nil)
    private let loginToggle = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let loginItemsButton = NSButton(title: "Open Login Items", target: nil, action: nil)
    private let removeLoginButton = NSButton(title: "Remove Pending Login Item", target: nil, action: nil)

    init(app: MacClickApp) {
        self.app = app
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 426),
            styleMask: [.titled, .closable], backing: .buffered, defer: true
        )
        super.init(window: window)
        window.title = "MacClick Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildLayout(in: window)
        refreshMappings()
        refreshStatus()
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    private func buildLayout(in window: NSWindow) {
        let content = NSView()
        window.contentView = content

        for (button, view) in pages {
            button.target = self
            button.action = #selector(selectPage(_:))
            button.setButtonType(.pushOnPushOff)
            button.widthAnchor.constraint(equalToConstant: 112).isActive = true
            button.state = button == trackpadButton ? .on : .off
            view.isHidden = button != trackpadButton
        }
        let sidebar = stack(pages.map(\.button), vertical: true, spacing: 8)
        let divider = separator(vertical: true)
        let page = NSView()
        for view in [sidebar, divider, page] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            sidebar.widthAnchor.constraint(equalToConstant: 112),
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 16),
            divider.topAnchor.constraint(equalTo: content.topAnchor),
            divider.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            page.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 22),
            page.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            page.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            page.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        for (_, view) in pages {
            view.orientation = .vertical
            view.alignment = .leading
            view.spacing = 10
            view.translatesAutoresizingMaskIntoConstraints = false
            page.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: page.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: page.trailingAnchor),
                view.topAnchor.constraint(equalTo: page.topAnchor),
                view.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor)
            ])
        }
        buildTrackpadPage()
        buildSettingsPage()
        buildAboutPage()
    }

    private func buildTrackpadPage() {
        trackpadPage.addArrangedSubview(heading("Trackpad", size: 21))
        trackpadStatus.textColor = .secondaryLabelColor
        trackpadPage.addArrangedSubview(trackpadStatus)
        trackpadStatus.widthAnchor.constraint(equalTo: trackpadPage.widthAnchor).isActive = true
        for (index, gesture) in Gesture.allCases.enumerated() {
            if index == 0 || gesture == .fourFingerTap {
                trackpadPage.addArrangedSubview(heading(index == 0 ? "Three Touch" : "Four Touch"))
            }
            let name = NSButton(title: gesture.title, target: self, action: #selector(selectGesture(_:)))
            name.setButtonType(.pushOnPushOff)
            name.alignment = .left
            name.widthAnchor.constraint(equalToConstant: 214).isActive = true
            let action = NSButton(title: "", target: self, action: #selector(selectGesture(_:)))
            action.widthAnchor.constraint(equalToConstant: 159).isActive = true
            action.alignment = .left
            let toggle = NSButton(checkboxWithTitle: "Enabled", target: self, action: #selector(toggleRow(_:)))
            for button in [name, action, toggle] { button.tag = index }
            action.setAccessibilityLabel("Action for \(gesture.title)")
            toggle.setAccessibilityLabel("Enable \(gesture.title)")
            rows.append((name, action, toggle))
            trackpadPage.addArrangedSubview(stack([name, action, toggle], spacing: 9))
        }

        let divider = separator()
        trackpadPage.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: trackpadPage.widthAnchor).isActive = true
        editorTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        editorToggle.target = self
        editorToggle.action = #selector(toggleEditor(_:))
        actionPicker.addItems(withTitles: ["Middle Mouse Click", "Keyboard Shortcut"])
        actionPicker.target = self
        actionPicker.action = #selector(changeAction)
        actionPicker.setAccessibilityLabel("Action type")
        captureButton.target = self
        captureButton.action = #selector(toggleCapture)
        let restore = NSButton(title: "Restore Default", target: self, action: #selector(restoreDefault))

        trackpadPage.addArrangedSubview(stack([editorTitle, editorToggle], spacing: 14))
        trackpadPage.addArrangedSubview(stack([actionPicker, captureButton, restore], spacing: 8))
        hintLabel.textColor = .secondaryLabelColor
        trackpadPage.addArrangedSubview(hintLabel)
        hintLabel.widthAnchor.constraint(equalTo: trackpadPage.widthAnchor).isActive = true
    }

    private func buildSettingsPage() {
        masterToggle.target = app
        masterToggle.action = #selector(MacClickApp.toggleGestures)
        loginToggle.target = app
        loginToggle.action = #selector(MacClickApp.toggleLogin)
        loginToggle.allowsMixedState = true
        loginItemsButton.target = app
        loginItemsButton.action = #selector(MacClickApp.openLoginItems)
        removeLoginButton.target = app
        removeLoginButton.action = #selector(MacClickApp.removePendingLogin)
        permissionButton.target = app
        permissionButton.action = #selector(MacClickApp.openPrivacySettings)
        let retry = NSButton(title: "Retry", target: app, action: #selector(MacClickApp.reloadGestures))

        settingsPage.addArrangedSubview(heading("Settings", size: 21))
        settingsPage.addArrangedSubview(masterToggle)
        settingsPage.addArrangedSubview(heading("Trackpad and Permissions"))
        settingsPage.addArrangedSubview(inputStatus)
        inputStatus.widthAnchor.constraint(equalTo: settingsPage.widthAnchor).isActive = true
        let permissionControls = stack([permissionButton, retry], spacing: 8)
        settingsPage.addArrangedSubview(permissionControls)
        settingsPage.setCustomSpacing(22, after: permissionControls)
        settingsPage.addArrangedSubview(heading("Startup"))
        settingsPage.addArrangedSubview(loginToggle)
        settingsPage.addArrangedSubview(loginStatus)
        loginStatus.widthAnchor.constraint(equalTo: settingsPage.widthAnchor).isActive = true
        settingsPage.addArrangedSubview(stack([loginItemsButton, removeLoginButton], spacing: 8))
    }

    private func buildAboutPage() {
        let title = heading("About", size: 21)
        aboutPage.addArrangedSubview(title)
        aboutPage.setCustomSpacing(20, after: title)

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 60).isActive = true
        icon.heightAnchor.constraint(equalTo: icon.widthAnchor).isActive = true
        let identity = stack([icon, heading("MacClick", size: 23)], spacing: 14)
        aboutPage.addArrangedSubview(identity)
        aboutPage.setCustomSpacing(18, after: identity)

        let divider = separator()
        aboutPage.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: aboutPage.widthAnchor).isActive = true
        aboutPage.setCustomSpacing(18, after: divider)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let versionLabel = NSTextField(labelWithString: build.map { "\(version) (build \($0))" } ?? version)
        versionLabel.textColor = .secondaryLabelColor
        let details = NSGridView(views: [
            [heading("Version"), versionLabel, NSGridCell.emptyContentView],
            aboutLinkRow("Website", symbol: "globe", address: Self.websiteAddress, action: #selector(openWebsite)),
            aboutLinkRow("GitHub", symbol: "chevron.left.forwardslash.chevron.right", address: Self.githubAddress, action: #selector(openGitHub))
        ])
        details.xPlacement = .leading
        details.yPlacement = .center
        details.rowAlignment = .none
        details.columnSpacing = 16
        details.rowSpacing = 12
        aboutPage.addArrangedSubview(details)
    }

    private func aboutLinkRow(_ title: String, symbol: String, address: String, action: Selector) -> [NSView] {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        let label = stack([icon, heading(title)], spacing: 6)

        let link = NSButton(title: address, target: self, action: action)
        link.isBordered = false
        link.attributedTitle = NSAttributedString(string: address, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
        let open = NSButton(title: "Open", target: self, action: action)
        open.setAccessibilityLabel("Open \(title)")
        return [label, link, open]
    }

    @objc private func openWebsite() {
        if let url = URL(string: Self.websiteAddress) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: Self.githubAddress) {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshStatus() {
        inputStatus.stringValue = app.inputMessage
        trackpadStatus.stringValue = app.hasPostPermission
            ? app.inputMessage
            : "Open the Settings page to grant permission and activate gestures."
        masterToggle.state = app.configuration.enabled ? .on : .off
        loginToggle.state = app.loginState
        loginStatus.stringValue = app.loginMessage
        removeLoginButton.isHidden = app.loginState != .mixed
    }

    private func refreshMappings() {
        for (gesture, row) in zip(Gesture.allCases, rows) {
            let mapping = app.configuration[gesture]
            row.gesture.state = gesture == selectedGesture ? .on : .off
            row.action.title = mapping.action.title
            row.toggle.state = mapping.enabled ? .on : .off
        }
        let mapping = app.configuration[selectedGesture]
        editorTitle.stringValue = selectedGesture.title
        editorToggle.state = mapping.enabled ? .on : .off
        let recording = shortcutMonitor != nil
        actionPicker.selectItem(at: mapping.action == .middleClick && !recording ? 0 : 1)
        captureButton.title = recording ? "Cancel Recording" : "Record Shortcut"
        if recording {
            hintLabel.stringValue = "Press a key or shortcut to assign it."
        } else if !captureHint.isEmpty {
            hintLabel.stringValue = captureHint
        } else {
            hintLabel.stringValue = "Assigned action: \(mapping.action.title)"
        }
    }

    func showAbout() {
        selectPage(aboutButton)
    }

    @objc private func selectPage(_ button: NSButton) {
        stopCapture()
        for (pageButton, view) in pages {
            let isSelected = pageButton == button
            pageButton.state = isSelected ? .on : .off
            view.isHidden = !isSelected
        }
    }

    @objc private func selectGesture(_ button: NSButton) {
        stopCapture()
        selectedGesture = Gesture.allCases[button.tag]
        captureHint = ""
        refreshMappings()
    }

    @objc private func toggleRow(_ button: NSButton) {
        setEnabled(button.state == .on, for: Gesture.allCases[button.tag])
    }

    @objc private func toggleEditor(_ button: NSButton) {
        setEnabled(button.state == .on, for: selectedGesture)
    }

    private func setEnabled(_ enabled: Bool, for gesture: Gesture) {
        var mapping = app.configuration[gesture]
        mapping.enabled = enabled
        app.setMapping(mapping, for: gesture)
        refreshMappings()
    }

    private func setAction(_ action: GestureAction) {
        var mapping = app.configuration[selectedGesture]
        mapping.action = action
        app.setMapping(mapping, for: selectedGesture)
        captureHint = ""
        refreshMappings()
    }

    @objc private func restoreDefault() {
        stopCapture()
        setAction(selectedGesture.defaultAction)
    }

    @objc private func changeAction() {
        if actionPicker.indexOfSelectedItem == 0 {
            stopCapture()
            setAction(.middleClick)
        } else if app.configuration[selectedGesture].action == .middleClick {
            startCapture()
        }
    }

    @objc private func toggleCapture() {
        if shortcutMonitor == nil { startCapture() }
        else { stopCapture() }
    }

    private func startCapture() {
        guard shortcutMonitor == nil else { return }
        captureHint = ""
        // Local delivery captures only key events sent to this settings window.
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window,
                  event.window === window || (event.window == nil && window.isKeyWindow) else { return event }
            if !event.isARepeat {
                let shortcut = KeyboardShortcut(event: event)
                self.stopCapture()
                self.setAction(.shortcut(shortcut))
            }
            return nil
        }
        if shortcutMonitor == nil { captureHint = "Couldn’t start shortcut recording. Try again." }
        refreshMappings()
    }

    private func stopCapture() {
        if let shortcutMonitor {
            NSEvent.removeMonitor(shortcutMonitor)
            self.shortcutMonitor = nil
        }
        refreshMappings()
    }

    func windowDidResignKey(_ notification: Notification) {
        stopCapture()
    }

    func windowWillClose(_ notification: Notification) {
        stopCapture()
        app.settingsDidClose()
    }

    private func heading(_ title: String, size: CGFloat = 13) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: size, weight: .semibold)
        return label
    }

    private func separator(vertical: Bool = false) -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        if vertical {
            box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        }
        return box
    }

    private func stack(_ views: [NSView], vertical: Bool = false, spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = vertical ? .vertical : .horizontal
        stack.alignment = vertical ? .leading : .centerY
        stack.spacing = spacing
        return stack
    }
}
