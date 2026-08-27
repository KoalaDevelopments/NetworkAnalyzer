## 0.1.0

* Initial release: real-time connection monitoring.
* `NetworkAnalyzer` facade: `startMonitoring(MonitorInterface)`,
  `stopMonitoring()`, synchronous `currentSession`, the `metrics`,
  `events` and `updates` streams, and `dispose()`.
* Monitors the internet path (`InternetInterface` — preset or custom
  hosts, ICMP/TCP/UDP probes) or the local gateway (`GatewayInterface`).
* Probe cadence, timeout and rolling sample window tunable via
  `MonitorOptions`; health evaluation, jitter and packet loss computed
  over the window; session events throttled and timestamped in UTC.
* All fallible operations return `Result<T, Failure>` and never throw.
* Endorses `network_analyzer_android` and `network_analyzer_ios`.
