import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:michiake/core/geo_sample.dart';
import 'package:michiake/data/exploration_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('committed exploration survives database close and reopen',
      (tester) async {
    final path = p.join(
      await getDatabasesPath(),
      'issue-26-durable-reopen-regression.db',
    );
    await deleteDatabase(path);

    final sample = GeoSample(
      latitude: 35.681236,
      longitude: 139.767125,
      accuracy: 5,
      altitude: 0,
      speed: 1,
      timestamp: DateTime(2026, 10, 9, 10),
    );

    try {
      final first = ExplorationDb(pathOverride: path);
      final saved = await first.recordSample(
        sample: sample,
        segmentDistanceMeters: 0,
        cells: const {},
        expectedRevision: await first.trackingRevision,
      );
      expect(saved, isTrue);
      expect(await first.trackPointCount, 1);
      await (await first.database).close();

      // A fresh wrapper must open the on-disk DB, not an in-memory cache.
      final reopened = ExplorationDb(pathOverride: path);
      expect(await reopened.trackPointCount, 1);
      expect(
        (await reopened.latestSample())?.timestamp.millisecondsSinceEpoch,
        sample.timestamp.millisecondsSinceEpoch,
      );
      expect(
        (await reopened.totalsFor(sample.timestamp))['point_count'],
        1,
      );
      await reopened.beginNewTrackingSegment();
      expect(await reopened.trackPointCount, 1);
      await (await reopened.database).close();
    } finally {
      await deleteDatabase(path);
    }
  });
}
