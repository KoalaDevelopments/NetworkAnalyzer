import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_analyzer/network_analyzer.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class _FakePlatform extends NetworkAnalyzerPlatform
    with MockPlatformInterfaceMixin {
  _FakePlatform(this._result);

  final Result<BridgeInfo, Failure> _result;

  @override
  Future<Result<BridgeInfo, Failure>> getBridgeInfo() async => _result;
}

void main() {
  group('NetworkAnalyzer.getBridgeInfo', () {
    test('forwards the success result from the platform', () async {
      const BridgeInfo info = BridgeInfo(
        operatingSystem: 'android',
        osVersion: '15',
      );
      NetworkAnalyzerPlatform.instance = _FakePlatform(
        const Result<BridgeInfo, Failure>.success(info),
      );

      final Result<BridgeInfo, Failure> result = await const NetworkAnalyzer()
          .getBridgeInfo();

      check(result.isSuccess).isTrue();
      check(result.success.value).equals(info);
    });

    test('forwards the failure result from the platform', () async {
      const BridgeFailure failure = BridgeFailure(message: 'bridge down');
      NetworkAnalyzerPlatform.instance = _FakePlatform(
        const Result<BridgeInfo, Failure>.failure(failure),
      );

      final Result<BridgeInfo, Failure> result = await const NetworkAnalyzer()
          .getBridgeInfo();

      check(result.isFailure).isTrue();
      check(result.failure.message).equals('bridge down');
    });
  });
}
