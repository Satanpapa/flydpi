#pragma once

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FlyDpiRuntime FlyDpiRuntime;

typedef struct FlyDpiRuntimeEvent {
    uint64_t timestamp_unix_ms;
    uint32_t kind;
    uint32_t protocol;
    uint16_t remote_port;
    uint32_t process_id;
    uint64_t latency_ms;
    int32_t error_code;
    uint32_t reserved;
} FlyDpiRuntimeEvent;

// Starts the observation runtime using the supplied native WFP observer DLL.
// Returns NULL on invalid arguments, load failure, or WFP startup failure.
FlyDpiRuntime* flydpi_runtime_start(const char* observer_dll_path);

// Polls one event. Returns 1 when an event was written, 0 when no event is
// currently available, or 87 for invalid arguments.
uint32_t flydpi_runtime_poll(FlyDpiRuntime* runtime, FlyDpiRuntimeEvent* out_event);

// Drains up to capacity events into the caller-owned array. Returns the number
// of events written, or 0 for invalid arguments / no available events.
size_t flydpi_runtime_drain(
    FlyDpiRuntime* runtime,
    FlyDpiRuntimeEvent* out_events,
    size_t capacity);

// Stops the runtime and releases all worker-owned resources.
void flydpi_runtime_stop(FlyDpiRuntime* runtime);

#ifdef __cplusplus
}
#endif
