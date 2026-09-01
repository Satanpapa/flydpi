#pragma once

#include <windows.h>
#include <fwpmu.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FlyDpiWfpObserver FlyDpiWfpObserver;

// Opens a dynamic WFP management session and subscribes to network events.
// Returns Win32/FWP error code; ERROR_SUCCESS on success.
DWORD flydpi_wfp_observer_start(FlyDpiWfpObserver** out_observer);

// Stops the observer and closes all owned handles.
void flydpi_wfp_observer_stop(FlyDpiWfpObserver* observer);

// Returns the number of events observed since start.
unsigned long long flydpi_wfp_observer_event_count(
    const FlyDpiWfpObserver* observer);

#ifdef __cplusplus
}
#endif
