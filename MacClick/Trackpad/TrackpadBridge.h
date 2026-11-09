#ifndef MACCLICK_TRACKPAD_BRIDGE_H
#define MACCLICK_TRACKPAD_BRIDGE_H

#include <stdint.h>

typedef struct {
    int32_t id;
    float x;
    float y;
} MacClickContact;

typedef enum {
    MacClickTrackpadReady,
    MacClickTrackpadFrameworkUnavailable,
    MacClickTrackpadNotFound,
    MacClickTrackpadStartFailed
} MacClickTrackpadStatus;

// Lifecycle calls are made on the main thread. Only one session is active at a time.
MacClickTrackpadStatus MacClickTrackpadStart(uintptr_t session);
void MacClickTrackpadStop(void);

#endif
