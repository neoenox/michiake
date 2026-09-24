import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/core/geo_sample.dart';
import 'package:michiake/core/tracking_policy.dart';

GeoSample point({
  double lat = 35,
  double lon = 139,
  double accuracy = 5,
  double altitude = 20,
  double speed = 1,
  int seconds = 0,
  bool mock = false,
}) => GeoSample(
  latitude: lat,
  longitude: lon,
  accuracy: accuracy,
  altitude: altitude,
  speed: speed,
  timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: seconds)),
  isMock: mock,
);

void main() {
  const policy = TrackingPolicy();

  test('rejects inaccurate, invalid, and mock points', () {
    expect(policy.isUsablePoint(point(accuracy: 31)), isFalse);
    expect(policy.isUsablePoint(point(lat: 91)), isFalse);
    expect(policy.isUsablePoint(point(mock: true)), isFalse);
    expect(policy.isUsablePoint(point()), isTrue);
  });

  test('bridges a reasonable GPS gap while retaining ordinary rail speed', () {
    expect(
      policy.evaluate(point(), point(lon: 139.01, seconds: 90)),
      SegmentDecision.connect,
    );
    expect(
      policy.evaluate(point(), point(speed: 95, altitude: 100, seconds: 1)),
      SegmentDecision.connect,
    );
  });

  test('breaks long gaps and excludes aircraft-like movement', () {
    expect(
      policy.evaluate(point(), point(lon: 139.001, seconds: 901)),
      SegmentDecision.startNew,
    );
    expect(
      policy.evaluate(point(), point(speed: 220, altitude: 9000)),
      SegmentDecision.rejectAndBreak,
    );
  });

  test('computes realistic great-circle distances', () {
    expect(TrackingPolicy.distanceMeters(0, 0, 0, 1), closeTo(111195, 5));
  });
}
