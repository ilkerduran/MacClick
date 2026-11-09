# MacClick

<img src="MacClick/Resources/Assets.xcassets/MacClick.appiconset/MacClick-128@2x.png" alt="MacClick trackpad icon" width="88">

MacClick is an open-source macOS menu bar app that turns built-in trackpad gestures into mouse clicks and keyboard shortcuts. It uses Swift and AppKit and runs locally without third-party dependencies.

| Gesture | Default action |
| --- | --- |
| Three-finger tap or click | Middle mouse click |
| Three-finger swipe right | Control + Tab |
| Three-finger swipe left | Control + Shift + Tab |
| Four-finger tap or click | Command + W |

You can change each action, turn individual gestures off, or set MacClick to launch at login.

## Requirements

- Apple Silicon MacBook with a built-in trackpad
- macOS 27.2 or later, tested on 27.2
- Xcode 27.2 or later to build from source

MacClick uses a private macOS framework for raw trackpad contacts. See [trackpad compatibility](docs/Trackpad.md) for the API and distribution limits, as well as system gestures that can overlap with MacClick.

## Build from source

Open `MacClick.xcodeproj` and run the shared **MacClick** scheme, or build from the repository root.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project MacClick.xcodeproj -scheme MacClick \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build build
```

Copy `build/Build/Products/Release/MacClick.app` to Applications and open that copy. The default build uses an ad hoc signature.

## First run

1. Click the MacClick icon in the menu bar and choose **Open Settings**.
2. On the **Settings** page, click **Open Privacy Settings**. In **System Settings → Privacy & Security → Device Control and Data Access**, enable MacClick. If it is missing, use **+** to add the Applications copy.
3. Return to MacClick, click **Retry**, and close its settings window before trying a gesture.

**Open Privacy Settings** remains available after you grant access.

If an ad hoc update invalidates the existing permission, remove MacClick’s entry and add the new Applications copy. If the permission still appears unavailable, quit and reopen that copy.

MacClick uses the macOS permission to send its configured mouse clicks and shortcuts and to replace matching primary-button clicks. The click monitor covers only primary-button events. Shortcut recording only receives key events delivered to MacClick’s settings window. MacClick does not request Input Monitoring.

## Customize gestures

On the **Trackpad** page, select a gesture and choose **Middle Mouse Click** or **Keyboard Shortcut**. Use **Record Shortcut** to enter a key combination. **Restore Default** restores the selected action.

Use a row’s **Enabled** checkbox to disable that gesture or **Disable Gestures** in the menu to pause all gestures. Gestures pause while the settings window has keyboard focus. **Launch at Login** uses macOS login items and may require approval in **System Settings → General → Login Items & Extensions**.

## Contribute

Use [GitHub Issues](https://github.com/ilkerduran/MacClick/issues) for bugs and feature requests. For trackpad bugs, include the Mac model, macOS version, MacClick build, gesture, and whether you used a light tap or physical click. Pull requests should include verification steps.

Use the other person’s language in direct conversation. Write code, documentation, repository contributions, and commit messages in English. MacClick’s interface is English for now. See the [contributor guide](AGENTS.md) for project conventions and test commands, and the [verification record](docs/Verification.md) for hardware checks and measured performance.

## License

MacClick is licensed under the [Apache License, Version 2.0](LICENSE).
