# network_analyzer

Network monitoring and analysis for mobile devices. Planned API surface:
real-time monitoring, throughput scanner (Mbps), scanner history, and
diagnostic tools (MTR, Ping, TCPing).

This is the app-facing package of a federated plugin. Host applications
depend on this package only; the Android and iOS implementations are
endorsed and wired automatically.

## Usage

```dart
import 'package:network_analyzer/network_analyzer.dart';

final result = await const NetworkAnalyzer().getBridgeInfo();
result.fold(
  onFailure: (failure) => print(failure.message),
  onSuccess: (success) => print(success.value), // BridgeInfo(android 15)
);
```

All fallible operations return `Result<T, Failure>` and never throw.
