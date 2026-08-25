import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class _ExtendsPlatform extends NetworkAnalyzerPlatform {}

final class _ImplementsPlatform extends PlatformInterface
    implements NetworkAnalyzerPlatform {
  _ImplementsPlatform() : super(token: _fakeToken);

  static final Object _fakeToken = Object();

  @override
  Future<Result<SessionData, Failure>> startMonitoring(
    MonitorInterface target,
  ) => throw UnimplementedError();

  @override
  Future<Result<void, Failure>> stopMonitoring() => throw UnimplementedError();

  @override
  Future<Result<SessionData, Failure>> currentSession() =>
      throw UnimplementedError();

  @override
  Stream<MonitorSignal> monitorSignals() => throw UnimplementedError();
}

void main() {
  group('NetworkAnalyzerPlatform', () {
    test('default instance throws UnimplementedError for startMonitoring', () {
      check(
        () => NetworkAnalyzerPlatform.instance.startMonitoring(
          InternetInterface(
            protocol: MonitorProtocol.tcp,
            host: PresetHost.google,
          ),
        ),
      ).throws<UnimplementedError>();
    });

    test('default instance throws UnimplementedError for stopMonitoring', () {
      check(
        () => NetworkAnalyzerPlatform.instance.stopMonitoring(),
      ).throws<UnimplementedError>();
    });

    test('default instance throws UnimplementedError for currentSession', () {
      check(
        () => NetworkAnalyzerPlatform.instance.currentSession(),
      ).throws<UnimplementedError>();
    });

    test('default instance throws UnimplementedError for monitorSignals', () {
      check(
        () => NetworkAnalyzerPlatform.instance.monitorSignals(),
      ).throws<UnimplementedError>();
    });

    test('accepts an implementation that extends the interface', () {
      final _ExtendsPlatform platform = _ExtendsPlatform();
      NetworkAnalyzerPlatform.instance = platform;
      check(NetworkAnalyzerPlatform.instance).equals(platform);
    });

    test('rejects an implementation built with implements', () {
      check(
        () => NetworkAnalyzerPlatform.instance = _ImplementsPlatform(),
      ).throws<AssertionError>();
    });
  });
}
