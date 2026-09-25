import '../core/exploration_coverage.dart';
import '../core/geo_sample.dart';
import '../core/tracking_policy.dart';
import '../data/exploration_db.dart';

class TrackingEngine {
  TrackingEngine(
    this._db, {
    this._policy = const TrackingPolicy(),
    CoverageProvider? coverage,
  }) : _coverage = coverage ?? ExplorationCoverage();

  final ExplorationDb _db;
  final TrackingPolicy _policy;
  final CoverageProvider _coverage;
  GeoSample? _previous;
  int _revision = 0;

  Future<void> initialize() async {
    _revision = await _db.trackingRevision;
    _previous = await _db.latestSample();
  }

  Future<void> accept(GeoSample sample, {required int queuedRevision}) async {
    final currentRevision = await _db.trackingRevision;
    if (currentRevision != queuedRevision) {
      _revision = currentRevision;
      _previous = null;
      return;
    }
    if (currentRevision != _revision) {
      _revision = currentRevision;
      _previous = null;
    }
    if (!_policy.isUsablePoint(sample) || _policy.isLikelyAircraft(sample)) {
      _previous = null;
      return;
    }
    final previous = _previous;
    final decision = previous == null
        ? SegmentDecision.startNew
        : _policy.evaluate(previous, sample);
    if (decision == SegmentDecision.rejectAndBreak) {
      _previous = null;
      return;
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
    final recorded = await _db.recordSample(
      sample: sample,
      segmentDistanceMeters: distance,
      cells: cells,
      expectedRevision: _revision,
    );
    if (recorded) {
      _previous = sample;
    } else {
      _revision = await _db.trackingRevision;
      _previous = null;
    }
  }
}
