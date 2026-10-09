import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/settings/tracking_settings.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  test('quest panel visibility survives a new settings instance', () async {
    SharedPreferencesAsyncPlatform.instance = _MemoryPreferences();
    expect(await TrackingSettings().questPanelVisible, isTrue);

    await TrackingSettings().setQuestPanelVisible(false);
    expect(await TrackingSettings().questPanelVisible, isFalse);

    await TrackingSettings().setQuestPanelVisible(true);
    expect(await TrackingSettings().questPanelVisible, isTrue);
  });
}

base class _MemoryPreferences extends SharedPreferencesAsyncPlatform {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async =>
      values[key] as bool?;

  @override
  Future<void> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
