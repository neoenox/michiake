import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/core/tracking_health.dart';

void main() {
  final now = DateTime(2026, 9, 25, 12);

  test('does not claim to be tracking when the service is stopped', () {
    expect(
      trackingStatusLabel(
        serviceRunning: false,
        locationStreamHealthy: false,
        lastSuccessfulSampleAt: now,
        latestError: null,
        now: now,
      ),
      '自動探索は停止中',
    );
  });

  test('reports service startup before the first sample is persisted', () {
    expect(
      trackingStatusLabel(
        serviceRunning: true,
        locationStreamHealthy: true,
        lastSuccessfulSampleAt: null,
        latestError: null,
        now: now,
      ),
      'サービス稼働中 · 記録を確認中',
    );
  });

  test('surfaces a location or persistence error while the service runs', () {
    expect(
      trackingStatusLabel(
        serviceRunning: true,
        locationStreamHealthy: true,
        lastSuccessfulSampleAt: now,
        latestError: '位置情報を保存できません',
        now: now,
      ),
      '記録エラー · 位置情報を保存できません',
    );
  });

  test('marks a recent successful database sample as recording', () {
    expect(
      trackingStatusLabel(
        serviceRunning: true,
        locationStreamHealthy: true,
        lastSuccessfulSampleAt: now.subtract(const Duration(seconds: 30)),
        latestError: null,
        now: now,
      ),
      '記録中 · 最終保存 11:59',
    );
  });

  test('does not report an error when diagnostic state is unavailable', () {
    expect(
      trackingStatusLabel(
        serviceRunning: true,
        locationStreamHealthy: null,
        lastSuccessfulSampleAt: now.subtract(const Duration(minutes: 30)),
        latestError: null,
        now: now,
      ),
      '記録状態を確認中 · 最終保存 11:30',
    );
  });

  test('warns when successful samples have gone stale', () {
    expect(
      trackingStatusLabel(
        serviceRunning: true,
        locationStreamHealthy: false,
        lastSuccessfulSampleAt: now.subtract(const Duration(minutes: 3)),
        latestError: null,
        now: now,
      ),
      '記録が止まっている可能性 · 最終保存 11:57',
    );
  });

  test('does not mark a healthy stationary stream as stale', () {
    expect(
      trackingStatusLabel(
        serviceRunning: true,
        locationStreamHealthy: true,
        lastSuccessfulSampleAt: now.subtract(const Duration(minutes: 30)),
        latestError: null,
        now: now,
      ),
      '記録中 · 最終保存 11:30',
    );
  });
}
