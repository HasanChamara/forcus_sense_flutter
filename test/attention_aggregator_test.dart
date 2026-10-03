import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sample_project/models/attention_state.dart';
import 'package:flutter_sample_project/services/attention_aggregator.dart';

/// These tests cover the aggregator in isolation — they don't need a camera
/// or ML Kit, which aren't available in a plain `flutter test` environment.
/// They mirror the 3 manual test cases described in the technical evidence
/// document (success / success / error-fallback), expressed as automated
/// checks against Feature 2's logic.
void main() {
  group('AttentionAggregator', () {
    test('does not alert on a single drowsy reading', () {
      final aggregator = AttentionAggregator(
        windowDuration: const Duration(minutes: 5),
        sustainedThreshold: const Duration(minutes: 3),
        sustainedFraction: 0.7,
      );

      final now = DateTime.now();
      final fired = aggregator.addReading(
        AttentionReading(timestamp: now, state: AttentionState.drowsy, eyeAspectRatio: 0.15),
      );

      expect(fired, isFalse,
          reason: 'a single noisy frame must never trigger a break alert');
    });

    test('alerts once drowsy state is sustained across the threshold window', () {
      final aggregator = AttentionAggregator(
        windowDuration: const Duration(minutes: 5),
        sustainedThreshold: const Duration(minutes: 3),
        sustainedFraction: 0.7,
        alertCooldown: const Duration(minutes: 10),
      );

      final start = DateTime.now();
      bool firedAtEnd = false;

      // Simulate one drowsy reading every 10 seconds for just over 3 minutes.
      for (int i = 0; i <= 19; i++) {
        final ts = start.add(Duration(seconds: i * 10));
        final fired = aggregator.addReading(
          AttentionReading(timestamp: ts, state: AttentionState.drowsy, eyeAspectRatio: 0.15),
        );
        if (fired) firedAtEnd = true;
      }

      expect(firedAtEnd, isTrue,
          reason: 'sustained drowsy readings spanning the threshold should alert');
    });

    test('does not alert when readings stay focused', () {
      final aggregator = AttentionAggregator(
        sustainedThreshold: const Duration(minutes: 3),
      );

      final start = DateTime.now();
      bool anyFired = false;

      for (int i = 0; i <= 19; i++) {
        final ts = start.add(Duration(seconds: i * 10));
        final fired = aggregator.addReading(
          AttentionReading(timestamp: ts, state: AttentionState.focused, eyeAspectRatio: 0.32),
        );
        anyFired = anyFired || fired;
      }

      expect(anyFired, isFalse);
    });

    test('fallback: noFace readings are not treated as low attention', () {
      final aggregator = AttentionAggregator(
        sustainedThreshold: const Duration(minutes: 3),
      );

      final start = DateTime.now();
      bool anyFired = false;

      // Simulate the user stepping away from the desk — camera sees no face.
      for (int i = 0; i <= 19; i++) {
        final ts = start.add(Duration(seconds: i * 10));
        final fired = aggregator.addReading(
          AttentionReading(timestamp: ts, state: AttentionState.noFace),
        );
        anyFired = anyFired || fired;
      }

      expect(anyFired, isFalse,
          reason: 'no-face periods must not be misread as sustained fatigue');
    });
  });
}
