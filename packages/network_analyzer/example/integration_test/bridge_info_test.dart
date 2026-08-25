import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_analyzer/network_analyzer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bootstrap probe round-trips through the native bridge', (
    WidgetTester tester,
  ) async {
    final Result<BridgeInfo, Failure> result = await NetworkAnalyzer()
        .getBridgeInfo();

    check(result.isSuccess).isTrue();

    final BridgeInfo info = result.success.value;
    final String expectedOs = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unsupported',
    };
    check(info.operatingSystem).equals(expectedOs);
    check(info.osVersion).isNotEmpty();
  });
}
