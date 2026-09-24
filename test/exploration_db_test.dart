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
    );
    await db.recordSample(
      sample: _sample(DateTime(2026, 1, 2, 9)),
      segmentDistanceMeters: 120,
      cells: {'a': 40, 'b': 45},
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
}

GeoSample _sample(DateTime time) => GeoSample(
  latitude: 35,
  longitude: 139,
  accuracy: 4,
  altitude: 12,
  speed: 0,
  timestamp: time,
);
