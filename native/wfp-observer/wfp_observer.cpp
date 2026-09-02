#include "wfp_observer.h"
#include "wfp_event_snapshot.h"

#include <atomic>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <rpcdce.h>
#include <windows.h>
#include <winsock2.h>

namespace {
constexpr size_t kQueueCapacity = 4096;
}

struct FlyDpiWfpObserver {
    HANDLE engine = nullptr;
    HANDLE subscription = nullptr;
    std::atomic<unsigned long long> events{0};
    std::atomic<unsigned long long> dropped{0};
    mutable std::mutex queue_mutex;
    std::deque<FlyDpiEventSnapshot> queue;
};

static uint64_t filetime_to_u64(const FILETIME& value) {
    return (static_cast<uint64_t>(value.dwHighDateTime) << 32) | value.dwLowDateTime;
}

static bool has_flag(uint32_t flags, uint32_t flag) {
    return (flags & flag) != 0;
}

static void copy_ipv4_network_order(uint32_t value, uint8_t out[16]) {
    const uint32_t network_order = htonl(value);
    std::memcpy(out, &network_order, sizeof(network_order));
}

static void CALLBACK on_net_event(void* context, const FWPM_NET_EVENT2* event) {
    if (context == nullptr || event == nullptr) return;
    auto* observer = static_cast<FlyDpiWfpObserver*>(context);

    FlyDpiEventSnapshot snapshot{};
    snapshot.timestamp_100ns = filetime_to_u64(event->header.timeStamp);
    snapshot.flags = event->header.flags;
    snapshot.ip_version = static_cast<uint32_t>(event->header.ipVersion);
    snapshot.protocol = event->header.ipProtocol;
    snapshot.local_port = event->header.localPort;
    snapshot.remote_port = event->header.remotePort;
    snapshot.event_type = static_cast<uint32_t>(event->type);

    if (has_flag(snapshot.flags, FWPM_NET_EVENT_FLAG_IP_VERSION_SET)) {
        if (snapshot.ip_version == FWP_IP_VERSION_V4) {
            if (has_flag(snapshot.flags, FWPM_NET_EVENT_FLAG_LOCAL_ADDR_SET)) {
                copy_ipv4_network_order(event->header.localAddrV4, snapshot.local_addr);
                snapshot.has_local_addr = 1;
            }
            if (has_flag(snapshot.flags, FWPM_NET_EVENT_FLAG_REMOTE_ADDR_SET)) {
                copy_ipv4_network_order(event->header.remoteAddrV4, snapshot.remote_addr);
                snapshot.has_remote_addr = 1;
            }
        } else if (snapshot.ip_version == FWP_IP_VERSION_V6) {
            if (has_flag(snapshot.flags, FWPM_NET_EVENT_FLAG_LOCAL_ADDR_SET)) {
                std::memcpy(snapshot.local_addr, event->header.localAddrV6.byteArray16, 16);
                snapshot.has_local_addr = 1;
            }
            if (has_flag(snapshot.flags, FWPM_NET_EVENT_FLAG_REMOTE_ADDR_SET)) {
                std::memcpy(snapshot.remote_addr, event->header.remoteAddrV6.byteArray16, 16);
                snapshot.has_remote_addr = 1;
            }
        }
    }

    if (has_flag(snapshot.flags, FWPM_NET_EVENT_FLAG_APP_ID_SET) && event->header.appId.data != nullptr) {
        snapshot.has_app_id = 1;
        snapshot.app_id_length = static_cast<uint32_t>(event->header.appId.size);
        const uint32_t copy_len = snapshot.app_id_length < sizeof(snapshot.app_id_prefix)
            ? snapshot.app_id_length
            : static_cast<uint32_t>(sizeof(snapshot.app_id_prefix));
        if (copy_len != 0) {
            std::memcpy(snapshot.app_id_prefix, event->header.appId.data, copy_len);
        }
    }

    if (event->type == FWPM_NET_EVENT_TYPE_CLASSIFY_DROP && event->classifyDrop != nullptr) {
        snapshot.result_code = event->classifyDrop->msFwpResult;
    }

    {
        std::lock_guard<std::mutex> lock(observer->queue_mutex);
        if (observer->queue.size() >= kQueueCapacity) {
            observer->queue.pop_front();
            observer->dropped.fetch_add(1, std::memory_order_relaxed);
        }
        observer->queue.push_back(snapshot);
    }
    observer->events.fetch_add(1, std::memory_order_release);
}

extern "C" DWORD flydpi_wfp_observer_start(FlyDpiWfpObserver** out_observer) {
    if (out_observer == nullptr) return ERROR_INVALID_PARAMETER;
    *out_observer = nullptr;

    auto observer = std::make_unique<FlyDpiWfpObserver>();
    FWPM_SESSION0 session{};
    session.flags = FWPM_SESSION_FLAG_DYNAMIC;

    DWORD rc = FwpmEngineOpen0(nullptr, RPC_C_AUTHN_DEFAULT, nullptr, &session, &observer->engine);
    if (rc != ERROR_SUCCESS) return rc;

    FWPM_NET_EVENT_SUBSCRIPTION0 subscription{};
    rc = FwpmNetEventSubscribe1(observer->engine, &subscription, on_net_event, observer.get(), &observer->subscription);
    if (rc != ERROR_SUCCESS) {
        FwpmEngineClose0(observer->engine);
        observer->engine = nullptr;
        return rc;
    }

    *out_observer = observer.release();
    return ERROR_SUCCESS;
}

extern "C" void flydpi_wfp_observer_stop(FlyDpiWfpObserver* observer) {
    if (observer == nullptr) return;
    if (observer->subscription != nullptr) {
        FwpmNetEventUnsubscribe0(observer->engine, observer->subscription);
        observer->subscription = nullptr;
    }
    if (observer->engine != nullptr) {
        FwpmEngineClose0(observer->engine);
        observer->engine = nullptr;
    }
    delete observer;
}

extern "C" unsigned long long flydpi_wfp_observer_event_count(const FlyDpiWfpObserver* observer) {
    return observer == nullptr ? 0 : observer->events.load(std::memory_order_acquire);
}

extern "C" unsigned long long flydpi_wfp_observer_dropped_count(const FlyDpiWfpObserver* observer) {
    return observer == nullptr ? 0 : observer->dropped.load(std::memory_order_acquire);
}

extern "C" DWORD flydpi_wfp_observer_pop(FlyDpiWfpObserver* observer, FlyDpiEventSnapshot* out_snapshot) {
    if (observer == nullptr || out_snapshot == nullptr) return ERROR_INVALID_PARAMETER;
    std::lock_guard<std::mutex> lock(observer->queue_mutex);
    if (observer->queue.empty()) return ERROR_NOT_FOUND;
    *out_snapshot = observer->queue.front();
    observer->queue.pop_front();
    return ERROR_SUCCESS;
}

extern "C" DWORD flydpi_wfp_observer_latest(const FlyDpiWfpObserver* observer, FlyDpiEventSnapshot* out_snapshot) {
    if (observer == nullptr || out_snapshot == nullptr) return ERROR_INVALID_PARAMETER;
    std::lock_guard<std::mutex> lock(observer->queue_mutex);
    if (observer->queue.empty()) return ERROR_NOT_FOUND;
    *out_snapshot = observer->queue.back();
    return ERROR_SUCCESS;
}
