import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'core/exploration_coverage.dart';
import 'core/tracking_health.dart';
import 'data/exploration_db.dart';
import 'services/tracking_service.dart';
import 'settings/tracking_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  TrackingService.initialize();
  runApp(const MichiakeApp());
}

class MichiakeApp extends StatelessWidget {
  const MichiakeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'みちあけ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff0e8b78),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
    home: const _StartupGate(),
  );
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _settings = TrackingSettings();
  bool? _ready;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await _settings.onboardingCompleted;
    if (done && await _settings.autoTrackingEnabled) {
      await _startIfAllowed();
    }
    if (mounted) setState(() => _ready = done);
  }

  Future<void> _startIfAllowed() async {
    try {
      final permission = await FlLocation.checkLocationPermission();
      if (permission == LocationPermission.always &&
          await FlLocation.isLocationServicesEnabled) {
        await TrackingService.start();
      }
    } catch (_) {
      // The diagnostics screen explains a missing permission or disabled GPS.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _ready! ? const MapHomeScreen() : const OnboardingScreen();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.startTracking, this.homeBuilder});

  final Future<bool> Function()? startTracking;
  final WidgetBuilder? homeBuilder;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _begin() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await TrackingSettings().setAutoTrackingEnabled(false);
      if (widget.startTracking == null &&
          !await FlLocation.isLocationServicesEnabled) {
        setState(() => _message = '端末の位置情報をオンにしてください。');
        return;
      }
      var permission = widget.startTracking == null
          ? await FlLocation.checkLocationPermission()
          : LocationPermission.always;
      if (widget.startTracking == null &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever)) {
        permission = await FlLocation.requestLocationPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _message = '位置情報の許可が必要です。設定から許可してください。');
        return;
      }
      if (widget.startTracking == null &&
          permission == LocationPermission.whileInUse) {
        permission = await FlLocation.requestLocationPermission();
      }
      if (permission != LocationPermission.always) {
        setState(() => _message = '画面を閉じた後も探索するには、アプリの位置情報を「常に許可」にしてください。');
        await AppSettings.openAppSettings(type: AppSettingsType.settings);
        return;
      }
      if (widget.startTracking == null) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final started =
          await (widget.startTracking?.call() ?? TrackingService.start());
      await TrackingSettings().setAutoTrackingEnabled(started);
      if (!started) {
        if (mounted) {
          setState(() => _message = '自動探索を開始できませんでした。もう一度お試しください。');
        }
        return;
      }
      await TrackingSettings().setOnboardingCompleted(true);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: widget.homeBuilder ?? (_) => const MapHomeScreen(),
          ),
        );
      }
    } catch (_) {
      try {
        await TrackingSettings().setAutoTrackingEnabled(false);
      } catch (_) {
        // Preserve the original onboarding error if preferences are unavailable.
      }
      if (mounted) {
        setState(() => _message = '設定を確認できませんでした。端末の位置情報設定を確認してください。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const SizedBox(height: 44),
              const Icon(Icons.explore, size: 76, color: Color(0xff0e8b78)),
              const SizedBox(height: 20),
              Text(
                '通った道が、地図にひらく。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _InfoCard(
                icon: Icons.route,
                title: '移動した場所を自動で記録',
                body: '徒歩から船まで、通った場所を約10m幅で探索済みにします。飛行機の移動は記録しません。',
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                icon: Icons.phone_android,
                title: '位置情報は端末内に保存',
                body: 'ログインも独自サーバーも使いません。地図の表示ではOpenFreeMapから地図データを読み込みます。',
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                icon: Icons.notifications_active_outlined,
                title: 'バックグラウンドでも探索',
                body: '画面を閉じても続けるため、位置情報の「常に許可」と探索中の通知を使います。あとから設定で停止できます。',
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: () => AppSettings.openAppSettings(
                    type: AppSettingsType.settings,
                  ),
                  child: const Text('端末の設定を開く'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _begin,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('内容を確認して探索を始める'),
              ),
              const SizedBox(height: 8),
              const Text(
                '移動中は画面を操作せず、安全な場所でご利用ください。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xff0e8b78)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen>
    with WidgetsBindingObserver {
  final _db = ExplorationDb();
  final _settings = TrackingSettings();
  final _coverage = ExplorationCoverage();
  MapLibreMapController? _map;
  Timer? _refreshTimer;
  bool _tracking = false;
  bool _locationStreamHealthy = false;
  DateTime? _lastSuccessfulSampleAt;
  String? _latestTrackingError;
  bool _sourceReady = false;
  bool _mapProblem = false;
  int? _fogCellCount;
  String? _fogViewportKey;
  bool _fogRefreshing = false;
  bool _fogRefreshQueued = false;
  bool _forceFogRefreshQueued = false;
  Map<String, num> _totals = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(forceFog: true);
  }

  Future<void> _refresh({bool forceFog = false}) async {
    var totals = _totals;
    String? databaseReadError;
    try {
      totals = await _db.totalsFor(DateTime.now());
    } catch (_) {
      databaseReadError = '探索データベースを読み込めません';
    }
    final running = await TrackingService.isRunning;
    DateTime? latestSavedAt;
    String? latestError = databaseReadError;
    try {
      latestSavedAt = (await _db.latestSample())?.timestamp;
      latestError ??= await _settings.latestTrackingError;
    } catch (_) {
      latestError = '記録状態を確認できません';
    }
    var streamHealthy = false;
    try {
      streamHealthy = await _settings.locationStreamHealthy;
    } catch (_) {
      latestError ??= '記録状態を確認できません';
    }
    if (!mounted) return;
    setState(() {
      _totals = totals;
      _tracking = running;
      _lastSuccessfulSampleAt = latestSavedAt;
      _latestTrackingError = latestError;
      _locationStreamHealthy = running && streamHealthy;
    });
    await _refreshFog(force: forceFog);
  }

  Future<void> _refreshFog({bool force = false}) async {
    final controller = _map;
    if (controller == null || !_sourceReady) return;
    if (_fogRefreshing) {
      _fogRefreshQueued = true;
      _forceFogRefreshQueued |= force;
      return;
    }
    _fogRefreshing = true;
    try {
      var refreshForce = force;
      do {
        _fogRefreshQueued = false;
        final queuedForce = _forceFogRefreshQueued;
        _forceFogRefreshQueued = false;
        final bounds = await controller.getVisibleRegion();
        final viewportKey =
            '${bounds.southwest.latitude.toStringAsFixed(4)},'
            '${bounds.southwest.longitude.toStringAsFixed(4)},'
            '${bounds.northeast.latitude.toStringAsFixed(4)},'
            '${bounds.northeast.longitude.toStringAsFixed(4)}';
        final cellCount = await _db.exploredCellCount;
        if (!refreshForce &&
            !queuedForce &&
            _fogCellCount == cellCount &&
            _fogViewportKey == viewportKey) {
          refreshForce = false;
          continue;
        }
        final cells = await _db.loadExploredCellsInBounds(
          south: bounds.southwest.latitude,
          west: bounds.southwest.longitude,
          north: bounds.northeast.latitude,
          east: bounds.northeast.longitude,
        );
        await controller.setGeoJsonSource('fog', _coverage.fogGeoJson(cells));
        _fogCellCount = cellCount;
        _fogViewportKey = viewportKey;
        refreshForce = false;
      } while (_fogRefreshQueued && mounted);
    } catch (_) {
      // The map can be recreating its style while returning from another screen.
    } finally {
      _fogRefreshing = false;
      if (_fogRefreshQueued && mounted) {
        final retryForce = _forceFogRefreshQueued;
        _fogRefreshQueued = false;
        _forceFogRefreshQueued = false;
        Future<void>.delayed(Duration.zero, () {
          if (mounted) _refreshFog(force: retryForce);
        });
      }
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _map = controller;
    try {
      final permission = await FlLocation.checkLocationPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final location = await FlLocation.getLocation();
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(location.latitude, location.longitude),
            15,
          ),
        );
      }
    } catch (_) {
      // Keep a useful default map view until location permission is available.
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _map;
    if (controller == null) return;
    try {
      await controller.addGeoJsonSource('fog', _coverage.fogGeoJson(const []));
      await controller.addLayer(
        'fog-layer',
        'fog',
        const FillLayerProperties(fillColor: '#101722', fillOpacity: 0.82),
      );
      _sourceReady = true;
      await _refreshFog(force: true);
      if (mounted) setState(() => _mapProblem = false);
    } catch (_) {
      if (mounted) setState(() => _mapProblem = true);
    }
  }

  Future<void> _toggleTracking(bool value) async {
    if (!value) {
      await _settings.setAutoTrackingEnabled(false);
      await TrackingService.stop();
      await _refresh();
      return;
    }
    try {
      if (!await FlLocation.isLocationServicesEnabled) {
        await AppSettings.openAppSettings(type: AppSettingsType.location);
        return;
      }
      var permission = await FlLocation.checkLocationPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await FlLocation.requestLocationPermission();
      }
      if (permission == LocationPermission.whileInUse) {
        permission = await FlLocation.requestLocationPermission();
      }
      if (permission != LocationPermission.always) {
        if (mounted) _showMessage('バックグラウンド探索には「常に許可」が必要です。設定から変更してください。');
        await AppSettings.openAppSettings(type: AppSettingsType.settings);
        return;
      }
      await FlutterForegroundTask.requestNotificationPermission();
      final started = await TrackingService.start();
      if (!started && mounted) _showMessage('自動探索を開始できませんでした。診断画面を確認してください。');
      await _settings.setAutoTrackingEnabled(started);
      await _refresh();
    } catch (_) {
      await _settings.setAutoTrackingEnabled(false);
      if (mounted) _showMessage('位置情報の設定を確認できませんでした。診断画面を確認してください。');
      await _refresh();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.explore, color: Color(0xff0e8b78)),
                const SizedBox(width: 8),
                Text(
                  'みちあけ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '履歴',
                  onPressed: () => _open(const HistoryScreen()),
                  icon: const Icon(Icons.calendar_month),
                ),
                IconButton(
                  tooltip: '診断',
                  onPressed: () => _open(const DiagnosticsScreen()),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MapLibreMap(
                  styleString: 'https://tiles.openfreemap.org/styles/liberty',
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(35.681236, 139.767125),
                    zoom: 11,
                  ),
                  myLocationEnabled: true,
                  compassEnabled: true,
                  attributionButtonPosition:
                      AttributionButtonPosition.bottomLeft,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  onCameraIdle: () => _refreshFog(force: true),
                ),
                if (_mapProblem)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: _HintBanner(text: '地図レイヤーを読み込めませんでした'),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !_tracking
                                ? Icons.pause_circle_outline
                                : _hasRecordingProblem
                                ? Icons.error_outline
                                : _lastSuccessfulSampleAt == null
                                ? Icons.hourglass_top
                                : Icons.radar,
                            color: !_tracking
                                ? Colors.black45
                                : _hasRecordingProblem
                                ? Colors.red.shade700
                                : const Color(0xff0e8b78),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trackingStatusLabel(
                                    serviceRunning: _tracking,
                                    locationStreamHealthy:
                                        _locationStreamHealthy,
                                    lastSuccessfulSampleAt:
                                        _lastSuccessfulSampleAt,
                                    latestError: _latestTrackingError,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '今日 ${_formatArea(_totals['new_area_m2'] ?? 0)} · ${_formatDistance(_totals['distance_m'] ?? 0)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(value: _tracking, onChanged: _toggleTracking),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '今日ひらいた面積',
                    value: _formatArea(_totals['new_area_m2'] ?? 0),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '累計探索面積',
                    value: _formatArea(_totals['total_area_m2'] ?? 0),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '今日の移動',
                    value: _formatDistance(_totals['distance_m'] ?? 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  bool get _hasRecordingProblem =>
      _latestTrackingError != null ||
      (!_locationStreamHealthy &&
          _lastSuccessfulSampleAt != null &&
          DateTime.now().difference(_lastSuccessfulSampleAt!) >
              trackingSampleStaleAfter);

  void _open(Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) => _refresh());
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = ExplorationDb();
  late Future<List<HistoryDay>> _history = _db.history();

  Future<void> _undo(String day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この日の探索を取り消しますか？'),
        content: Text('$day の移動記録と、この日に初めて探索した場所を取り消します。別の日にも通った場所は残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取り消す'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.undoDay(day);
    setState(() => _history = _db.history());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('日別履歴')),
    body: FutureBuilder<List<HistoryDay>>(
      future: _history,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('移動記録はまだありません'));
        }
        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final day = snapshot.data![index];
            return ListTile(
              title: Text(day.dayKey),
              subtitle: Text(
                '${_formatDistance(day.distanceMeters)} · 新規 ${_formatArea(day.newAreaM2)} · ${day.pointCount}地点',
              ),
              trailing: IconButton(
                tooltip: 'この日の探索を取り消す',
                icon: const Icon(Icons.undo),
                onPressed: () => _undo(day.dayKey),
              ),
            );
          },
        );
      },
    ),
  );
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _db = ExplorationDb();
  final _settings = TrackingSettings();
  bool? _service;
  bool? _enabled;
  bool? _gps;
  String _permission = '確認中';
  int _points = 0;
  int _cells = 0;
  DateTime? _lastSuccessfulSampleAt;
  String? _latestTrackingError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final latestSample = await _db.latestSample();
      final latestError = await _settings.latestTrackingError;
      final values = await Future.wait<Object>([
        TrackingService.isRunning,
        FlLocation.isLocationServicesEnabled,
        FlLocation.checkLocationPermission(),
        _db.trackPointCount,
        _db.exploredCellCount,
        _settings.autoTrackingEnabled,
      ]);
      if (!mounted) return;
      setState(() {
        _service = values[0] as bool;
        _gps = values[1] as bool;
        _permission = (values[2] as LocationPermission).name;
        _points = values[3] as int;
        _cells = values[4] as int;
        _enabled = values[5] as bool;
        _lastSuccessfulSampleAt = latestSample?.timestamp;
        _latestTrackingError = latestError;
      });
    } catch (_) {
      if (mounted) setState(() => _permission = '取得できません');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('診断')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DiagnosticRow(
          label: '自動探索設定',
          value: _enabled == null ? '確認中' : (_enabled! ? 'オン' : 'オフ'),
        ),
        _DiagnosticRow(
          label: '追跡サービス',
          value: _service == null ? '確認中' : (_service! ? '稼働中' : '停止中'),
        ),
        _DiagnosticRow(
          label: '最後に正常保存した位置',
          value: _lastSuccessfulSampleAt == null
              ? 'まだありません'
              : _lastSuccessfulSampleAt!.toLocal().toString().substring(0, 16),
        ),
        _DiagnosticRow(label: '直近の記録エラー', value: _latestTrackingError ?? 'なし'),
        _DiagnosticRow(
          label: '位置情報サービス',
          value: _gps == null ? '確認中' : (_gps! ? 'オン' : 'オフ'),
        ),
        _DiagnosticRow(label: '位置情報の許可', value: _permission),
        _DiagnosticRow(label: '保存した位置点', value: '$_points'),
        _DiagnosticRow(label: '探索済みセル', value: '$_cells'),
        const SizedBox(height: 12),
        const Text(
          '位置情報と探索記録はこの端末内に保存され、端末のクラウドバックアップや端末間コピーの対象にはなりません。アカウントや同期サーバーはありません。地図タイルの表示にはネット接続が必要です。',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('状態を再確認'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await AppSettings.openAppSettings(type: AppSettingsType.settings);
            await _load();
          },
          icon: const Icon(Icons.settings),
          label: const Text('端末の設定を開く'),
        ),
      ],
    ),
  );
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  );
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.orange.shade100,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
  );
}

String _formatArea(num value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(2)} km²'
    : value >= 1000
    ? '${(value / 1000).toStringAsFixed(1)}千㎡'
    : '${value.round()}㎡';

String _formatDistance(num value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(1)} km'
    : '${value.round()} m';
