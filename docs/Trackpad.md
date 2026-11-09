# Trackpad Compatibility

## Trackpad conflicts

MacClick observes touches alongside macOS. If both are assigned to a gesture, macOS can act before MacClick sends its shortcut. Change only the conflicting settings you use.

| macOS gesture | Where to change it |
| --- | --- |
| Swipe between Spaces and full-screen apps | **System Settings → Trackpad → More Gestures → Swipe between full-screen applications**. Choose the four-finger option or turn it off. |
| Mission Control and App Exposé | **System Settings → Trackpad → More Gestures → Mission Control / App Exposé**. These use vertical swipes. Choose four fingers or turn either one off if it conflicts with your gestures. |
| Look up and data detectors | **System Settings → Trackpad → Point & Click → Look up & data detectors**. Choose a force-click option if available, or turn it off to free a three-finger tap. |
| Three-finger drag | **System Settings → Accessibility → Pointer Control → Trackpad Options**. Change **Dragging style** from **Three Finger Drag**, or turn off **Use trackpad for dragging**. |
| Swipe between pages | **System Settings → Trackpad → More Gestures → Swipe between pages**. Select a two-finger setting or turn it off if the current choice uses three fingers. |

For either tap mapping, touch and lift lightly or place all fingers on the trackpad before pressing and releasing the button. Physical clicks fire on button release. MacClick leaves three-finger primary clicks to macOS when Three Finger Drag is enabled. A simultaneous primary click on another pointing device can match an active three- or four-finger chord on the built-in trackpad because Quartz does not identify the physical device on ordinary mouse events. Use one or two fingers for normal clicking and dragging.

For swipes, move all three fingers together and lift them to trigger the action once. A normal middle-button click follows the pointer and the receiving app decides how to handle it. Keyboard events use ordinary session routing, so an OS-reserved shortcut or one intercepted by another utility can take precedence. Temporarily disable overlapping mappings in other gesture utilities when verifying MacClick. [Apple’s Trackpad settings guide](https://support.apple.com/en-gb/guide/mac-help/mchlp1226/mac) and [three-finger drag guide](https://support.apple.com/en-us/102341) describe the controls.

## Capture and compatibility

AppKit documents raw indirect touches for views that opt in within the key window. A global event monitor observes events already posted to other applications. Those APIs do not provide a documented raw system-wide trackpad stream with the contact transitions this app needs. [Apple’s trackpad event guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html) and [global event monitor reference](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)) describe that delivery model.

[TrackpadBridge.c](../MacClick/Trackpad/TrackpadBridge.c) dynamically resolves the private MultitouchSupport symbols, selects a built-in non-opaque device, and checks that capture started. The Swift recognizer receives contact positions and IDs independent of the framework. The C contact layout and phase values are based on [TrackMagic’s reverse-engineered declarations](https://github.com/calftrail/TrackMagic/blob/master/MultitouchSupport.h). Runtime checks detect missing symbols and startup failures. Apple can change the contact ABI without changing the exported symbols, so revalidate physical gestures after macOS updates.

MacClick supports the built-in MacBook trackpad only. The private framework precludes Mac App Store distribution under Apple’s public API rule. Build from source for local use. [Apple App Review Guidelines §2.5.1](https://developer.apple.com/app-store/review/guidelines/#software-requirements).
