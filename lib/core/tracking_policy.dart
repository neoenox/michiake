import 'dart:math' as math;

import 'geo_sample.dart';

enum SegmentDecision { connect, startNew, rejectAndBreak }

class TrackingPolicy {
  const TrackingPolicy();
  static const maxAccuracyMeters = 30.0;
  static const maxBridgeDuration = Duration(minutes: 15);
  static const maxBridgeDistanceMeters = 20000.0;
  static const _earthRadiusMeters = 6371008.8;

  bool isUsablePoint(GeoSample point) =>
      !point.isMock &&
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.accuracy.isFinite &&
      point.altitude.isFinite &&
      point.speed.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180 &&
      point.accuracy > 0 &&
      point.accuracy <= maxAccuracyMeters;

  bool isLikelyAircraft(GeoSample point) =>
      (point.altitude >= 2000 && point.speed >= 120) || point.speed >= 180;

  SegmentDecision evaluate(GeoSample previous, GeoSample current) {
    if (isLikelyAircraft(current)) return SegmentDecision.rejectAndBreak;
    final elapsed = current.timestamp.difference(previous.timestamp);
    if (elapsed <= Duration.zero) return SegmentDecision.startNew;
    final distance = distanceMeters(previous.latitude, previous.longitude,
        current.latitude, current.longitude);
    final seconds = elapsed.inMilliseconds / 1000;
    if (distance / seconds >= 180) return SegmentDecision.rejectAndBreak;
    if (elapsed > maxBridgeDuration || distance > maxBridgeDistanceMeters) {
      return SegmentDecision.startNew;
    }
    return SegmentDecision.connect;
  }

  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
