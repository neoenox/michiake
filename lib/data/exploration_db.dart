import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:h3_flutter/h3_flutter.dart';

import '../core/geo_sample.dart';

class HistoryDay {
  const HistoryDay({
    required this.dayKey,
    required this.distanceMeters,
    required this.pointCount,
    required this.newCellCount,
    required this.newAreaM2,
  });

  final String dayKey;
  final double distanceMeters;
  final int pointCount;
  final int newCellCount;
  final double newAreaM2;
}

class ExplorationDb {
  ExplorationDb({this.pathOverride});

  final String? pathOverride;
  Database? _database;
  H3? _h3;
  H3 get _h3Api => _h3 ??= const H3Factory().load();

  Future<Database> get database async {
    if (_database case final db?) return db;
    final path =
        pathOverride ?? p.join(await getDatabasesPath(), 'michiake.db');
    return _database = await openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE tracking_state (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              revision INTEGER NOT NULL
            )
          ''');
          await db.insert('tracking_state', {'id': 1, 'revision': 0});
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE explored_cells ADD COLUMN center_lat REAL',
          );
          await db.execute(
            'ALTER TABLE explored_cells ADD COLUMN center_lon REAL',
          );
          final rows = await db.query('explored_cells', columns: ['cell_id']);
          final batch = db.batch();
          for (final row in rows) {
            final id = row['cell_id']! as String;
            if (id.length < 15) continue;
            try {
              final center = _h3Api.cellToGeo(BigInt.parse(id, radix: 16));
              batch.update(
                'explored_cells',
                {'center_lat': center.lat, 'center_lon': center.lon},
                where: 'cell_id = ?',
                whereArgs: [id],
              );
            } on FormatException {
              continue;
            }
          }
          await batch.commit(noResult: true);
          await db.execute(
            'CREATE INDEX explored_center_idx ON explored_cells(center_lat, center_lon)',
          );
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE explored_cells (
            cell_id TEXT PRIMARY KEY,
            area_m2 REAL NOT NULL,
            first_seen_at INTEGER NOT NULL,
            first_seen_day TEXT NOT NULL,
            center_lat REAL,
            center_lon REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE cell_days (
            cell_id TEXT NOT NULL,
            day_key TEXT NOT NULL,
            first_seen_at INTEGER NOT NULL,
            PRIMARY KEY (cell_id, day_key)
          )
        ''');
        await db.execute('''
          CREATE TABLE track_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL NOT NULL,
            altitude REAL NOT NULL,
            speed REAL NOT NULL,
            recorded_at INTEGER NOT NULL,
            day_key TEXT NOT NULL,
            segment_distance_m REAL NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX track_day_idx ON track_points(day_key)');
        await db.execute('CREATE INDEX cell_day_idx ON cell_days(day_key)');
        await db.execute(
          'CREATE INDEX explored_center_idx ON explored_cells(center_lat, center_lon)',
        );
        await db.execute('''
          CREATE TABLE tracking_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            revision INTEGER NOT NULL
          )
        ''');
        await db.insert('tracking_state', {'id': 1, 'revision': 0});
      },
    );
  }

  Future<bool> recordSample({
    required GeoSample sample,
    required double segmentDistanceMeters,
    required Map<String, double> cells,
    required int expectedRevision,
  }) async {
    final db = await database;
    final day = dayKey(sample.timestamp);
    final stamp = sample.timestamp.millisecondsSinceEpoch;
    var recorded = false;
    await db.transaction((txn) async {
      final revision = Sqflite.firstIntValue(
        await txn.query(
          'tracking_state',
          columns: ['revision'],
          where: 'id = 1',
        ),
      );
      if (revision != expectedRevision) return;
      await txn.insert('track_points', {
        'latitude': sample.latitude,
        'longitude': sample.longitude,
        'accuracy': sample.accuracy,
        'altitude': sample.altitude,
        'speed': sample.speed,
        'recorded_at': stamp,
        'day_key': day,
        'segment_distance_m': segmentDistanceMeters,
      });
      for (final entry in cells.entries) {
        final center = _cellCenter(entry.key, sample);
        await txn.insert('cell_days', {
          'cell_id': entry.key,
          'day_key': day,
          'first_seen_at': stamp,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('explored_cells', {
          'cell_id': entry.key,
          'area_m2': entry.value,
          'first_seen_at': stamp,
          'first_seen_day': day,
          'center_lat': center.lat,
          'center_lon': center.lon,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      recorded = true;
    });
    return recorded;
  }

  Future<int> get trackingRevision async =>
      Sqflite.firstIntValue(
        await (await database).query(
          'tracking_state',
          columns: ['revision'],
          where: 'id = 1',
        ),
      ) ??
      0;

  Future<GeoSample?> latestSample() async {
    final rows = await (await database).query(
      'track_points',
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GeoSample(
      latitude: row['latitude']! as double,
      longitude: row['longitude']! as double,
      accuracy: row['accuracy']! as double,
      altitude: row['altitude']! as double,
      speed: row['speed']! as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row['recorded_at']! as int,
      ),
    );
  }

  Future<List<String>> loadExploredCells() async =>
      (await (await database).query(
        'explored_cells',
        columns: ['cell_id'],
      )).map((row) => row['cell_id']! as String).toList(growable: false);

  Future<List<String>> loadExploredCellsInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final db = await database;
    // Resolution-13 H3 cells can extend about 15 m from their centers.
    // Pad by 25 m to include cells whose polygons overlap the viewport.
    const paddingMeters = 25.0;
    const metersPerLatitudeDegree = 111320.0;
    final minLat = (south - paddingMeters / metersPerLatitudeDegree)
        .clamp(-90.0, 90.0);
    final maxLat = (north + paddingMeters / metersPerLatitudeDegree)
        .clamp(-90.0, 90.0);
    final longitudeScale =
        metersPerLatitudeDegree * math.cos(
          (south.abs() > north.abs() ? south.abs() : north.abs()) * math.pi / 180,
        ).abs();
    final longitudePadding = longitudeScale < 1
        ? 180.0
        : paddingMeters / longitudeScale;
    final minLon = _wrapLongitude(west - longitudePadding);
    final maxLon = _wrapLongitude(east + longitudePadding);
    final longitudeFilter = minLon <= maxLon
        ? 'center_lon BETWEEN ? AND ?'
        : '(center_lon >= ? OR center_lon <= ?)';
    final rows = await db.rawQuery(
      '''
      SELECT cell_id FROM explored_cells
      WHERE center_lat BETWEEN ? AND ? AND $longitudeFilter
        AND center_lat IS NOT NULL AND center_lon IS NOT NULL
      ''',
      [minLat, maxLat, minLon, maxLon],
    );
    return rows.map((row) => row['cell_id']! as String).toList(growable: false);
  }

  double _wrapLongitude(double longitude) {
    final wrapped = (longitude + 180) % 360;
    return (wrapped < 0 ? wrapped + 360 : wrapped) - 180;
  }

  ({double lat, double lon}) _cellCenter(String cellId, GeoSample fallback) {
    if (cellId.length < 15) {
      return (lat: fallback.latitude, lon: fallback.longitude);
    }
    try {
      final center = _h3Api.cellToGeo(BigInt.parse(cellId, radix: 16));
      return (lat: center.lat, lon: center.lon);
    } on FormatException {
      return (lat: fallback.latitude, lon: fallback.longitude);
    }
  }

  Future<List<HistoryDay>> history() async {
    final rows = await (await database).rawQuery('''
      SELECT days.day_key,
        COALESCE(points.distance_m, 0) AS distance_m,
        COALESCE(points.point_count, 0) AS point_count,
        COALESCE(cells.cell_count, 0) AS cell_count,
        COALESCE(cells.area_m2, 0) AS area_m2
      FROM (
        SELECT day_key FROM track_points UNION SELECT day_key FROM cell_days
      ) days
      LEFT JOIN (
        SELECT day_key, SUM(segment_distance_m) AS distance_m, COUNT(*) AS point_count
        FROM track_points GROUP BY day_key
      ) points ON points.day_key = days.day_key
      LEFT JOIN (
        SELECT first_seen_day AS day_key, COUNT(*) AS cell_count,
          SUM(area_m2) AS area_m2 FROM explored_cells GROUP BY first_seen_day
      ) cells ON cells.day_key = days.day_key
      ORDER BY days.day_key DESC
    ''');
    return rows
        .map(
          (row) => HistoryDay(
            dayKey: row['day_key']! as String,
            distanceMeters: (row['distance_m']! as num).toDouble(),
            pointCount: row['point_count']! as int,
            newCellCount: row['cell_count']! as int,
            newAreaM2: (row['area_m2']! as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, num>> totalsFor(DateTime date) async {
    final db = await database;
    final day = dayKey(date);
    final rows = await db.rawQuery(
      '''
      SELECT
        (SELECT COALESCE(SUM(segment_distance_m), 0) FROM track_points WHERE day_key = ?) AS distance_m,
        (SELECT COUNT(*) FROM track_points WHERE day_key = ?) AS point_count,
        (SELECT COUNT(*) FROM explored_cells WHERE first_seen_day = ?) AS new_cells,
        (SELECT COALESCE(SUM(area_m2), 0) FROM explored_cells WHERE first_seen_day = ?) AS new_area_m2,
        (SELECT COUNT(*) FROM explored_cells) AS total_cells,
        (SELECT COALESCE(SUM(area_m2), 0) FROM explored_cells) AS total_area_m2
    ''',
      [day, day, day, day],
    );
    return rows.first.map((key, value) => MapEntry(key, value as num));
  }

  Future<void> undoDay(String day) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cell_days', where: 'day_key = ?', whereArgs: [day]);
      await txn.delete('track_points', where: 'day_key = ?', whereArgs: [day]);
      await txn.rawDelete('''
        DELETE FROM explored_cells WHERE NOT EXISTS (
          SELECT 1 FROM cell_days WHERE cell_days.cell_id = explored_cells.cell_id
        )
      ''');
      await txn.rawUpdate('''
        UPDATE explored_cells
        SET first_seen_at = (
          SELECT MIN(first_seen_at) FROM cell_days WHERE cell_id = explored_cells.cell_id
        ), first_seen_day = (
          SELECT day_key FROM cell_days WHERE cell_id = explored_cells.cell_id
          ORDER BY first_seen_at LIMIT 1
        )
      ''');
      await txn.rawUpdate(
        'UPDATE tracking_state SET revision = revision + 1 WHERE id = 1',
      );
    });
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cell_days');
      await txn.delete('explored_cells');
      await txn.delete('track_points');
    });
  }

  Future<int> get trackPointCount async =>
      Sqflite.firstIntValue(
        await (await database).rawQuery('SELECT COUNT(*) FROM track_points'),
      ) ??
      0;

  Future<int> get exploredCellCount async =>
      Sqflite.firstIntValue(
        await (await database).rawQuery('SELECT COUNT(*) FROM explored_cells'),
      ) ??
      0;

  static String dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
