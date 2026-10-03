/// The classified state for a single processed camera frame.
///
/// This is intentionally a small, closed set driven by heuristic thresholds
/// (see AttentionClassifier) rather than a trained model — see the Week 1/2
/// technical evidence doc for the heuristic-first rationale.
enum AttentionState {
  /// Eyes open, head roughly forward — normal working state.
  focused,

  /// Sustained eye closure / slow blink pattern consistent with fatigue.
  drowsy,

  /// Head turned/tilted away from the screen beyond threshold.
  distracted,

  /// A face was detected but landmark quality was too low to classify
  /// confidently (e.g. partial occlusion, extreme angle, poor light).
  uncertain,

  /// No face detected in the frame at all (user stepped away, camera
  /// blocked, etc). This is a distinct state from `uncertain` because it
  /// drives different fallback behavior (see AttentionAggregator).
  noFace,
}

/// A single timestamped classification result, with the raw signal values
/// that produced it. Kept lightweight since these accumulate every frame.
class AttentionReading {
  final DateTime timestamp;
  final AttentionState state;
  final double? eyeAspectRatio;
  final double? headYawDeg;

  const AttentionReading({
    required this.timestamp,
    required this.state,
    this.eyeAspectRatio,
    this.headYawDeg,
  });

  @override
  String toString() =>
      'AttentionReading(${timestamp.toIso8601String()}, $state, '
      'EAR=${eyeAspectRatio?.toStringAsFixed(3)}, yaw=${headYawDeg?.toStringAsFixed(1)})';
}

/// A single entry in the dashboard's attention/fatigue history list.
///
/// Rather than logging every single frame (which would flood the list with
/// hundreds of near-identical entries per minute), the app logs only:
///   - state *transitions* (e.g. focused -> drowsy), and
///   - moments where low attention was sustained long enough to be
///     noteworthy (`isSustainedAlert = true`), per AttentionAggregator.
/// See AttentionController for the logging logic.
class HistoryEvent {
  final DateTime timestamp;
  final AttentionState state;
  final bool isSustainedAlert;
  final double? eyeAspectRatio;

  const HistoryEvent({
    required this.timestamp,
    required this.state,
    this.isSustainedAlert = false,
    this.eyeAspectRatio,
  });
}
