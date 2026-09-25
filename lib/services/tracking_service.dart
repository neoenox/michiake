import 'dart:async';

import 'package:fl_location/fl_location.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/geo_sample.dart';
import '../data/exploration_db.dart';
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
  TrackingEngine? _engine;
  StreamSubscription<Location>? _subscription;
  Future<void> _writes = Future.value();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final engine = TrackingEngine(_db);
    await engine.initialize();
    _engine = engine;
    _subscription =
        FlLocation.getLocationStream(
          accuracy: LocationAccuracy.best,
          interval: 8000,
          distanceFilter: 5,
        ).listen((location) {
          // Start the revision read before this sample waits behind earlier writes.
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
          _writes = _writes
              .then((_) async {
                await _engine?.accept(
                  sample,
                  queuedRevision: await queuedRevision,
                );
              })
              .then((_) {})
              .catchError((Object _) {});
        });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _subscription?.cancel();
    await _writes;
  }
}
