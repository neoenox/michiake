import 'package:flutter/material.dart';

import '../core/exploration_quest.dart';

class DiscoveryCollectionScreen extends StatelessWidget {
  const DiscoveryCollectionScreen({required this.earnedCardIds, super.key});

  final Set<int> earnedCardIds;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('発見図鑑')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            earnedCardIds.length == discoveryCardCatalog.length
                ? '12種類の景色がそろいました。'
                : '探索依頼を達成すると、新しいカードが増えます。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: discoveryCardCatalog.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final card = discoveryCardCatalog[index];
              return _DiscoveryCardTile(
                card: card,
                isEarned: earnedCardIds.contains(card.id),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryCardTile extends StatelessWidget {
  const _DiscoveryCardTile({required this.card, required this.isEarned});

  final DiscoveryCardDefinition card;
  final bool isEarned;

  static const _icons = [
    Icons.spa,
    Icons.notifications,
    Icons.lightbulb_outline,
    Icons.terrain,
    Icons.cloud,
    Icons.mail_outline,
    Icons.star,
    Icons.flutter_dash,
    Icons.local_florist,
    Icons.nights_stay,
    Icons.water_drop,
    Icons.navigation,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isEarned
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Card(
      color: isEarned ? null : theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEarned ? _icons[card.id - 1] : Icons.help_outline,
              size: 42,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              isEarned ? card.title : '未発見',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isEarned ? card.description : '探索依頼で見つけよう',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
