import 'dart:collection';

import '../models/attention_state.dart';

/// Feature 2's core logic: consumes the live stream of per-frame readings
/// from AttentionClassifier (Feature 1) and decides whether attention has
/// been low for long enough to justify interrupting the user with a break
/// alert — a single noisy/drowsy frame must NOT trigger an alert.
///
/// This is what makes Feature 1 and Feature 2 "connected" per the assignment
/// brief: the aggregator has no meaningful output without Feature 1's stream.
class AttentionAggregator {
  /// How far back readings are kept for the "sustained" check.
  final Duration windowDuration;

  /// How long low-attention (drowsy/distracted) must persist within the
  /// window before an alert is justified.
  final Duration sustainedThreshold;

  /// Minimum fraction of readings in the window that must be low-attention
  /// for it to count as "sustained" (guards against one bad frame skewing
  /// a short window).
  final double sustainedFraction;

  /// Cooldown after firing an alert, so the same sustained period doesn't
  /// re-trigger every frame.
  final Duration alertCooldown;

  final Queue<AttentionReading> _readings = Queue();
  DateTime? _lastAlertAt;

  AttentionAggregator({
    this.windowDuration = const Duration(minutes: 5),
    this.sustainedThreshold = const Duration(minutes: 3),
    this.sustainedFraction = 0.7,
    this.alertCooldown = const Duration(minutes: 10),
  });

  /// Readings currently retained in the rolling window — exposed read-only
  /// for the dashboard/timeline UI.
  List<AttentionReading> get recentReadings => List.unmodifiable(_readings);

  /// Adds a new reading and returns true if a break alert should fire now.
  bool addReading(AttentionReading reading) {
    _readings.addLast(reading);
    _evictOldReadings(reading.timestamp);

    if (!_isLowAttentionSustained(reading.timestamp)) return false;

    final now = reading.timestamp;
    if (_lastAlertAt != null && now.difference(_lastAlertAt!) < alertCooldown) {
      return false; // still in cooldown from a previous alert
    }

    _lastAlertAt = now;
    return true;
  }

  void _evictOldReadings(DateTime now) {
    while (_readings.isNotEmpty &&
        now.difference(_readings.first.timestamp) > windowDuration) {
      _readings.removeFirst();
    }
  }

  bool _isLowAttentionSustained(DateTime now) {
    // Only consider the sub-window relevant to "sustained" (may be shorter
    // than the full retained window, which is kept larger for the timeline UI).
    final relevant = _readings
        .where((r) => now.difference(r.timestamp) <= sustainedThreshold)
        .toList();

    if (relevant.isEmpty) return false;

    // Require the sub-window to actually span close to the full threshold
    // duration — otherwise a handful of readings right after app start could
    // falsely trigger.
    final earliestInWindow = relevant.first.timestamp;
    final spanCovered = now.difference(earliestInWindow);
    if (spanCovered < sustainedThreshold * 0.8) return false;

    final lowAttentionCount = relevant
        .where((r) =>
            r.state == AttentionState.drowsy ||
            r.state == AttentionState.distracted)
        .length;

    return (lowAttentionCount / relevant.length) >= sustainedFraction;
  }

  void reset() {
    _readings.clear();
    _lastAlertAt = null;
  }
}
