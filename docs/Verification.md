# MacClick 1.0 Verification

## Automated checks

Verified on November 9, 2026 with Xcode 27.2 and Swift 6 language mode on an arm64 Mac running macOS 27.2 (26B123).

| Check | Result |
| --- | --- |
| Release build, bundle metadata, and signature | Built an arm64 application with minimum macOS 27.2 and `LSUIElement=true`. The local ad hoc signature passed `codesign --verify --strict`. |
| XCTest | 19 tests passed from a fresh copy of the source. Both the standard Xcode test runner in the logged-in environment and the direct hostless runner passed. |
| Launch | Launch Services started the app and reported the accessory activation policy. |
| AppKit smoke check | Verified the template icon, all four menu commands, page switching, recording a shortcut with a synthetic AppKit key event sent to the settings window, restoring its default action, and release of the settings controller on close. |
| Native capture startup | The live C bridge selected the built-in non-opaque device, started and stopped it three times, and received callbacks. This was a startup and lifecycle probe without a prescribed physical gesture sequence. |

Run the [contributor commands](../AGENTS.md#build-test-and-development-commands) to reproduce the build and tests. The synthetic suite covers all four gestures, direction and movement thresholds, invalid finger counts, staggered contact and release, replacement fingers, interruption, duplicate prevention, disabled mappings, and settings persistence. It runs without touching the trackpad or posting system input.

## Build 2 follow-up

The Release build and 25 XCTest cases passed. The build was installed in Applications, the signature and icon resource were verified, and Launch Services reported accessory activation. AppKit resolved the new icon from the installed path. Six new synthetic cases cover staggered taps, physical button handling, duplicate prevention, and the original swipe assembly window. macOS rejected the previous build’s permission grant for the new signature. After the stale grant was cleared and access was granted again, the user reported that clicking worked. The remaining hardware checklist items have separate verification requirements.

## Build 3 follow-up

The Release build and all 25 XCTest cases passed. The installed bundle passed signature verification and launched in accessory mode. Its metadata names `MacClick` in both `CFBundleIconName` and `CFBundleIconFile`. The compiled asset catalog contains ten icon renditions, and AppKit resolved the trackpad icon from the installed path. The installed bundle occupied 512 KiB on disk on the test Mac. The new build requires a fresh macOS permission grant. The Device Control and Data Access row remains to be checked visually.

## Idle measurements

Sampled each process six times at five-second intervals with `ps`. Physical footprint is from `vmmap -summary` after the final sample. CPU average is the change in cumulative CPU time divided by the 25-second sample window and is expressed as a percentage of one core.

| Run | Physical footprint | Resident set at final sample | Average CPU |
| --- | ---: | ---: | ---: |
| Release, Accessibility off and Settings closed | 13.9 MiB | 67.5 MiB | 0.24% |
| Instrumented Release, built-in trackpad capture running and Settings closed | 27.3 MiB | 91.8 MiB | 0.16% |

The second run started the same capture path with a no-op output callback. It had already opened and closed Settings during the smoke check, so its footprint includes AppKit resources warmed by that window. These short samples describe this Mac and workload. Active-use and comparative performance remain unmeasured.

## Manual hardware checklist

Run on an Apple Silicon MacBook with the same macOS version as the build. Use disposable browser tabs. Record the Mac model, macOS version, receiving app and version, and any overlapping macOS or third-party gestures.

- [ ] Launch the copy in Applications. Confirm Finder shows the trackpad app icon, the menu bar icon appears in light and dark mode, the Dock has no MacClick icon, and all four menu commands are available. Open and close Settings several times.
- [ ] In **System Settings → Privacy & Security → Device Control and Data Access**, confirm MacClick shows its app icon. With permission off, confirm MacClick explains the requirement and gestures have no effect. Grant access, click **Retry**, and confirm the built-in trackpad is connected. Revoke it and confirm posting stops.
- [ ] Close Settings. In a browser, place the pointer over a link and tap the trackpad lightly with three fingers. Confirm the browser handles it as a real middle-button click, normally by opening a background tab.
- [ ] Tap with four fingers. Confirm one foreground tab closes and no middle click is generated.
- [ ] Repeat with a physical press after all three or four fingers touch down. Confirm one assigned action, with no extra primary click. Try releasing the button before lifting the fingers and lifting while releasing.
- [ ] Disable each tap mapping and confirm its physical click passes through. Check one-finger clicks and drags. With Three Finger Drag enabled, verify that three-finger dragging still works.
- [ ] Swipe right with three fingers. Confirm the next tab becomes active once when all fingers lift. Swipe left and confirm one move to the previous tab. Check that MacClick does not become active.
- [ ] Repeat with slightly staggered landings and lifts. Try one-, two-, and five-finger taps, four-finger swipes, vertical and diagonal motion, a long hold, and changing fingers mid-gesture. Confirm these produce no MacClick action.
- [ ] Verify ordinary pointing, clicking, two-finger scrolling, pinching, and your remaining macOS gestures. If an external trackpad is available, confirm MacClick acts only on the built-in one.
- [ ] Record a custom shortcut and map another gesture to **Middle Mouse Click**. Test the assigned actions, per-gesture and master switches, and **Restore Default**. Quit and relaunch to check persistence. Verify recognition works with Settings closed and while a different app is active.
- [ ] Sleep and wake the Mac, then repeat a gesture. If available, switch away from the login session and back and repeat.
- [ ] Enable **Launch at Login**, approve the login item if required, then log out and back in. Confirm that MacClick starts in the menu bar. Disable the setting and repeat the login check.
- [ ] With capture enabled, Settings closed, and the trackpad untouched, measure idle memory and CPU. Repeat after a sustained burst of normal trackpad use.

The user report confirms that clicking worked on the installed Build 2 after re-authorization. The complete per-gesture browser checks, sleep and wake, external-device exclusion, and actual login startup remain pending.
