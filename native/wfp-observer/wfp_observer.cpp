#include "wfp_observer.h"
#include "wfp_event_snapshot.h"

#include <atomic>
#include <cstring>
#include <memory>
#include <rpcdce.h>
#include <windows.h>

struct FlyDpiWfpObserver {
    HANDLE engine = nullptr;
    HANDLE subscription = nullptr;
    std::atomic<unsigned long long> events{0};
    std::atomic<unsigned long long> dropped{0};
    FlyDpiEventSnapshot latest{};
};

static void CALLBACK on_net_event(void* context, const FWPM_NET_EVENT2* event) {
    if (context == nullptr || event == nullptr) {
        return;
    }

    auto* observer = static_cast<FlyDpiWfpObserver*>(context);
    FlyDpiEventSnapshot snapshot{};
    snapshot.timestamp_100ns = event->header.timeStamp ?
        static_cast<uint64_t>(event->header.timeStamp->QuadPart) : 0;
    snapshot.ip_version = event->header.ipVersion;
    snapshot.protocol = event->header.ipProtocol;
    snapshot.local_port = event->header.localPort;
    snapshot.remote_port = event->header.remotePort;
    snapshot.process_id = static_cast<uint32_t>(event->header.processId);
    snapshot.event_code = event->header.eventType;
    snapshot.status = event->header.msFwpResult;

    // Single-writer callback path. Readers only consume a copied snapshot
    // through the C ABI; no Windows SDK structures cross that boundary.
    observer->latest = snapshot;
    observer->events.fetch_add(1, std::memory_order_release);
}

extern "C" DWORD flydpi_wfp_observer_start(FlyDpiWfpObserver** out_observer) {
    if (out_observer == nullptr) {
        return ERROR_INVALID_PARAMETER;
    }
    *out_observer = nullptr;

    auto observer = std::make_unique<FlyDpiWfpObserver>();
    FWPM_SESSION0 session{};
    session.flags = FWPM_SESSION_FLAG_DYNAMIC;

    DWORD rc = FwpmEngineOpen0(
        nullptr,
        RPC_C_AUTHN_DEFAULT,
        nullptr,
        &session,
        &observer->engine);
    if (rc != ERROR_SUCCESS) {
        return rc;
    }

    FWPM_NET_EVENT_SUBSCRIPTION0 subscription{};
    rc = FwpmNetEventSubscribe1(
        observer->engine,
        &subscription,
        on_net_event,
        observer.get(),
        &observer->subscription);
    if (rc != ERROR_SUCCESS) {
        FwpmEngineClose0(&observer->engine);
        return rc;
    }

    *out_observer = observer.release();
    return ERROR_SUCCESS;
}

extern "C" void flydpi_wfp_observer_stop(FlyDpiWfpObserver* observer) {
    if (observer == nullptr) {
        return;
    }
    if (observer->subscription != nullptr) {
        FwpmNetEventUnsubscribe0(observer->engine, observer->subscription);
        observer->subscription = nullptr;
    }
    if (observer->engine != nullptr) {
        FwpmEngineClose0(&observer->engine);
        observer->engine = nullptr;
    }
    delete observer;
}

extern "C" unsigned long long flydpi_wfp_observer_event_count(
    const FlyDpiWfpObserver* observer) {
    return observer == nullptr ? 0 : observer->events.load(std::memory_order_acquire);
}

extern "C" DWORD flydpi_wfp_observer_latest(
    const FlyDpiWfpObserver* observer,
    FlyDpiEventSnapshot* out_snapshot) {
    if (observer == nullptr || out_snapshot == nullptr) {
        return ERROR_INVALID_PARAMETER;
    }
    *out_snapshot = observer->latest;
    return ERROR_SUCCESS;
}
