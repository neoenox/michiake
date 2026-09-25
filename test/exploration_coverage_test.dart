import 'package:flutter_test/flutter_test.dart';
import 'package:michiake/core/exploration_coverage.dart';
import 'package:michiake/core/geo_sample.dart';
import 'package:h3_flutter/h3_flutter.dart';

void main() {
  test('covers an approximately ten metre corridor around a track segment', () {
    final coverage = ExplorationCoverage(h3: _FakeH3());
    final cells = coverage.forSegment(
      _sample(35.681, 139.767),
      _sample(35.6815, 139.767),
    );
    expect(cells.length, greaterThan(7));
    expect(cells.values.every((area) => area > 0), isTrue);
    expect(coverage.fogGeoJson(cells.keys)['type'], 'FeatureCollection');
  });

  test('fog exterior follows the viewport and explored areas are holes', () {
    final coverage = ExplorationCoverage(h3: _PolygonH3());
    final collection = coverage.fogGeoJson(
      ['1'],
      south: 35.679,
      west: 139.765,
      north: 35.683,
      east: 139.769,
    );
    final geometry = (collection['features'] as List).single['geometry'] as Map;
    final polygons = geometry['coordinates'] as List;
    final polygon = polygons.single as List;
    final outerRing = polygon.first as List;

    expect(geometry['type'], 'MultiPolygon');
    expect(polygon, hasLength(2));
    expect(outerRing.first[0], lessThan(139.765));
    expect(outerRing.first[1], lessThan(35.679));
    expect(outerRing[2][0], greaterThan(139.769));
    expect(outerRing[2][1], greaterThan(35.683));
  });
}

class _FakeH3 implements H3 {
  @override
  BigInt geoToCell(GeoCoord geoCoord, int resolution) =>
      BigInt.from((geoCoord.lat * 100000).round());

  @override
  List<BigInt> gridDisk(BigInt h3Index, int ringSize) =>
      List.generate(7, (index) => h3Index + BigInt.from(index));

  @override
  double cellArea(BigInt h3Index, H3Units unit) => 44;

  @override
  bool isValidCell(BigInt h3Index) => true;

  @override
  List<List<List<GeoCoord>>> cellsToMultiPolygon(List<BigInt> h3Indexes) => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PolygonH3 extends _FakeH3 {
  @override
  List<List<List<GeoCoord>>> cellsToMultiPolygon(List<BigInt> h3Indexes) => [
    [
      [
        GeoCoord(lon: 139.766, lat: 35.680),
        GeoCoord(lon: 139.768, lat: 35.680),
        GeoCoord(lon: 139.768, lat: 35.682),
        GeoCoord(lon: 139.766, lat: 35.682),
        GeoCoord(lon: 139.766, lat: 35.680),
      ],
    ],
  ];
}

GeoSample _sample(double latitude, double longitude) => GeoSample(
  latitude: latitude,
  longitude: longitude,
  accuracy: 5,
  altitude: 10,
  speed: 1,
  timestamp: DateTime.utc(2026),
);
