/// What a monitoring session is watching.
///
/// Carried on every measurement and event so a consumer holding only one of
/// them still knows which kind of monitor produced it.
enum MonitorKind {
  /// The public internet, reached through a chosen target host.
  internet,

  /// The local network's default gateway, discovered automatically.
  gateway,
}
