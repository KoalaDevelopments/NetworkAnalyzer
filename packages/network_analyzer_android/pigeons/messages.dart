// Pigeon API definition for the Android implementation.
//
// Regenerate with:
//   dart run pigeon --input pigeons/messages.dart
//
// The generated files (lib/src/messages.g.dart and Messages.g.kt) are
// committed after generation. Never edit generated files by hand and never
// hand-write channel code (constitution, Principle II).
//
// ignore_for_file: one_member_abstracts

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/koaladevelopments/network_analyzer_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.koaladevelopments.network_analyzer_android',
    ),
    dartPackageName: 'network_analyzer_android',
  ),
)
/// Identity of the native side, returned by the bootstrap probe.
class BridgeInfoMessage {
  BridgeInfoMessage({required this.operatingSystem, required this.osVersion});

  /// Lowercase operating system identifier, e.g. `android`.
  String operatingSystem;

  /// The operating system version string.
  String osVersion;
}

/// Bootstrap host API proving the typed channel round-trip.
///
/// Feature APIs are added here per feature through the Spec Kit flow.
@HostApi()
abstract class NetworkAnalyzerHostApi {
  /// Returns the identity of the native side.
  BridgeInfoMessage getBridgeInfo();
}
