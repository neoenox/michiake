import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:michiake/settings/tracking_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quest panel visibility survives a new settings instance', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = TrackingSettings();
    expect(await settings.questPanelVisible, isTrue);

    await settings.setQuestPanelVisible(false);
    final reopened = TrackingSettings();
    expect(await reopened.questPanelVisible, isFalse);

    await reopened.setQuestPanelVisible(true);
    expect(await TrackingSettings().questPanelVisible, isTrue);
  });
}
