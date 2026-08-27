# network_analyzer

Network monitoring and analysis for mobile devices. Current API
surface: real-time connection monitoring — latency, jitter, packet loss
and health over ICMP/TCP/UDP, against internet hosts or the local
gateway. Planned: throughput scanner (Mbps), scanner history, and
diagnostic tools (MTR, Ping, TCPing).

This is the app-facing package of a federated plugin. Host applications
depend on this package only; the Android and iOS implementations are
endorsed and wired automatically.

## Usage

```dart
import 'package:network_analyzer/network_analyzer.dart';

final analyzer = NetworkAnalyzer();

final result = await analyzer.startMonitoring(
  InternetInterface(
    protocol: MonitorProtocol.icmp,
    host: PresetHost.cloudflare,
  ),
);
result.fold(
  onFailure: (failure) => print(failure.message),
  onSuccess: (_) => print('monitoring started'),
);

analyzer.metrics.listen((m) => print('${m.latency} · ${m.health}'));

// Later:
await analyzer.stopMonitoring();
```

All fallible operations return `Result<T, Failure>` and never throw.
