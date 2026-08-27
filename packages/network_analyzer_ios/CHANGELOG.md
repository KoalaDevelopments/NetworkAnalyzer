## 0.1.0

* Initial release: iOS (Swift) implementation of real-time monitoring —
  `startMonitoring`, `stopMonitoring`, `currentSession` and the raw
  `monitorSignals()` stream, over a pigeon-typed platform channel.
  Registered via `dartPluginClass` (`NetworkAnalyzerIos`); SPM layout
  with a CocoaPods podspec for compatibility.
* ICMP via an unprivileged datagram socket; TCP/UDP probes resolve
  through `getaddrinfo`, so NAT64/DNS64 (IPv6-only) networks keep
  working; interface type via `NWPathMonitor`, cellular generation via
  `CoreTelephony`, gateway read from the BSD routing table.
* No permissions, entitlements or `Info.plist` keys required.
