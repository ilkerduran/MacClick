# MacClick Error Log

Search this log before retrying a failed operation or changing an area with a known failure. Apply any relevant prevention step. Add an entry when evidence confirms a mistake that could recur. Update the existing entry if the same mistake recurs or new evidence changes the diagnosis.

## Entry Format

```markdown
## ERR-001 · YYYY-MM-DD · Short description

- **Symptom and impact** — What failed, where it happened, and what it affected.
- **Cause and evidence** — What caused the failure, with a link to a file, issue, or log excerpt.
- **Fix and verification** — What changed and how the result was checked. Mark pending verification explicitly.
- **Prevention** — The specific check or guardrail to use next time and where to apply it.
```

## Recorded Errors

## ERR-001 · 2026-11-09 · Missing private device validation symbol

- **Symptom and impact** — The first feasibility probe crashed during device enumeration.
- **Cause and evidence** — The macOS 27.2 framework does not export `MTDeviceIsValid`. The probe called the null function pointer returned by `dlsym`. The corrected probe identified a built-in non-opaque trackpad.
- **Fix and verification** — [The bridge](../MacClick/Trackpad/TrackpadBridge.c) checks every required symbol before use and uses `MTDeviceIsRunning` to verify startup. The live bridge probe completed three start/stop cycles outside the development sandbox.
- **Prevention** — Validate the symbol set on the actual target OS before calling private framework functions.

## ERR-002 · 2026-11-09 · Sandboxed Xcode test runner could not connect

- **Symptom and impact** — `xcodebuild test` built the targets but could not launch the tests in the workspace sandbox.
- **Cause and evidence** — The connection to `com.apple.testmanagerd.control` failed at lookup with error 159 and reported a sandbox restriction.
- **Fix and verification** — The same hostless test bundle ran with `xcrun xctest`. The [contributor guide](../AGENTS.md) documents the build-for-testing and direct runner commands.
- **Prevention** — Use the direct runner in restricted shells and report compilation and test execution separately. Run GUI and raw capture probes in a normal logged-in macOS session.

## ERR-003 · 2026-11-09 · Menu bar symbol lookup returned no image

- **Symptom and impact** — A native AppKit smoke check found that the first build displayed the fallback title instead of a template icon.
- **Cause and evidence** — The requested `trackpad` SF Symbol did not resolve on the test host.
- **Fix and verification** — [MacClick draws a small monochrome template image](../MacClick/MacClickApp.swift) with AppKit. The smoke check inspects the menu bar button’s template image directly.
- **Prevention** — Check template image creation on the target macOS version when changing menu bar artwork.

## ERR-004 · 2026-11-09 · Finder app icon missing from bundle

- **Symptom and impact** — The installed copy showed a generic icon in Applications even though the menu bar glyph was present.
- **Cause and evidence** — The app drew the menu bar image at runtime. The original bundle contained neither an icon resource nor the `CFBundleIconFile` key.
- **Fix and verification** — Build 2 bundled a standalone `MacClick.icns` and declared it in its Info.plist. The installed resource matched the Release icon, the bundle passed signature verification, and `NSWorkspace.icon(forFile:)` returned the new glyph for the installed path. Build 3 compiles the same glyph from the [asset catalog](../MacClick/Resources/Assets.xcassets).
- **Prevention** — Verify the icon key and the named resource in the built app when checking visible branding.

## ERR-005 · 2026-11-09 · Physical trackpad press had no recognition path

- **Symptom and impact** — The user reported intermittent three-finger clicks, four-finger clicks failing, and swipes appearing to work. They tried both light touches and physical presses.
- **Cause and evidence** — Build 1 recognized the release of contact frames as taps or swipes. It had no primary-button input path, so a physical press could only match incidentally if the contact sequence also fit the tap thresholds. The exact rejection reason for individual light taps was not captured.
- **Fix and verification** — Build 2 uses separate tap tolerances and a mouse-only Quartz event tap for physical clicks. Synthetic regressions covered three and four fingers, stagger, both release orders, extra contacts, and interruption. The user reported that clicking worked after re-authorizing the installed build.
- **Prevention** — Test an unpressed touch and a physical press separately for both finger counts, and check ordinary clicking and dragging.

## ERR-006 · 2026-11-09 · Ad hoc update invalidated the previous Accessibility grant

- **Symptom and impact** — The installed Build 2 launched but did not activate the input capture path after replacing Build 1.
- **Cause and evidence** — The two ad hoc signatures had different designated code hashes. macOS reported that the existing code requirement for `com.macclick.app` failed to match for `kTCCServicePostEvent` and denied preflight.
- **Fix and verification** — The new process received a `kTCCServicePostEvent` code-requirement mismatch even though the permission appeared enabled. Scoped `tccutil reset PostEvent com.macclick.app` and `tccutil reset Accessibility com.macclick.app` cleared the entries. The user reported that clicking worked after granting access again. The [setup guide](../README.md#first-run) explains how to authorize the installed copy.
- **Prevention** — Check Accessibility again after replacing an ad hoc build. Use a consistent development signing identity when available.

  On November 9, 2026, the user downloaded the published v1.0 archive and reported that MacClick did not appear in Device Control and Data Access. The installed process received the same code-requirement mismatch for `kTCCServicePostEvent`. The current release and the earlier local build use ad hoc signatures. Re-authorization of the downloaded copy is pending.

## ERR-007 · 2026-11-09 · App icon missing from the macOS permission list

- **Symptom and impact** — The user reported that Build 2 showed its icon in Finder but had no icon in Device Control and Data Access.
- **Cause and evidence** — Build 2 shipped only a standalone `.icns` and `CFBundleIconFile`. It did not declare a named app icon. The exact reason the permission pane omitted the old icon is unconfirmed.
- **Fix and verification** — Build 3 added an Xcode [app icon set](../MacClick/Resources/Assets.xcassets/MacClick.appiconset). AppKit resolved the trackpad glyph, but the user reported that the permission row still had no icon. Launch Services later listed two development copies and an old copy in the Trash under the same bundle ID. The duplicate registrations were removed and the generated development bundles were moved aside because Launch Services had registered them again. The user subsequently reported that the updated setup worked. The icon on the permission row was not independently observed.
- **Prevention** — Verify both icon metadata keys, the named rendition in the compiled catalog, and the permission row after changing bundle artwork.

## ERR-008 · 2026-11-09 · Privacy Settings shortcut hidden after permission grant

- **Symptom and impact** — The Open Privacy Settings button disappeared after MacClick was authorized, so the Settings page could not reopen the macOS permission pane.
- **Cause and evidence** — The status refresh hid the button when posting was allowed. The button action also opened the pane only if the permission request returned false.
- **Fix and verification** — Build 4 keeps the button visible and opens the same pane whether or not access is granted. An AppKit smoke check confirmed visibility in both states and verified that clicking with access already granted reaches the privacy URL.
- **Prevention** — Verify the privacy shortcut before and after granting access.
