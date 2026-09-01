#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FlyDpiEventSnapshot {
    uint64_t timestamp_100ns;
    uint32_t flags;
    uint32_t ip_version;
    uint8_t protocol;
    uint16_t local_port;
    uint16_t remote_port;
    uint32_t event_type;
    uint32_t result_code;
} FlyDpiEventSnapshot;

#ifdef __cplusplus
}
#endif
