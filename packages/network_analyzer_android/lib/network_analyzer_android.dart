import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:network_analyzer_android/src/messages.g.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// The Android implementation of [NetworkAnalyzerPlatform].
///
/// Communicates with the native side exclusively through the
/// pigeon-generated [NetworkAnalyzerHostApi] (constitution, Principle II).
final class NetworkAnalyzerAndroid extends NetworkAnalyzerPlatform {
  /// Creates the Android implementation.
  ///
  /// [api] is injectable for tests; production code uses the default
  /// pigeon-generated client.
  NetworkAnalyzerAndroid({NetworkAnalyzerHostApi? api})
    : _api = api ?? NetworkAnalyzerHostApi();

  final NetworkAnalyzerHostApi _api;

  /// Registers this class as the default instance of
  /// [NetworkAnalyzerPlatform].
  ///
  /// Invoked by the Flutter tool through the `dartPluginClass` entry in
  /// the pubspec; never called manually.
  static void registerWith() {
    NetworkAnalyzerPlatform.instance = NetworkAnalyzerAndroid();
  }

  @override
  Future<Result<BridgeInfo, Failure>> getBridgeInfo() async {
    try {
      final BridgeInfoMessage message = await _api.getBridgeInfo();
      return Result<BridgeInfo, Failure>.success(
        BridgeInfo(
          operatingSystem: message.operatingSystem,
          osVersion: message.osVersion,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'getBridgeInfo failed',
        name: 'network_analyzer_android',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
      return Result<BridgeInfo, Failure>.failure(
        BridgeFailure(
          message: 'Failed to read native bridge info.',
          details: '$error',
        ),
      );
    }
  }
}
