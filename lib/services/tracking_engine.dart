import '../core/exploration_coverage.dart';
import '../core/geo_sample.dart';
import '../core/tracking_policy.dart';
import '../data/exploration_db.dart';

class TrackingEngine {
  TrackingEngine(
    this._db, {
    this._policy = const TrackingPolicy(),
    ExplorationCoverage? coverage,
  }) : _coverage = coverage ?? ExplorationCoverage();

  final ExplorationDb _db;
  final TrackingPolicy _policy;
  final ExplorationCoverage _coverage;
  GeoSample? _previous;

  Future<void> initialize() async => _previous = await _db.latestSample();

  Future<bool> accept(GeoSample sample) async {
    if (!_policy.isUsablePoint(sample) || _policy.isLikelyAircraft(sample)) {
      _previous = null;
      return false;
    }
    final previous = _previous;
    final decision = previous == null
        ? SegmentDecision.startNew
        : _policy.evaluate(previous, sample);
    if (decision == SegmentDecision.rejectAndBreak) {
      _previous = null;
      return false;
    }
    final distance = decision == SegmentDecision.connect
        ? TrackingPolicy.distanceMeters(
            previous!.latitude,
            previous.longitude,
            sample.latitude,
            sample.longitude,
          )
        : 0.0;
    final cells = _coverage.forSegment(
      decision == SegmentDecision.connect ? previous : null,
      sample,
    );
    await _db.recordSample(
      sample: sample,
      segmentDistanceMeters: distance,
      cells: cells,
    );
    _previous = sample;
    return true;
  }
}
