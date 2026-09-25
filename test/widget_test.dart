import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/main.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  testWidgets('shows onboarding before tracking starts', (tester) async {
    SharedPreferencesAsyncPlatform.instance = _EmptyPreferences();
    await tester.pumpWidget(const MichiakeApp());
    await tester.pumpAndSettle();

    expect(find.text('通った道が、地図にひらく。'), findsOneWidget);
    expect(find.text('位置情報は端末内に保存'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('failed start stays on onboarding and can be retried', (
    tester,
  ) async {
    final preferences = _EmptyPreferences();
    SharedPreferencesAsyncPlatform.instance = preferences;
    var attempt = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          startTracking: () async => ++attempt > 1,
          homeBuilder: (_) => const Scaffold(body: Text('ホーム')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _startButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('自動探索を開始できませんでした。もう一度お試しください。'), findsOneWidget);
    expect(preferences.values['auto_tracking_enabled'], isFalse);
    expect(preferences.values['onboarding_completed'], isNull);
    expect(find.text('通った道が、地図にひらく。'), findsOneWidget);

    await _startButton(tester);
    await tester.pumpAndSettle();
    expect(find.text('ホーム'), findsOneWidget);
    expect(preferences.values['auto_tracking_enabled'], isTrue);
    expect(preferences.values['onboarding_completed'], isTrue);
  });

  testWidgets('successful start completes onboarding', (tester) async {
    final preferences = _EmptyPreferences();
    SharedPreferencesAsyncPlatform.instance = preferences;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          startTracking: () async => true,
          homeBuilder: (_) => const Scaffold(body: Text('ホーム')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _startButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('ホーム'), findsOneWidget);
    expect(preferences.values['auto_tracking_enabled'], isTrue);
    expect(preferences.values['onboarding_completed'], isTrue);
  });
}

Future<void> _startButton(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
  final button = find.text('内容を確認して探索を始める');
  await tester.tap(button);
}

base class _EmptyPreferences extends SharedPreferencesAsyncPlatform {
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
