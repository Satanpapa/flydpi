#pragma once

#include <windows.h>
#include <fwpmu.h>
#include "wfp_event_snapshot.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FlyDpiWfpObserver FlyDpiWfpObserver;

// Opens a dynamic WFP management session and subscribes to network events.
DWORD flydpi_wfp_observer_start(FlyDpiWfpObserver** out_observer);

// Stops the observer and closes all owned handles.
void flydpi_wfp_observer_stop(FlyDpiWfpObserver* observer);

// Number of events received from WFP since start.
unsigned long long flydpi_wfp_observer_event_count(const FlyDpiWfpObserver* observer);

// Number of events dropped because the bounded queue was full.
unsigned long long flydpi_wfp_observer_dropped_count(const FlyDpiWfpObserver* observer);

// Copies and removes the oldest queued event. Returns ERROR_NOT_FOUND when empty.
DWORD flydpi_wfp_observer_pop(FlyDpiWfpObserver* observer, FlyDpiEventSnapshot* out_snapshot);

// Copies the most recent event without removing it. Returns ERROR_NOT_FOUND when empty.
DWORD flydpi_wfp_observer_latest(const FlyDpiWfpObserver* observer, FlyDpiEventSnapshot* out_snapshot);

#ifdef __cplusplus
}
#endif
