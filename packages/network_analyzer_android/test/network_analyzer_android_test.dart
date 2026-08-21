import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_android/network_analyzer_android.dart';
import 'package:network_analyzer_android/src/messages.g.dart';
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
}
