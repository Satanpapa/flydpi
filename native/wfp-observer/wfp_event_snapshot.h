#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum FlyDpiEventKind {
    FLYDPI_EVENT_OTHER = 0,
    FLYDPI_EVENT_CLASSIFY_DROP = 1,
    FLYDPI_EVENT_AUTH_CONNECT = 2,
    FLYDPI_EVENT_AUTH_RECV_ACCEPT = 3,
} FlyDpiEventKind;

typedef struct FlyDpiEventSnapshot {
    uint64_t timestamp_100ns;
    uint32_t ip_version;
    uint8_t protocol;
    uint8_t direction;
    uint16_t local_port;
    uint16_t remote_port;
    uint32_t process_id;
    uint32_t event_code;
    uint32_t status;
} FlyDpiEventSnapshot;

#ifdef __cplusplus
}
#endif
