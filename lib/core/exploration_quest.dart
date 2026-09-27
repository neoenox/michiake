class ExplorationQuestOption {
  const ExplorationQuestOption({
    required this.targetNewCells,
    required this.title,
    required this.description,
  });

  final int targetNewCells;
  final String title;
  final String description;
}

const explorationQuestOptions = [
  ExplorationQuestOption(
    targetNewCells: 20,
    title: 'ゆっくり',
    description: '新しい場所を20セルひらく',
  ),
  ExplorationQuestOption(
    targetNewCells: 60,
    title: 'いつもどおり',
    description: '新しい場所を60セルひらく',
  ),
  ExplorationQuestOption(
    targetNewCells: 150,
    title: 'たっぷり',
    description: '新しい場所を150セルひらく',
  ),
];

class DiscoveryCardDefinition {
  const DiscoveryCardDefinition({
    required this.id,
    required this.title,
    required this.description,
  });

  final int id;
  final String title;
  final String description;
}

const discoveryCardCatalog = [
  DiscoveryCardDefinition(id: 1, title: '朝露の葉', description: '新しい道に、朝の光がこぼれた。'),
  DiscoveryCardDefinition(
    id: 2,
    title: '風の鈴',
    description: 'まだ知らない風景が、そっと鳴った。',
  ),
  DiscoveryCardDefinition(
    id: 3,
    title: '小さな灯台',
    description: '歩いた先に、小さな目印がともった。',
  ),
  DiscoveryCardDefinition(
    id: 4,
    title: '石畳のかけら',
    description: '今日の一歩が、地図のかけらになった。',
  ),
  DiscoveryCardDefinition(
    id: 5,
    title: '雲の切れ間',
    description: '霧の向こうに、新しい空が見えた。',
  ),
  DiscoveryCardDefinition(
    id: 6,
    title: 'どんぐり便',
    description: '道ばたから、森の便りが届いた。',
  ),
  DiscoveryCardDefinition(id: 7, title: '星砂', description: 'いつもの地図に、星の粒がひとつ。'),
  DiscoveryCardDefinition(
    id: 8,
    title: '青い羽根',
    description: '知らない道が、遠くまで続いている。',
  ),
  DiscoveryCardDefinition(
    id: 9,
    title: '旅する鉢植え',
    description: '新しい景色で、小さな芽が育った。',
  ),
  DiscoveryCardDefinition(
    id: 10,
    title: '月の窓',
    description: '今日ひらいた場所に、月明かりが差した。',
  ),
  DiscoveryCardDefinition(
    id: 11,
    title: '潮騒の小瓶',
    description: '歩いた道から、遠い波の音が届いた。',
  ),
  DiscoveryCardDefinition(
    id: 12,
    title: '道しるべの花',
    description: '地図いっぱいに、花の道がつながった。',
  ),
];

DiscoveryCardDefinition? discoveryCardForId(int? id) {
  for (final card in discoveryCardCatalog) {
    if (card.id == id) return card;
  }
  return null;
}
