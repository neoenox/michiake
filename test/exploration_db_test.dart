import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/core/geo_sample.dart';
import 'package:michiake/data/exploration_db.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  test('undoing a day preserves cells explored again on another day', () async {
    final db = ExplorationDb(pathOverride: inMemoryDatabasePath);
    await db.recordSample(
      sample: _sample(DateTime(2026, 1, 1, 9)),
      segmentDistanceMeters: 0,
      cells: {'a': 40},
      expectedRevision: await db.trackingRevision,
    );
    await db.recordSample(
      sample: _sample(DateTime(2026, 1, 2, 9)),
      segmentDistanceMeters: 120,
      cells: {'a': 40, 'b': 45},
      expectedRevision: await db.trackingRevision,
    );

    await db.undoDay('2026-01-01');
    expect(await db.exploredCellCount, 2);
    expect((await db.totalsFor(DateTime(2026, 1, 2)))['new_area_m2'], 85);
    expect((await db.history()).single.distanceMeters, 120);

    await db.undoDay('2026-01-02');
    expect(await db.exploredCellCount, 0);
    expect(await db.trackPointCount, 0);
    await (await db.database).close();
  });

  test('viewport query includes cell centers just outside visible bounds', () async {
    final db = ExplorationDb(pathOverride: inMemoryDatabasePath);
    final sql = await db.database;
    await sql.insert('explored_cells', {
      'cell_id': 'overlap',
      'area_m2': 45,
      'first_seen_at': 1,
      'first_seen_day': '2026-01-01',
      'center_lat': 34.9999,
      'center_lon': 139.0,
    });

    final visible = await db.loadExploredCellsInBounds(
      south: 35.0,
      west: 139.0,
      north: 35.001,
      east: 139.001,
    );

    expect(visible, contains('overlap'));
    await sql.close();
  });

  test('viewport padding wraps across the antimeridian', () async {
    final db = ExplorationDb(pathOverride: inMemoryDatabasePath);
    final sql = await db.database;
    await sql.insert('explored_cells', {
      'cell_id': 'dateline',
      'area_m2': 45,
      'first_seen_at': 1,
      'first_seen_day': '2026-01-01',
      'center_lat': 0.0,
      'center_lon': -179.9999,
    });

    final visible = await db.loadExploredCellsInBounds(
      south: -0.001,
      west: 179.9999,
      north: 0.001,
      east: -179.9999,
    );

    expect(visible, contains('dateline'));
    await sql.close();
  });

  test(
    'viewport query filters a large cell history before geometry work',
    () async {
      final db = ExplorationDb(pathOverride: inMemoryDatabasePath);
      final sql = await db.database;
      await sql.transaction((txn) async {
        final batch = txn.batch();
        for (var index = 0; index < 10000; index++) {
          final lat = 30 + index / 1000;
          batch.insert('explored_cells', {
            'cell_id': index.toRadixString(16),
            'area_m2': 45,
            'first_seen_at': index,
            'first_seen_day': '2026-01-01',
            'center_lat': lat,
            'center_lon': 139.0,
          });
        }
        await batch.commit(noResult: true);
      });

      final watch = Stopwatch()..start();
      final visible = await db.loadExploredCellsInBounds(
        south: 34.99,
        west: 138.99,
        north: 35.009,
        east: 139.01,
      );
      watch.stop();

      expect(visible.length, 20);
      expect(visible.length, lessThan(10000 ~/ 100));
      // Keep a local measurement available when diagnosing this query.
      // ignore: avoid_print
      print(
        'Viewport query: 10,000 cells -> ${visible.length} in ${watch.elapsedMilliseconds}ms',
      );
      await sql.close();
    },
  );
}

GeoSample _sample(DateTime time) => GeoSample(
  latitude: 35,
  longitude: 139,
  accuracy: 4,
  altitude: 12,
  speed: 0,
  timestamp: time,
);
