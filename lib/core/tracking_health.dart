const trackingSampleStaleAfter = Duration(minutes: 2);

String trackingStatusLabel({
  required bool serviceRunning,
  required bool? locationStreamHealthy,
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
  if (locationStreamHealthy == null) {
    return '記録状態を確認中 · 最終保存 $timeLabel';
  }
  if (!locationStreamHealthy && age > trackingSampleStaleAfter) {
    return '記録が止まっている可能性 · 最終保存 $timeLabel';
  }
  return '記録中 · 最終保存 $timeLabel';
}
