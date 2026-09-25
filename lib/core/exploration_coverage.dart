import 'dart:math' as math;

import 'package:h3_flutter/h3_flutter.dart';

import 'geo_sample.dart';
import 'tracking_policy.dart';

abstract interface class CoverageProvider {
  Map<String, double> forSegment(GeoSample? start, GeoSample end);
}

class ExplorationCoverage implements CoverageProvider {
  ExplorationCoverage({H3? h3}) : _h3 = h3 ?? const H3Factory().load();

  static const resolution = 13;
  static const sampleSpacingMeters = 5.0;
  final H3 _h3;

  @override
  Map<String, double> forSegment(GeoSample? start, GeoSample end) {
    final meters = start == null
        ? 0.0
        : TrackingPolicy.distanceMeters(
            start.latitude,
            start.longitude,
            end.latitude,
            end.longitude,
          );
    final steps = math.max(1, (meters / sampleSpacingMeters).ceil());
    final cells = <String, double>{};
    for (var step = 0; step <= steps; step++) {
      final ratio = step / steps;
      final lat = start == null
          ? end.latitude
          : start.latitude + (end.latitude - start.latitude) * ratio;
      final lon = start == null
          ? end.longitude
          : _interpolateLongitude(start.longitude, end.longitude, ratio);
      final center = _h3.geoToCell(GeoCoord(lon: lon, lat: lat), resolution);
      for (final cell in _h3.gridDisk(center, 1)) {
        cells[cell.toRadixString(16)] = _h3.cellArea(cell, H3Units.m);
      }
    }
    return cells;
  }

  static double _interpolateLongitude(double from, double to, double ratio) {
    var delta = to - from;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    var result = from + delta * ratio;
    if (result > 180) result -= 360;
    if (result < -180) result += 360;
    return result;
  }

  Map<String, dynamic> fogGeoJson(
    Iterable<String> ids, {
    double south = -85,
    double west = -180,
    double north = 85,
    double east = 180,
  }) {
    final indexes = <BigInt>[];
    for (final id in ids) {
      try {
        final cell = BigInt.parse(id, radix: 16);
        if (_h3.isValidCell(cell)) indexes.add(cell);
      } on FormatException {
        continue;
      }
    }
    // A world-sized polygon wraps at the antimeridian in MapLibre. Restrict
    // the fog exterior to the viewport plus a small margin so it is drawable.
    const viewportPaddingMeters = 100.0;
    const metersPerLatitudeDegree = 111320.0;
    final latitudePadding = viewportPaddingMeters / metersPerLatitudeDegree;
    final maxAbsLatitude = math.max(south.abs(), north.abs());
    final metersPerLongitudeDegree =
        metersPerLatitudeDegree * math.cos(maxAbsLatitude * math.pi / 180);
    final longitudePadding = metersPerLongitudeDegree.abs() < 1
        ? 180.0
        : viewportPaddingMeters / metersPerLongitudeDegree.abs();
    final minLatitude = (south - latitudePadding).clamp(-85.0, 85.0);
    final maxLatitude = (north + latitudePadding).clamp(-85.0, 85.0);
    final minLongitude = (west - longitudePadding).clamp(-180.0, 180.0);
    final maxLongitude = (east + longitudePadding).clamp(-180.0, 180.0);
    final viewportRing = <List<double>>[
      [minLongitude, minLatitude],
      [maxLongitude, minLatitude],
      [maxLongitude, maxLatitude],
      [minLongitude, maxLatitude],
      [minLongitude, minLatitude],
    ];
    final List<List<List<GeoCoord>>> polygons = indexes.isEmpty
        ? <List<List<GeoCoord>>>[]
        : _h3.cellsToMultiPolygon(indexes);
    final holes = <List<List<double>>>[];
    for (final polygon in polygons) {
      if (polygon.isEmpty) continue;
      final ring = polygon.first
          .map((point) => [point.lon, point.lat])
          .toList();
      if (ring.length >= 4) holes.add(_clockwise(ring));
    }
    final fogPolygons = <List<List<List<double>>>>[
      [viewportRing, ...holes],
    ];
    for (final polygon in polygons) {
      for (final inner in polygon.skip(1)) {
        final ring = inner.map((point) => [point.lon, point.lat]).toList();
        if (ring.length >= 4) fogPolygons.add([_counterClockwise(ring)]);
      }
    }
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {},
          'geometry': {'type': 'MultiPolygon', 'coordinates': fogPolygons},
        },
      ],
    };
  }

  static List<List<double>> _clockwise(List<List<double>> ring) =>
      _signedArea(ring) > 0 ? ring.reversed.toList() : ring;

  static List<List<double>> _counterClockwise(List<List<double>> ring) =>
      _signedArea(ring) < 0 ? ring.reversed.toList() : ring;

  static double _signedArea(List<List<double>> ring) {
    var area = 0.0;
    for (var i = 0; i < ring.length - 1; i++) {
      area += ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1];
    }
    return area / 2;
  }
}
