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

GeoSample _sample(double latitude, double longitude) => GeoSample(
  latitude: latitude,
  longitude: longitude,
  accuracy: 5,
  altitude: 10,
  speed: 1,
  timestamp: DateTime.utc(2026),
);
