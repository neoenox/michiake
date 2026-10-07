import 'dart:io';

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

  test(
    'reopening retains recorded history, explored map cells and rewards',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'michiake-restart-',
      );
      final path = '${directory.path}/michiake.db';
      final sample = GeoSample(
        latitude: 35,
        longitude: 139,
        accuracy: 5,
        altitude: 0,
        speed: 1,
        timestamp: DateTime(2026, 10, 4, 9),
      );
      final first = ExplorationDb(pathOverride: path);
      try {
        expect(
          await first.recordSample(
            sample: sample,
            segmentDistanceMeters: 100,
            cells: {'saved-cell': 45},
            expectedRevision: await first.trackingRevision,
          ),
          isTrue,
        );
        await first.startDailyQuest(dayKey: '2026-10-04', targetNewCells: 1);
        final completed = await first.updateDailyQuestProgress(
          dayKey: '2026-10-04',
          newCellsToday: 1,
        );
        final totals = await first.totalsFor(sample.timestamp);
        await (await first.database).close();

        final reopened = ExplorationDb(pathOverride: path);
        try {
          await reopened.beginNewTrackingSegment();
          expect(await reopened.totalsFor(sample.timestamp), totals);
          expect((await reopened.history()).single.pointCount, 1);
          expect((await reopened.latestSample())!.latitude, sample.latitude);
          expect(
            await reopened.loadExploredCellsInBounds(
              south: 34.99,
              west: 138.99,
              north: 35.01,
              east: 139.01,
            ),
            ['saved-cell'],
          );
          expect(await reopened.earnedDiscoveryCardIds, {completed!.cardId});
        } finally {
          await (await reopened.database).close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
