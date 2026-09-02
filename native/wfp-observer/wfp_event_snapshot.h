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
    uint8_t local_addr[16];
    uint8_t remote_addr[16];
    uint32_t event_type;
    uint32_t result_code;
    uint8_t has_local_addr;
    uint8_t has_remote_addr;
    uint8_t has_app_id;
    uint8_t reserved0;
    uint32_t app_id_length;
    uint8_t app_id_prefix[64];
} FlyDpiEventSnapshot;

typedef enum FlyDpiWfpEventKind {
    FLYDPI_WFP_EVENT_OTHER = 0,
    FLYDPI_WFP_EVENT_CLASSIFY_DROP = 1,
    FLYDPI_WFP_EVENT_CLASSIFY_ALLOW = 2,
    FLYDPI_WFP_EVENT_IPSEC_DROP = 3,
    FLYDPI_WFP_EVENT_CAPABILITY_DROP = 4,
    FLYDPI_WFP_EVENT_CAPABILITY_ALLOW = 5
} FlyDpiWfpEventKind;

#ifdef __cplusplus
}
#endif
