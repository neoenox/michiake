import 'dart:async';

import 'package:fl_location/fl_location.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/geo_sample.dart';
import '../data/exploration_db.dart';
import '../settings/tracking_settings.dart';
import 'tracking_engine.dart';

class TrackingService {
  static const _serviceId = 8201;

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
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}

@pragma('vm:entry-point')
void trackingStartCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

class _LocationTaskHandler extends TaskHandler {
  final ExplorationDb _db = ExplorationDb();
  final TrackingSettings _settings = TrackingSettings();
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
      await _settings.setLocationStreamHealthy(false);
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
              final sample = GeoSample(
                latitude: location.latitude,
                longitude: location.longitude,
                accuracy: location.accuracy,
                altitude: location.altitude,
                speed: location.speed,
                timestamp: location.timestamp,
                isMock: location.isMock,
              );
              _writes = _writes.then((_) => _recordSample(sample));
            },
            onError: (Object _) {
              _writes = _writes.then((_) async {
                await _settings.setLocationStreamHealthy(false);
                await _recordError('位置情報を受信できません');
              });
            },
            onDone: () {
              if (!_destroying) {
                _writes = _writes.then((_) async {
                  await _settings.setLocationStreamHealthy(false);
                  await _recordError('位置情報の取得が停止しました');
                });
              }
            },
          );
      _writes = _writes.then((_) async {
        await _settings.setLocationStreamHealthy(true);
        await _settings.setLatestTrackingError(null);
      });
    } catch (_) {
      _writes = _writes.then((_) async {
        await _settings.setLocationStreamHealthy(false);
        await _recordError('位置情報を受信できません');
      });
    }
  }

  Future<void> _recordSample(GeoSample sample) async {
    try {
      final saved = await _engine?.accept(sample) ?? false;
      if (saved) {
        try {
          await _settings.setLatestTrackingError(null);
        } catch (_) {
          // A diagnostic preference must not interrupt location recording.
        }
      }
    } catch (_) {
      await _recordError('位置情報を保存できません');
    }
  }

  Future<void> _recordError(String message) async {
    try {
      await _settings.setLatestTrackingError(message);
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
