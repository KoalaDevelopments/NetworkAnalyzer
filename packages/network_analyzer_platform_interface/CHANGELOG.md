## 0.1.0

* Initial release: the real-time monitoring contract.
* `NetworkAnalyzerPlatform`: `startMonitoring`, `stopMonitoring`,
  `currentSession` and the raw `monitorSignals()` stream that platform
  implementations must provide.
* Shared monitoring domain: `SessionData`, `MonitorSignal`,
  `ProbeSample`, `ConnectionMetrics`, `ConnectionHealth`,
  `MonitorInterface` (internet/gateway), `MonitorHost` (preset/custom),
  `MonitorProtocol` (ICMP/TCP/UDP), `MonitorOptions`,
  `HealthThresholds`, `MonitorEvent`/`MonitorUpdate`, and the monitoring
  `Failure` hierarchy.
* `Result`/`Failure`/`Success` functional core — fallible operations
  return `Result<T, Failure>` and never throw.
