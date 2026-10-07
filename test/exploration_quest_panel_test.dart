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
}
