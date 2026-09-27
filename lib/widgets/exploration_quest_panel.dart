import 'package:flutter/material.dart';

import '../core/exploration_quest.dart';
import '../data/exploration_db.dart';

class ExplorationQuestPanel extends StatelessWidget {
  const ExplorationQuestPanel({
    required this.quest,
    required this.collectedCardCount,
    required this.onChooseQuest,
    required this.onOpenCollection,
    super.key,
  });

  final DailyQuestProgress? quest;
  final int collectedCardCount;
  final VoidCallback onChooseQuest;
  final VoidCallback onOpenCollection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = discoveryCardForId(quest?.cardId);
    final progress = quest == null
        ? 0.0
        : (quest!.newCellsToday / quest!.targetNewCells).clamp(0.0, 1.0);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xff0e8b78)),
                const SizedBox(width: 8),
                Text(
                  '今日の探索依頼',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '発見図鑑',
                  onPressed: onOpenCollection,
                  icon: const Icon(Icons.collections_bookmark_outlined),
                ),
                Text(
                  '$collectedCardCount/${discoveryCardCatalog.length}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            if (quest == null)
              Row(
                children: [
                  const Expanded(child: Text('目標を選んで、今日の地図をひらこう')),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: onChooseQuest,
                    child: const Text('依頼を選ぶ'),
                  ),
                ],
              )
            else ...[
              Text(
                quest!.isComplete
                    ? card == null
                          ? '依頼達成！図鑑のカードをすべて集めました'
                          : '依頼達成！「${card.title}」を見つけました'
                    : '${quest!.newCellsToday} / ${quest!.targetNewCells} セル',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: const Color(0xff0e8b78),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                quest!.isComplete
                    ? '自分のペースで、また次の景色を見つけよう'
                    : '新しい場所を${quest!.targetNewCells}セルひらく',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
