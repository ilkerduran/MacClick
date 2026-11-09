#include "TrackpadBridge.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdatomic.h>

enum { MaxContacts = 4, MakeTouch = 3, Touching = 4, OutOfRange = 7 };

// Private arm64 contact layout. See the README for ABI evidence and limitations.
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t pathID;
    uint32_t state;
    int32_t fingerID;
    int32_t handID;
    float x, y, velocityX, velocityY;
    float quality;
    int32_t reserved1;
    float angle, majorAxis, minorAxis;
    float absoluteVector[4];
    int32_t reserved2[2];
    float density;
} MTContact;

_Static_assert(sizeof(MTContact) == 96, "Unexpected MTContact stride");
_Static_assert(offsetof(MTContact, x) == 32, "Unexpected MTContact position offset");

typedef void (*MTCallback)(CFTypeRef, const MTContact *, size_t, double, size_t, void *);

static struct {
    CFArrayRef (*createList)(void);
    bool (*isBuiltIn)(CFTypeRef);
    bool (*isOpaqueSurface)(CFTypeRef);
    void (*registerCallback)(CFTypeRef, MTCallback, void *);
    void (*unregisterCallback)(CFTypeRef, MTCallback);
    void (*start)(CFTypeRef, int);
    void (*stop)(CFTypeRef);
    bool (*isRunning)(CFTypeRef);
} mt;
static CFTypeRef trackpad;
static _Atomic uintptr_t idleSession;

// The library handle stays open after a successful load. Late callbacks can finish
// safely, and Swift discards their session numbers after the device is stopped.
static bool loadFramework(void) {
    if (mt.isRunning) return true;

    void *framework = dlopen(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        RTLD_NOW | RTLD_LOCAL
    );
    if (!framework) return false;

    mt.createList = dlsym(framework, "MTDeviceCreateList");
    mt.isBuiltIn = dlsym(framework, "MTDeviceIsBuiltIn");
    mt.isOpaqueSurface = dlsym(framework, "MTDeviceIsOpaqueSurface");
    mt.registerCallback = dlsym(framework, "MTRegisterContactFrameCallbackWithRefcon");
    mt.unregisterCallback = dlsym(framework, "MTUnregisterContactFrameCallback");
    mt.start = dlsym(framework, "MTDeviceStart");
    mt.stop = dlsym(framework, "MTDeviceStop");
    mt.isRunning = dlsym(framework, "MTDeviceIsRunning");

    if (mt.createList && mt.isBuiltIn && mt.isOpaqueSurface && mt.registerCallback &&
        mt.unregisterCallback && mt.start && mt.stop && mt.isRunning) {
        return true;
    }

    mt.isRunning = NULL;
    dlclose(framework);
    return false;
}

extern void MacClickReceiveContacts(
    uintptr_t session, const MacClickContact *contacts, int32_t count, double timestamp
);

static void receiveFrame(
    CFTypeRef device, const MTContact *touches, size_t count, double timestamp,
    size_t frame, void *context
) {
    MacClickContact contacts[MaxContacts];
    int32_t activeCount = 0;
    // A count above four (or an unknown contact state) invalidates this sequence.
    if (count > 32 || (count && !touches)) {
        activeCount = MaxContacts + 1;
    } else {
        for (size_t index = 0; index < count; index++) {
            const MTContact *touch = &touches[index];
            if (touch->state > OutOfRange) {
                activeCount = MaxContacts + 1;
                break;
            }
            if (touch->state != MakeTouch && touch->state != Touching) continue;
            if (activeCount == MaxContacts) {
                activeCount++;
                break;
            }
            contacts[activeCount++] = (MacClickContact){touch->pathID, touch->x, touch->y};
        }
    }
    const uintptr_t session = (uintptr_t)context;
    // Forward the release once, then keep idle frames off the Swift path.
    if (activeCount == 0) {
        if (atomic_load_explicit(&idleSession, memory_order_relaxed) == session) return;
        atomic_store_explicit(&idleSession, session, memory_order_relaxed);
    } else {
        atomic_store_explicit(&idleSession, 0, memory_order_relaxed);
    }
    MacClickReceiveContacts(session, contacts, activeCount, timestamp);
}

MacClickTrackpadStatus MacClickTrackpadStart(uintptr_t session) {
    if (!loadFramework()) return MacClickTrackpadFrameworkUnavailable;

    CFArrayRef devices = mt.createList();
    if (!devices) return MacClickTrackpadNotFound;
    for (CFIndex index = 0; index < CFArrayGetCount(devices); index++) {
        CFTypeRef device = CFArrayGetValueAtIndex(devices, index);
        if (mt.isBuiltIn(device) && !mt.isOpaqueSurface(device)) {
            trackpad = CFRetain(device);
            break;
        }
    }
    CFRelease(devices);
    if (!trackpad) return MacClickTrackpadNotFound;

    mt.registerCallback(trackpad, receiveFrame, (void *)session);
    mt.start(trackpad, 0);
    if (mt.isRunning(trackpad)) return MacClickTrackpadReady;

    MacClickTrackpadStop();
    return MacClickTrackpadStartFailed;
}

void MacClickTrackpadStop(void) {
    if (!trackpad) return;
    mt.unregisterCallback(trackpad, receiveFrame);
    mt.stop(trackpad);
    CFRelease(trackpad);
    trackpad = NULL;
}
