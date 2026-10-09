import 'package:flutter/material.dart';

import '../core/exploration_quest.dart';
import '../data/exploration_db.dart';

class ExplorationQuestPanel extends StatefulWidget {
  const ExplorationQuestPanel({
    required this.quest,
    required this.collectedCardCount,
    required this.onChooseQuest,
    required this.onOpenCollection,
    this.initialExpanded = true,
    this.onExpandedChanged,
    this.onDismiss,
    super.key,
  });

  final DailyQuestProgress? quest;
  final int collectedCardCount;
  final VoidCallback onChooseQuest;
  final VoidCallback onOpenCollection;
  final bool initialExpanded;
  final ValueChanged<bool>? onExpandedChanged;
  final VoidCallback? onDismiss;

  @override
  State<ExplorationQuestPanel> createState() => _ExplorationQuestPanelState();
}

class _ExplorationQuestPanelState extends State<ExplorationQuestPanel> {
  late bool _expanded = widget.initialExpanded;

  @override
  void didUpdateWidget(ExplorationQuestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialExpanded != widget.initialExpanded) {
      _expanded = widget.initialExpanded;
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quest = widget.quest;
    final collectedCardCount = widget.collectedCardCount;
    final onChooseQuest = widget.onChooseQuest;
    final onOpenCollection = widget.onOpenCollection;
    final card = discoveryCardForId(quest?.cardId);
    final progress = quest == null
        ? 0.0
        : (quest.newCellsToday / quest.targetNewCells).clamp(0.0, 1.0);

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
                IconButton(
                  tooltip: _expanded ? '探索依頼を折りたたむ' : '探索依頼を開く',
                  onPressed: _toggleExpanded,
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            if (_expanded && quest == null)
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
            else if (_expanded && quest != null) ...[
              Text(
                quest.isComplete
                    ? card == null
                          ? '依頼達成！図鑑のカードをすべて集めました'
                          : '依頼達成！「${card.title}」を見つけました'
                    : '${quest.newCellsToday} / ${quest.targetNewCells} セル',
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
                quest.isComplete
                    ? '自分のペースで、また次の景色を見つけよう'
                    : '新しい場所を${quest.targetNewCells}セルひらく',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_expanded && widget.onDismiss != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text('地図から隠す'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
