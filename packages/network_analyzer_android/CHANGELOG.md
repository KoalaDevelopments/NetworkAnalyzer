## 0.1.0

* Initial release: Android (Kotlin) implementation of real-time
  monitoring — `startMonitoring`, `stopMonitoring`, `currentSession` and
  the raw `monitorSignals()` stream, over a pigeon-typed platform
  channel. Registered via `dartPluginClass` (`NetworkAnalyzerAndroid`).
* ICMP via an unprivileged datagram socket (no root, no NDK); TCP and
  UDP probes; interface type via `ConnectivityManager`. Only the normal
  permissions `INTERNET` and `ACCESS_NETWORK_STATE` are declared.
* ICMP is IPv4-only in this version: on IPv6-only networks it returns
  `UnsupportedCapabilityFailure`, while TCP and UDP keep working.
