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
}

base class _EmptyPreferences extends SharedPreferencesAsyncPlatform {
  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async =>
      false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
