import 'package:shared_preferences/shared_preferences.dart';

class TrackingSettings {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<bool> get questPanelExpanded async =>
      await _preferences.getBool('quest_panel_expanded') ?? true;

  Future<void> setQuestPanelExpanded(bool value) =>
      _preferences.setBool('quest_panel_expanded', value);

  Future<bool> get onboardingCompleted async =>
      await _preferences.getBool('onboarding_completed') ?? false;

  Future<void> setOnboardingCompleted(bool value) =>
      _preferences.setBool('onboarding_completed', value);

  Future<bool> get autoTrackingEnabled async =>
      await _preferences.getBool('auto_tracking_enabled') ?? true;

  Future<void> setAutoTrackingEnabled(bool value) =>
      _preferences.setBool('auto_tracking_enabled', value);
}
