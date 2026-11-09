# Repository Guidelines

## Project Structure

- `MacClick.xcodeproj/` contains the native app target, hostless XCTest target, and shared MacClick scheme.
- `MacClick/` contains Swift application and settings code plus bundle metadata in `Info.plist`. Add app modules here and add them to the MacClick target.
- `MacClick/Trackpad/` contains the private framework bridge and its Swift input adapter. Keep private ABI details in the C bridge.
- `MacClick/Resources/Assets.xcassets/` contains the app icon used by Finder and macOS settings. Keep its trackpad glyph consistent with the menu bar template.
- `MacClickTests/` contains XCTest cases. The test target compiles the same gesture recognizer and configuration source files as the app. Add new test files to the MacClickTests target.
- `docs/` contains the project wiki and verification records. Keep generated local build output under `build/`.
- `web/` contains the static landing page, translations, and website images. See [hosting instructions](web/README.md).

## Build, Test, and Development Commands

Use Xcode 27.2 with the macOS 27.2 SDK on Apple Silicon. The project has no package setup step. Run commands from the repository root.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project MacClick.xcodeproj -scheme MacClick \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build build
open build/Build/Products/Release/MacClick.app

xcodebuild -project MacClick.xcodeproj -scheme MacClick \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build \
  -parallel-testing-enabled NO test
```

If a sandbox blocks Xcode’s connection to `testmanagerd`, use the hostless runner.

```sh
xcodebuild -project MacClick.xcodeproj -scheme MacClick \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build build-for-testing
xcrun xctest build/Build/Products/Debug/MacClickTests.xctest
```

## Coding Style and Naming

Use four-space indentation, Swift naming conventions, and descriptive file names. Follow nearby code. The project uses Swift 6 compiler checks and has no separate formatter or linter.

## Language

Reply in the language used by the person addressing you. Write source code, code comments, tests, documentation, issue and pull request text, and commit messages in English. Keep MacClick’s interface in English for now.

## Testing

Use XCTest files and case classes ending in `Tests` with test methods beginning with `test`. Cover new behavior and add a focused regression test for bug fixes. Run the affected tests and report the commands and results. The project has no enforced coverage threshold. Use the [hardware checklist](docs/Verification.md) for changes to capture, synthetic input, or UI behavior.

## Commits and Pull Requests

Use short, imperative commit subjects such as `Add keyboard shortcut handling`. In pull requests, summarize the change and include verification steps, relevant issue links, and screenshots for visible UI changes.

## Project Wiki and Error Log

Start at the [wiki index](docs/index.md) for project knowledge. Check [Errors.md](docs/Errors.md) for relevant entries before troubleshooting or retrying a failed operation. Record confirmed lessons using the entry format there and apply the prevention step when working in the affected area.
