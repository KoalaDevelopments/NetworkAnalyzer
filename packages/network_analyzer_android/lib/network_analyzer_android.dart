import 'package:flutter/services.dart';
import 'package:network_analyzer_android/src/monitoring.g.dart';
import 'package:network_analyzer_android/src/monitoring/monitor_failures.dart';
import 'package:network_analyzer_android/src/monitoring/monitor_mapper.dart';
import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// The Android implementation of [NetworkAnalyzerPlatform].
///
/// Communicates with the native side exclusively through the
/// pigeon-generated [MonitoringHostApi] (constitution, Principle II).
final class NetworkAnalyzerAndroid extends NetworkAnalyzerPlatform {
  /// Creates the Android implementation.
  ///
  /// [monitoringApi] is injectable for tests; production code uses the
  /// default pigeon-generated client.
  NetworkAnalyzerAndroid({MonitoringHostApi? monitoringApi})
    : _monitoringApi = monitoringApi ?? MonitoringHostApi();

  final MonitoringHostApi _monitoringApi;

  /// Registers this class as the default instance of
  /// [NetworkAnalyzerPlatform].
  ///
  /// Invoked by the Flutter tool through the `dartPluginClass` entry in
  /// the pubspec; never called manually.
  static void registerWith() {
    NetworkAnalyzerPlatform.instance = NetworkAnalyzerAndroid();
  }

  @override
  Future<Result<SessionData, Failure>> startMonitoring(
    MonitorInterface target,
  ) async {
    try {
      final SessionDataMessage message = await _monitoringApi.startSession(
        toConfigMessage(target),
      );
      return Result<SessionData, Failure>.success(toSessionData(message));
    } on PlatformException catch (error) {
      return Result<SessionData, Failure>.failure(
        mapPlatformException(error, 'startMonitoring'),
      );
    }
  }

  @override
  Future<Result<void, Failure>> stopMonitoring() async {
    try {
      await _monitoringApi.stopSession();
      return const Result<void, Failure>.success(null);
    } on PlatformException catch (error) {
      return Result<void, Failure>.failure(
        mapPlatformException(error, 'stopMonitoring'),
      );
    }
  }

  @override
  Future<Result<SessionData, Failure>> currentSession() async {
    try {
      final SessionDataMessage? message = await _monitoringApi.currentSession();
      if (message == null) {
        return const Result<SessionData, Failure>.failure(
          NoActiveSessionFailure(
            message: 'No monitoring session is running.',
          ),
        );
      }
      return Result<SessionData, Failure>.success(toSessionData(message));
    } on PlatformException catch (error) {
      return Result<SessionData, Failure>.failure(
        mapPlatformException(error, 'currentSession'),
      );
    }
  }

  @override
  Stream<MonitorSignal> monitorSignals() =>
      streamMonitorSignals().map(toMonitorSignal);
}
