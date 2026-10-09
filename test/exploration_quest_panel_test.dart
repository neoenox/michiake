import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/widgets/exploration_quest_panel.dart';

void main() {
  testWidgets('quest details can be folded and reopened', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorationQuestPanel(
            quest: null,
            collectedCardCount: 0,
            onChooseQuest: () {},
            onOpenCollection: () {},
          ),
        ),
      ),
    );
    expect(find.text('依頼を選ぶ'), findsOneWidget);
    await tester.tap(find.byTooltip('探索依頼を折りたたむ'));
    await tester.pumpAndSettle();
    expect(find.text('依頼を選ぶ'), findsNothing);
    await tester.tap(find.byTooltip('探索依頼を開く'));
    await tester.pumpAndSettle();
    expect(find.text('依頼を選ぶ'), findsOneWidget);
  });

  testWidgets('quest panel can be dismissed without removing its quest', (tester) async {
    var dismissCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplorationQuestPanel(
            quest: null,
            collectedCardCount: 0,
            onChooseQuest: () {},
            onOpenCollection: () {},
            onDismiss: () => dismissCount++,
          ),
        ),
      ),
    );
    expect(find.text('地図から隠す'), findsOneWidget);
    await tester.tap(find.text('地図から隠す'));
    expect(dismissCount, 1);
    // The parent owns visibility. This component only requests dismissal.
    await tester.tap(find.byTooltip('探索依頼を折りたたむ'));
    await tester.pumpAndSettle();
    expect(find.text('地図から隠す'), findsNothing);
  });
}
