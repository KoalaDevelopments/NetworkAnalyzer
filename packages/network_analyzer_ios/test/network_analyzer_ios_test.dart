import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer_ios/network_analyzer_ios.dart';
import 'package:network_analyzer_ios/src/messages.g.dart';
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
    return BridgeInfoMessage(operatingSystem: 'ios', osVersion: '18.4');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkAnalyzerIos', () {
    test('registerWith sets the platform instance', () {
      NetworkAnalyzerIos.registerWith();
      check(NetworkAnalyzerPlatform.instance).isA<NetworkAnalyzerIos>();
    });

    test('getBridgeInfo maps the pigeon message to BridgeInfo', () async {
      final NetworkAnalyzerIos platform = NetworkAnalyzerIos(
        api: _FakeHostApi(),
      );

      final Result<BridgeInfo, Failure> result = await platform.getBridgeInfo();

      check(result.isSuccess).isTrue();
      check(result.success.value).equals(
        const BridgeInfo(operatingSystem: 'ios', osVersion: '18.4'),
      );
    });

    test('getBridgeInfo maps PlatformException to BridgeFailure', () async {
      final NetworkAnalyzerIos platform = NetworkAnalyzerIos(
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
