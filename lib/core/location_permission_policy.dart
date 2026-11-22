import 'package:fl_location/fl_location.dart';

/// Whether the current runtime grant is sufficient to start a location
/// foreground service while the app is visible.
bool canStartLocationTracking(LocationPermission permission) =>
    permission == LocationPermission.whileInUse ||
    permission == LocationPermission.always;
