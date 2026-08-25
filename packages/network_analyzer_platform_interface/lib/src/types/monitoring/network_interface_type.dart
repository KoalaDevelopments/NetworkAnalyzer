/// The kind of network interface a session is running over.
///
/// Cellular generation is best effort. On Android it requires the host
/// application to hold `READ_PHONE_STATE`, which this plugin deliberately
/// does not declare; without it a mobile connection is reported as
/// [cellular] rather than guessed at. iOS resolves the generation without
/// any permission.
enum NetworkInterfaceType {
  /// A wired connection.
  ethernet,

  /// A Wi-Fi connection.
  wifi,

  /// A 5G mobile connection.
  cellular5g,

  /// A 4G or LTE mobile connection.
  cellular4g,

  /// A 3G mobile connection.
  cellular3g,

  /// A 2G, GPRS or EDGE mobile connection.
  cellular2g,

  /// A mobile connection whose generation could not be determined.
  cellular,

  /// A virtual private network interface.
  vpn,

  /// A connected interface of some other kind.
  other,

  /// No interface: the device has no connectivity.
  none,

  /// The interface could not be determined.
  unknown;

  /// Whether this value describes a mobile data connection.
  bool get isCellular => switch (this) {
    cellular5g || cellular4g || cellular3g || cellular2g || cellular => true,
    ethernet || wifi || vpn || other || none || unknown => false,
  };

  /// Whether the device has any connectivity at all.
  bool get isConnected => this != none && this != unknown;
}
