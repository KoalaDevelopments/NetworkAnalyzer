import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

void main() {
  group('MonitorOptions', () {
    test('documented defaults apply when nothing is supplied', () {
      final MonitorOptions options = MonitorOptions();
      check(options.probeInterval).equals(const Duration(seconds: 1));
      check(options.probeTimeout).equals(const Duration(seconds: 1));
      check(options.sampleWindowSize).equals(10);
    });

    test('accepts values inside the documented bounds', () {
      final MonitorOptions options = MonitorOptions(
        probeInterval: const Duration(milliseconds: 200),
        probeTimeout: const Duration(milliseconds: 100),
        sampleWindowSize: 300,
      );
      check(options.sampleWindowSize).equals(300);
    });

    test('rejects a probe interval below 200 ms', () {
      check(
        () => MonitorOptions(probeInterval: const Duration(milliseconds: 199)),
      ).throws<ArgumentError>();
    });

    test('rejects a probe interval above 60 s', () {
      check(
        () => MonitorOptions(probeInterval: const Duration(seconds: 61)),
      ).throws<ArgumentError>();
    });

    test('rejects a probe timeout below 100 ms', () {
      check(
        () => MonitorOptions(probeTimeout: const Duration(milliseconds: 99)),
      ).throws<ArgumentError>();
    });

    test('rejects a probe timeout above the probe interval', () {
      check(
        () => MonitorOptions(
          probeInterval: const Duration(milliseconds: 500),
          probeTimeout: const Duration(milliseconds: 600),
        ),
      ).throws<ArgumentError>();
    });

    test('rejects a sample window outside 1..300', () {
      check(() => MonitorOptions(sampleWindowSize: 0)).throws<ArgumentError>();
      check(
        () => MonitorOptions(sampleWindowSize: 301),
      ).throws<ArgumentError>();
    });

    test('equal values are equal and share a hash code', () {
      final MonitorOptions a = MonitorOptions();
      final MonitorOptions b = MonitorOptions();
      check(a).equals(b);
      check(a.hashCode).equals(b.hashCode);
    });
  });
}
