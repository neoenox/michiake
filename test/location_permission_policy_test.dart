import 'dart:io';

import 'package:fl_location/fl_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/core/location_permission_policy.dart';

void main() {
  test('accepts while-in-use and always location grants', () {
    expect(
      canStartLocationTracking(LocationPermission.whileInUse),
      isTrue,
    );
    expect(canStartLocationTracking(LocationPermission.always), isTrue);
  });

  test('rejects denied location grants', () {
    expect(canStartLocationTracking(LocationPermission.denied), isFalse);
    expect(
      canStartLocationTracking(LocationPermission.deniedForever),
      isFalse,
    );
  });

  test('Android requests foreground location but not background location', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
    );
    expect(manifest, contains('android:foregroundServiceType="location"'));
  });
}
