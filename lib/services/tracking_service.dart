import 'dart:async';

import 'package:fl_location/fl_location.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/geo_sample.dart';
import '../data/exploration_db.dart';
import 'tracking_engine.dart';

class TrackingService {
  static const _serviceId = 8201;
  static const _locationStreamHealthyKey =
      'michiake_location_stream_healthy';
  static const _latestTrackingErrorKey = 'michiake_latest_tracking_error';

  static Future<bool?> get locationStreamHealthy =>
      FlutterForegroundTask.getData<bool>(key: _locationStreamHealthyKey);

  static Future<String?> get latestTrackingError =>
      FlutterForegroundTask.getData<String>(key: _latestTrackingErrorKey);

  static Future<void> _setLocationStreamHealthy(bool value) async {
    await FlutterForegroundTask.saveData(
      key: _locationStreamHealthyKey,
      value: value,
    );
  }

  static Future<void> _setLatestTrackingError(String? message) async {
    if (message == null) {
      await FlutterForegroundTask.removeData(key: _latestTrackingErrorKey);
    } else {
      await FlutterForegroundTask.saveData(
        key: _latestTrackingErrorKey,
        value: message,
      );
    }
  }

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'michiake_tracking',
        channelName: '自動探索',
        channelDescription: '移動した場所を自動で記録しています',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  static Future<bool> start() async {
    if (await FlutterForegroundTask.isRunningService) return true;
    try {
      await _setLocationStreamHealthy(false);
      await _setLatestTrackingError(null);
    } catch (_) {
      // Diagnostics must never prevent the tracking service from starting.
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'みちあけ',
      notificationText: '移動した場所を自動探索しています',
      callback: trackingStartCallback,
    );
    return result is ServiceRequestSuccess;
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    try {
      await _setLocationStreamHealthy(false);
    } catch (_) {
      // The service is already stopped; stale diagnostics are non-critical.
    }
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}

@pragma('vm:entry-point')
void trackingStartCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

class _LocationTaskHandler extends TaskHandler {
  final ExplorationDb _db = ExplorationDb();
  TrackingEngine? _engine;
  StreamSubscription<Location>? _subscription;
  Future<void> _writes = Future.value();
  bool _destroying = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final engine = TrackingEngine(_db);
    try {
      await engine.initialize();
    } catch (_) {
      await _recordHealth(false);
      await _recordError('探索データを読み込めません');
      return;
    }
    _engine = engine;
    try {
      _subscription =
          FlLocation.getLocationStream(
            accuracy: LocationAccuracy.best,
            interval: 8000,
            distanceFilter: 5,
          ).listen(
            (location) {
              // Capture the revision before this sample waits behind pending writes.
              final queuedRevision = _db.trackingRevision;
              final sample = GeoSample(
                latitude: location.latitude,
                longitude: location.longitude,
                accuracy: location.accuracy,
                altitude: location.altitude,
                speed: location.speed,
                timestamp: location.timestamp,
                isMock: location.isMock,
              );
              _enqueueWrite(() async {
                await _recordSample(sample, await queuedRevision);
              });
            },
            onError: (Object _) {
              _enqueueWrite(() async {
                await _recordHealth(false);
                await _recordError('位置情報を受信できません');
              });
            },
            onDone: () {
              if (!_destroying) {
                _enqueueWrite(() async {
                  await _recordHealth(false);
                  await _recordError('位置情報の取得が停止しました');
                });
              }
            },
          );
      _enqueueWrite(() async {
        await _recordHealth(true);
        await _clearError();
      });
    } catch (_) {
      _enqueueWrite(() async {
        await _recordHealth(false);
        await _recordError('位置情報を受信できません');
      });
    }
  }

  void _enqueueWrite(Future<void> Function() action) {
    _writes = _writes.then((_) => action()).catchError((Object _) {});
  }

  Future<void> _recordSample(GeoSample sample, int queuedRevision) async {
    try {
      final saved =
          await _engine?.accept(sample, queuedRevision: queuedRevision) ?? false;
      if (saved) {
        await _recordHealth(true);
        await _clearError();
      }
    } catch (_) {
      await _recordError('位置情報を保存できません');
    }
  }

  Future<void> _recordHealth(bool healthy) async {
    try {
      await TrackingService._setLocationStreamHealthy(healthy);
    } catch (_) {
      // Diagnostic state must not interrupt location recording.
    }
  }

  Future<void> _clearError() async {
    try {
      await TrackingService._setLatestTrackingError(null);
    } catch (_) {
      // Diagnostic state must not interrupt location recording.
    }
  }

  Future<void> _recordError(String message) async {
    try {
      await TrackingService._setLatestTrackingError(message);
    } catch (_) {
      // Keep the foreground service alive even if diagnostics cannot be saved.
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroying = true;
    await _subscription?.cancel();
    await _writes;
  }
}
