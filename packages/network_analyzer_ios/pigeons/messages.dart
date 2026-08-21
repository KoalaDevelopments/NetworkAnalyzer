// Pigeon API definition for the iOS implementation.
//
// Regenerate with:
//   dart run pigeon --input pigeons/messages.dart
//
// The generated files (lib/src/messages.g.dart and Messages.g.swift) are
// committed after generation. Never edit generated files by hand and never
// hand-write channel code (constitution, Principle II).
//
// ignore_for_file: one_member_abstracts

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    swiftOut:
        'ios/network_analyzer_ios/Sources/network_analyzer_ios/Messages.g.swift',
    dartPackageName: 'network_analyzer_ios',
  ),
)
/// Identity of the native side, returned by the bootstrap probe.
class BridgeInfoMessage {
  BridgeInfoMessage({required this.operatingSystem, required this.osVersion});

  /// Lowercase operating system identifier, e.g. `ios`.
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
