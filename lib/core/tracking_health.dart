const trackingSampleStaleAfter = Duration(minutes: 2);

String trackingStatusLabel({
  required bool serviceRunning,
  required DateTime? lastSuccessfulSampleAt,
  required String? latestError,
  DateTime? now,
}) {
  if (!serviceRunning) return '自動探索は停止中';
  if (latestError != null) return '記録エラー · $latestError';
  if (lastSuccessfulSampleAt == null) return 'サービス稼働中 · 記録を確認中';

  final currentTime = now ?? DateTime.now();
  final age = currentTime.difference(lastSuccessfulSampleAt);
  final savedAt = lastSuccessfulSampleAt.toLocal();
  final timeLabel =
      '${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}';
  if (age > trackingSampleStaleAfter) {
    return '記録が止まっている可能性 · 最終保存 $timeLabel';
  }
  return '記録中 · 最終保存 $timeLabel';
}
