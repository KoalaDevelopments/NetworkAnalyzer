/// How monitoring probes are sent to a target.
///
/// Not every protocol is valid for every monitor kind: a gateway monitor
/// accepts only [tcp] and [icmp]. A platform that cannot honor a protocol
/// reports an unsupported-capability failure rather than substituting a
/// different one.
enum MonitorProtocol {
  /// Times a TCP connection handshake to the target port.
  ///
  /// The most portable choice: it needs no special socket permission and
  /// works on every network that allows outbound connections.
  tcp,

  /// Sends a datagram to the target port and times the reply.
  ///
  /// Rejected by a gateway monitor, whose target does not answer datagrams
  /// predictably.
  udp,

  /// Sends an ICMP echo request and times the echo reply.
  ///
  /// Closest to a classic `ping`. Uses an unprivileged ICMP datagram socket
  /// on both platforms, so it needs no elevated permission and needs no NDK
  /// component on Android.
  ///
  /// **On cellular networks, expect ICMP to look worse than TCP or UDP.**
  /// Most carriers give ICMP echo the lowest forwarding priority and
  /// rate-limit it, so its latency runs higher and far more variable than
  /// application traffic on the same connection — several hundred
  /// milliseconds against ~100 ms of TCP is normal, and early probes may be
  /// dropped entirely while the radio promotes out of idle. That gap is a
  /// real property of how the carrier treats ICMP, faithfully measured — not
  /// a defect in the connection or in the measurement. To approximate what
  /// applications will actually experience, probe with [tcp] or [udp]; use
  /// [icmp] when the classic ping semantics are what you want to observe.
  ///
  /// **IPv4 only in this version.** An ICMPv6 echo needs a different checksum
  /// computed over an IPv6 pseudo-header, which is not implemented yet. On an
  /// IPv6-only network, starting an ICMP monitor reports an
  /// unsupported-capability failure — TCP and UDP keep working there, because
  /// they resolve through the system's NAT64 address synthesis.
  icmp,
}
