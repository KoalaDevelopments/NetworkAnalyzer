# Implementing a platform for network_analyzer

This package defines the contract between the app-facing
[`network_analyzer`](https://pub.dev/packages/network_analyzer) plugin and
its platform implementations. Host applications never use it directly.

A platform implementation extends `NetworkAnalyzerPlatform` — extending,
rather than implementing, is what keeps interface evolution non-breaking —
and registers itself as the default instance from its `dartPluginClass`
entry point:

```dart
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// A hypothetical desktop implementation.
final class NetworkAnalyzerLinux extends NetworkAnalyzerPlatform {
  /// Registers this class as the default instance of the platform.
  static void registerWith() {
    NetworkAnalyzerPlatform.instance = NetworkAnalyzerLinux();
  }

  // Override startMonitoring, stopMonitoring, currentSession and
  // monitorSignals with the platform-specific behavior. Fallible
  // operations return Result<T, Failure> and never throw.
}
```
