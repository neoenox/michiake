import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/core/exploration_coverage.dart';
import 'package:michiake/core/geo_sample.dart';
import 'package:michiake/data/exploration_db.dart';
import 'package:michiake/services/tracking_engine.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  test('undoing the latest day breaks the next recorded segment', () async {
    final db = ExplorationDb(pathOverride: inMemoryDatabasePath);
    final engine = TrackingEngine(db, coverage: _FakeCoverage());
    await engine.initialize();
    await engine.accept(_sample(35, 139, DateTime.utc(2026, 1, 1, 9)));

    await db.undoDay('2026-01-01');
    await engine.accept(_sample(35.01, 139.01, DateTime.utc(2026, 1, 1, 9, 1)));

    expect(await db.trackPointCount, 1);
    expect((await db.totalsFor(DateTime(2026, 1, 1)))['distance_m'], 0);
    expect(await db.exploredCellCount, greaterThan(0));
    await (await db.database).close();
  });

  test(
    'a queued write from before undo cannot reinsert deleted points',
    () async {
      final db = ExplorationDb(pathOverride: inMemoryDatabasePath);
      final oldRevision = await db.trackingRevision;
      await db.undoDay('2026-01-01');

      final recorded = await db.recordSample(
        sample: _sample(35, 139, DateTime.utc(2026, 1, 1, 9)),
        segmentDistanceMeters: 500,
        cells: {'stale': 50},
        expectedRevision: oldRevision,
      );

      expect(recorded, isFalse);
      expect(await db.trackPointCount, 0);
      expect(await db.exploredCellCount, 0);
      await (await db.database).close();
    },
  );
}

GeoSample _sample(double lat, double lon, DateTime time) => GeoSample(
  latitude: lat,
  longitude: lon,
  accuracy: 4,
  altitude: 12,
  speed: 0,
  timestamp: time,
);

class _FakeCoverage implements CoverageProvider {
  @override
  Map<String, double> forSegment(GeoSample? start, GeoSample end) => {
    '${end.latitude},${end.longitude}': 50,
  };
}
