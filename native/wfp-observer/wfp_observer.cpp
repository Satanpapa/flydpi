#include "wfp_observer.h"

#include <atomic>
#include <memory>
#include <rpcdce.h>

struct FlyDpiWfpObserver {
    HANDLE engine = nullptr;
    HANDLE subscription = nullptr;
    std::atomic<unsigned long long> events{0};
};

static void CALLBACK on_net_event(void* context, const FWPM_NET_EVENT2* /*event*/) {
    if (context == nullptr) {
        return;
    }
    auto* observer = static_cast<FlyDpiWfpObserver*>(context);
    observer->events.fetch_add(1, std::memory_order_relaxed);
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
    if (observer == nullptr) {
        return 0;
    }
    return observer->events.load(std::memory_order_relaxed);
}
