//! Background pump from the native WFP observer into the Rust datapath.
//!
//! This worker performs observation/normalization only. It never mutates network
//! packets and stops cleanly when the returned handle is dropped.

use std::sync::{atomic::{AtomicBool, Ordering}, Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use crate::datapath::Datapath;
use crate::ring::EventRing;
use crate::wfp_bridge::{feed_snapshot, WfpObserverBridge};

#[derive(Debug, Default)]
pub struct IngestStats {
    pub snapshots_seen: u64,
    pub events_normalized: u64,
    pub snapshots_rejected: u64,
    pub observer_dropped: u64,
}

pub struct IngestWorker {
    stop: Arc<AtomicBool>,
    join: Option<JoinHandle<IngestStats>>,
}

impl IngestWorker {
    pub fn start(
        dll_path: String,
        datapath: Arc<Mutex<Datapath>>,
        events: Arc<Mutex<EventRing>>,
    ) -> Result<Self, crate::wfp_bridge::BridgeError> {
        let bridge = WfpObserverBridge::open(&dll_path)?;
        let stop = Arc::new(AtomicBool::new(false));
        let stop_thread = Arc::clone(&stop);

        let join = thread::Builder::new()
            .name("flydpi-wfp-ingest".to_owned())
            .spawn(move || {
                let mut stats = IngestStats::default();

                while !stop_thread.load(Ordering::Acquire) {
                    let mut drained = 0u32;
                    while let Some(snapshot) = bridge.pop() {
                        drained += 1;
                        stats.snapshots_seen = stats.snapshots_seen.saturating_add(1);

                        let event = match datapath.lock() {
                            Ok(mut dp) => feed_snapshot(&mut dp, &snapshot),
                            Err(_) => None,
                        };

                        match event {
                            Some(event) => {
                                stats.events_normalized = stats.events_normalized.saturating_add(1);
                                if let Ok(mut ring) = events.lock() {
                                    ring.push(event);
                                }
                            }
                            None => stats.snapshots_rejected = stats.snapshots_rejected.saturating_add(1),
                        }
                    }

                    stats.observer_dropped = bridge.dropped_count();
                    if drained == 0 {
                        thread::sleep(Duration::from_millis(2));
                    }
                }

                stats.observer_dropped = bridge.dropped_count();
                stats
            })
            .map_err(|_| crate::wfp_bridge::BridgeError::WorkerStartFailed)?;

        Ok(Self { stop, join: Some(join) })
    }

    pub fn stop(mut self) -> IngestStats {
        self.stop.store(true, Ordering::Release);
        self.join.take().map(|handle| handle.join().unwrap_or_default()).unwrap_or_default()
    }
}

impl Drop for IngestWorker {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        if let Some(handle) = self.join.take() {
            let _ = handle.join();
        }
    }
}
