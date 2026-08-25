import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_android/network_analyzer_android.dart';
import 'package:network_analyzer_android/src/messages.g.dart';
import 'package:network_analyzer_android/src/monitoring.g.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

final class _FakeHostApi extends NetworkAnalyzerHostApi {
  _FakeHostApi({PlatformException? error}) : _error = error;

  final PlatformException? _error;

  @override
  Future<BridgeInfoMessage> getBridgeInfo() async {
    final PlatformException? error = _error;
    if (error != null) {
      throw error;
    }
    return BridgeInfoMessage(operatingSystem: 'android', osVersion: '15');
  }
}

final class _FakeMonitoringApi extends MonitoringHostApi {
  _FakeMonitoringApi({this.error, this.session});

  final PlatformException? error;
  final SessionDataMessage? session;
  int stopCalls = 0;
  MonitorConfigMessage? lastConfig;

  SessionDataMessage get _defaultSession => SessionDataMessage(
    interfaceType: InterfaceTypeMessage.wifi,
    probeProtocol: ProtocolMessage.tcp,
    kind: KindMessage.internet,
    deviceIpAddress: '192.168.1.42',
    targetAddress: '8.8.8.8',
    targetName: 'Google Public DNS',
    startedAtUtcMillis: 1787654321000,
  );

  @override
  Future<SessionDataMessage> startSession(MonitorConfigMessage config) async {
    lastConfig = config;
    final PlatformException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return session ?? _defaultSession;
  }

  @override
  Future<void> stopSession() async {
    stopCalls++;
    final PlatformException? failure = error;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<SessionDataMessage?> currentSession() async {
    final PlatformException? failure = error;
    if (failure != null) {
      throw failure;
    }
    return session;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkAnalyzerAndroid', () {
    test('registerWith sets the platform instance', () {
      NetworkAnalyzerAndroid.registerWith();
      check(NetworkAnalyzerPlatform.instance).isA<NetworkAnalyzerAndroid>();
    });

    test('getBridgeInfo maps the pigeon message to BridgeInfo', () async {
      final NetworkAnalyzerAndroid platform = NetworkAnalyzerAndroid(
        api: _FakeHostApi(),
      );

      final Result<BridgeInfo, Failure> result = await platform.getBridgeInfo();

      check(result.isSuccess).isTrue();
      check(result.success.value).equals(
        const BridgeInfo(operatingSystem: 'android', osVersion: '15'),
      );
    });

    test('getBridgeInfo maps PlatformException to BridgeFailure', () async {
      final NetworkAnalyzerAndroid platform = NetworkAnalyzerAndroid(
        api: _FakeHostApi(
          error: PlatformException(code: 'bridge', message: 'native error'),
        ),
      );

      final Result<BridgeInfo, Failure> result = await platform.getBridgeInfo();

      check(result.isFailure).isTrue();
      check(result.failure).isA<BridgeFailure>();
      check(result.failure.details).isNotNull();
    });
  });

  group('NetworkAnalyzerAndroid monitoring', () {
    MonitorInterface target() => InternetInterface(
      protocol: MonitorProtocol.tcp,
      host: PresetHost.google,
    );

    test('startMonitoring maps the pigeon message to SessionData', () async {
      final _FakeMonitoringApi api = _FakeMonitoringApi();
      final NetworkAnalyzerAndroid platform = NetworkAnalyzerAndroid(
        monitoringApi: api,
      );

      final Result<SessionData, Failure> result = await platform
          .startMonitoring(target());

      check(result.isSuccess).isTrue();
      check(result.success.value.targetAddress).equals('8.8.8.8');
      check(result.success.value.startedAt.isUtc).isTrue();
      check(api.lastConfig?.targetIPv4).equals('8.8.8.8');
    });

    test('startMonitoring never throws and maps every native code', () async {
      final Map<String, Type> expected = <String, Type>{
        'PERMISSION_DENIED': PermissionFailure,
        'UNSUPPORTED_CAPABILITY': UnsupportedCapabilityFailure,
        'GATEWAY_DISCOVERY_FAILED': GatewayDiscoveryFailure,
        'INVALID_CONFIGURATION': InvalidConfigurationFailure,
        'SESSION_ALREADY_RUNNING': SessionAlreadyRunningFailure,
        'TARGET_UNREACHABLE': TargetUnreachableFailure,
        'SOMETHING_UNMAPPED': TargetUnreachableFailure,
      };

      for (final MapEntry<String, Type> entry in expected.entries) {
        final NetworkAnalyzerAndroid platform = NetworkAnalyzerAndroid(
          monitoringApi: _FakeMonitoringApi(
            error: PlatformException(code: entry.key, message: 'native'),
          ),
        );

        final Result<SessionData, Failure> result = await platform
            .startMonitoring(target());

        check(
          result.isFailure,
          because: 'expected ${entry.key} to fail',
        ).isTrue();
        check(
          result.failure.runtimeType,
          because: 'expected ${entry.key} to map to ${entry.value}',
        ).equals(entry.value);
      }
    });

    test('stopMonitoring succeeds and reaches the native side', () async {
      final _FakeMonitoringApi api = _FakeMonitoringApi();
      final NetworkAnalyzerAndroid platform = NetworkAnalyzerAndroid(
        monitoringApi: api,
      );

      final Result<void, Failure> result = await platform.stopMonitoring();

      check(result.isSuccess).isTrue();
      check(api.stopCalls).equals(1);
    });

    test('currentSession reports NoActiveSessionFailure when idle', () async {
      final NetworkAnalyzerAndroid platform = NetworkAnalyzerAndroid(
        monitoringApi: _FakeMonitoringApi(),
      );

      final Result<SessionData, Failure> result = await platform
          .currentSession();

      check(result.isFailure).isTrue();
      check(result.failure).isA<NoActiveSessionFailure>();
    });

    test('currentSession returns the running session', () async {
      final SessionDataMessage running = _FakeMonitoringApi()._defaultSession;

      final Result<SessionData, Failure> result = await NetworkAnalyzerAndroid(
        monitoringApi: _FakeMonitoringApi(session: running),
      ).currentSession();

      check(result.isSuccess).isTrue();
      check(result.success.value.kind).equals(MonitorKind.internet);
    });
  });
}
