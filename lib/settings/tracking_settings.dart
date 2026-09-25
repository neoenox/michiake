import 'package:shared_preferences/shared_preferences.dart';

class TrackingSettings {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static const _trackingErrorKey = 'tracking_latest_error';
  static const _locationStreamHealthyKey = 'location_stream_healthy';

  Future<bool> get onboardingCompleted async =>
      await _preferences.getBool('onboarding_completed') ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _preferences.setBool('onboarding_completed', value);

  Future<bool> get autoTrackingEnabled async =>
      await _preferences.getBool('auto_tracking_enabled') ?? true;

  Future<void> setAutoTrackingEnabled(bool value) =>
      _preferences.setBool('auto_tracking_enabled', value);

  Future<String?> get latestTrackingError =>
      _preferences.getString(_trackingErrorKey);

  Future<void> setLatestTrackingError(String? message) async {
    if (message == null) {
      await _preferences.remove(_trackingErrorKey);
    } else {
      await _preferences.setString(_trackingErrorKey, message);
    }
  }

  Future<bool> get locationStreamHealthy async =>
      await _preferences.getBool(_locationStreamHealthyKey) ?? false;

  Future<void> setLocationStreamHealthy(bool value) =>
      _preferences.setBool(_locationStreamHealthyKey, value);
}
