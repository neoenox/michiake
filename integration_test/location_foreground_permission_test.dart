import 'package:fl_location/fl_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:michiake/core/location_permission_policy.dart';
import 'package:michiake/main.dart' as app;
import 'package:michiake/services/tracking_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'starts a location foreground service with while-in-use permission',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      final permission = await FlLocation.checkLocationPermission();
      expect(permission, LocationPermission.whileInUse);
      expect(canStartLocationTracking(permission), isTrue);
      expect(await FlLocation.isLocationServicesEnabled, isTrue);

      expect(await TrackingService.start(), isTrue);
      expect(await TrackingService.isRunning, isTrue);

      await Future<void>.delayed(const Duration(seconds: 3));
      expect(await TrackingService.isRunning, isTrue);

      await TrackingService.stop();
      expect(await TrackingService.isRunning, isFalse);
    },
  );
}
