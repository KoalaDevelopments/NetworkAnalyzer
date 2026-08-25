/// Address validation shared by the monitoring types.
///
/// Hand-rolled rather than delegating to `dart:io` so the platform interface
/// stays free of `dart:io` and can compile for any future target.
library;

/// Whether [value] is a dotted-quad IPv4 address.
bool isIPv4(String value) {
  final List<String> parts = value.split('.');
  if (parts.length != 4) {
    return false;
  }
  for (final String part in parts) {
    if (part.isEmpty || part.length > 3) {
      return false;
    }
    for (final int unit in part.codeUnits) {
      if (unit < 0x30 || unit > 0x39) {
        return false;
      }
    }
    final int? octet = int.tryParse(part);
    if (octet == null || octet > 255) {
      return false;
    }
  }
  return true;
}

/// Whether [value] is an IPv6 address, including the IPv4-mapped forms.
///
/// Accepts at most one `::` elision and an optional trailing IPv4 tail.
bool isIPv6(String value) {
  if (value.isEmpty || !value.contains(':')) {
    return false;
  }
  if (value.indexOf('::') != value.lastIndexOf('::')) {
    return false;
  }
  final int elision = value.indexOf('::');
  final String head = elision < 0 ? value : value.substring(0, elision);
  final String tail = elision < 0 ? '' : value.substring(elision + 2);
  final List<String> groups = <String>[
    ...head.isEmpty ? const <String>[] : head.split(':'),
    ...tail.isEmpty ? const <String>[] : tail.split(':'),
  ];
  if (groups.isEmpty && elision < 0) {
    return false;
  }

  int required = groups.length;
  if (groups.isNotEmpty && isIPv4(groups.last)) {
    // A trailing IPv4 tail occupies two 16-bit groups.
    required += 1;
    groups.removeLast();
  }
  if (elision < 0 ? required != 8 : required > 7) {
    return false;
  }

  for (final String group in groups) {
    if (group.isEmpty || group.length > 4) {
      return false;
    }
    for (final int unit in group.codeUnits) {
      final bool isDigit = unit >= 0x30 && unit <= 0x39;
      final bool isLower = unit >= 0x61 && unit <= 0x66;
      final bool isUpper = unit >= 0x41 && unit <= 0x46;
      if (!isDigit && !isLower && !isUpper) {
        return false;
      }
    }
  }
  return true;
}

/// Throws an [ArgumentError] unless [value] is a valid IPv4 address.
void requireIPv4(String value, String name) {
  if (!isIPv4(value)) {
    throw ArgumentError.value(value, name, 'must be a valid IPv4 address');
  }
}

/// Throws an [ArgumentError] unless [value] is a valid IPv6 address.
void requireIPv6(String value, String name) {
  if (!isIPv6(value)) {
    throw ArgumentError.value(value, name, 'must be a valid IPv6 address');
  }
}

/// Throws an [ArgumentError] unless [port] is a usable TCP or UDP port.
void requirePort(int port, String name) {
  if (port < 1 || port > 65535) {
    throw ArgumentError.value(port, name, 'must be between 1 and 65535');
  }
}
