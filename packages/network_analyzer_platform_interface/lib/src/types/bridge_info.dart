import 'package:meta/meta.dart';

/// Identity of the native side of the plugin, reported over the typed
/// pigeon channel.
///
/// This is the bootstrap probe type used to verify the Dart↔native
/// round-trip. Feature domain types are added per feature through the
/// Spec Kit flow.
@immutable
final class BridgeInfo {
  /// Creates a [BridgeInfo] with the reported [operatingSystem] and
  /// [osVersion].
  const BridgeInfo({required this.operatingSystem, required this.osVersion});

  /// Lowercase operating system identifier reported by the native side,
  /// e.g. `android` or `ios`.
  final String operatingSystem;

  /// The operating system version string, as reported by the platform.
  final String osVersion;

  @override
  bool operator ==(Object other) =>
      other is BridgeInfo &&
      other.operatingSystem == operatingSystem &&
      other.osVersion == osVersion;

  @override
  int get hashCode => Object.hash(operatingSystem, osVersion);

  @override
  String toString() => 'BridgeInfo($operatingSystem $osVersion)';
}
