import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('BridgeInfo', () {
    const BridgeInfo info = BridgeInfo(
      operatingSystem: 'android',
      osVersion: '15',
    );

    test('equal values are equal and share a hash code', () {
      const BridgeInfo other = BridgeInfo(
        operatingSystem: 'android',
        osVersion: '15',
      );
      check(info).equals(other);
      check(info.hashCode).equals(other.hashCode);
    });

    test('different values are not equal', () {
      const BridgeInfo other = BridgeInfo(
        operatingSystem: 'ios',
        osVersion: '15',
      );
      check(info == other).isFalse();
    });

    test('toString is readable', () {
      check(info.toString()).equals('BridgeInfo(android 15)');
    });
  });
}
