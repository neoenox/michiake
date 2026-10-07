import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:michiake/data/exploration_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> _writer(List<Object> args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    args[0] as RootIsolateToken,
  );
  final replies = args[2] as SendPort;
  final release = ReceivePort();
  final db = ExplorationDb(pathOverride: args[1] as String);
  try {
    final sql = await db.database;
    await sql.transaction((txn) async {
      await txn.insert('track_points', {
        'latitude': 35.0,
        'longitude': 139.0,
        'accuracy': 5.0,
        'altitude': 0.0,
        'speed': 1.0,
        'recorded_at': DateTime(2026, 10, 4, 9).millisecondsSinceEpoch,
        'day_key': '2026-10-04',
        'segment_distance_m': 100.0,
      });
      replies.send(release.sendPort);
      await release.first;
    });
    replies.send('committed');
  } catch (error) {
    replies.send('error: $error');
  } finally {
    await (await db.database).close();
    release.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'reopening UI does not roll back a background recording transaction',
    (tester) async {
      final path = p.join(await getDatabasesPath(), 'reopen-regression.db');
      await deleteDatabase(path);
      final seed = ExplorationDb(pathOverride: path);
      await (await seed.database).close();
      final replies = ReceivePort();
      final events = StreamIterator<Object?>(replies);
      final isolate = await Isolate.spawn(_writer, <Object>[
        RootIsolateToken.instance!,
        path,
        replies.sendPort,
      ]);
      Database? reopened;
      try {
        expect(
          await events.moveNext().timeout(const Duration(seconds: 15)),
          isTrue,
        );
        final release = events.current as SendPort;
        final ui = ExplorationDb(pathOverride: path);
        reopened = await ui.database.timeout(const Duration(seconds: 15));
        release.send(true);
        expect(
          await events.moveNext().timeout(const Duration(seconds: 15)),
          isTrue,
        );
        expect(events.current, 'committed');
        expect((await ui.history()).single.pointCount, 1);
        // Starting/stopping tracking uses this write. It must remain responsive
        // after the previous recording isolate closes its own connection.
        await ui.beginNewTrackingSegment().timeout(const Duration(seconds: 5));
        expect((await ui.history()).single.distanceMeters, 100);
      } finally {
        isolate.kill(priority: Isolate.immediate);
        await events.cancel();
        replies.close();
        await reopened?.close();
        await deleteDatabase(path);
      }
    },
  );
}
