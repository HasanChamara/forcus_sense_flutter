import 'dart:math' as math;

import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../models/attention_state.dart';

/// Turns a single frame's [FaceMesh] into an [AttentionReading] using
/// geometric heuristics (eye-aspect-ratio + head yaw) rather than a trained
/// classifier.
///
/// WHY HEURISTICS, NOT A TRAINED MODEL: fatigue/attention is well captured by
/// eye-closure duration and head-pose deviation (standard PERCLOS-style
/// drowsiness research), so a threshold-based approach is honest, explainable
/// and avoids the 4-week risk of training+validating a classifier from
/// scratch. See the Week 1 progress form's technology-selection justification.
///
/// IMPORTANT: The threshold constants below are *starting points* copied from
/// common EAR-based drowsiness literature (~0.2-0.25 typical open-eye EAR).
/// Per the Week-1 "next action", these MUST be recalibrated against your own
/// recorded EAR values (focused vs. simulated-drowsy) before relying on them
/// for the demo — see calibration notes in README.md.
class AttentionClassifier {
  // --- Tunable thresholds ---
  // These are INSTANCE fields (not const) so the Settings screen can let the
  // user adjust sensitivity at runtime via AttentionController, and persist
  // the chosen values — see PreferencesService. Defaults below are starting
  // points from general EAR-based drowsiness literature; recalibrate per
  // README instructions before relying on them for a demo.

  /// EAR below this is treated as "eye(s) closed" for a frame.
  double earClosedThreshold;

  /// Head yaw beyond this (degrees, approximate) is treated as "looking
  /// away" / distracted rather than focused on the screen.
  double distractedYawDegThreshold;

  /// Minimum confidence proxy: if the face mesh bounding box is too small
  /// (face far from camera / low detail), treat the frame as uncertain
  /// rather than guessing. Not user-adjustable — a fixed quality floor.
  static const double minFaceBoxWidthPx = 80.0;

  AttentionClassifier({
    this.earClosedThreshold = 0.21,
    this.distractedYawDegThreshold = 30.0,
  });

  // --- MediaPipe/ML Kit canonical 468-point face mesh indices used for EAR.
  // These are the standard six-point-per-eye landmark sets used throughout
  // EAR-based drowsiness literature, and apply here because ML Kit's Face
  // Mesh uses the same 468-point canonical topology as MediaPipe Face Mesh.
  static const List<int> _leftEyeIdx = [33, 160, 158, 133, 153, 144];
  static const List<int> _rightEyeIdx = [362, 385, 387, 263, 373, 380];

  // Rough yaw proxy landmarks: nose tip vs. left/right face-oval edges.
  static const int _noseTipIdx = 1;
  static const int _leftFaceEdgeIdx = 234;
  static const int _rightFaceEdgeIdx = 454;

  AttentionReading classify(FaceMesh? mesh, DateTime timestamp) {
    if (mesh == null) {
      return AttentionReading(timestamp: timestamp, state: AttentionState.noFace);
    }

    final pointsByIndex = {for (final p in mesh.points) p.index: p};

    final hasAllEyePoints = [..._leftEyeIdx, ..._rightEyeIdx]
        .every((i) => pointsByIndex.containsKey(i));
    final hasPosePoints = [_noseTipIdx, _leftFaceEdgeIdx, _rightFaceEdgeIdx]
        .every((i) => pointsByIndex.containsKey(i));

    if (!hasAllEyePoints || mesh.boundingBox.width < minFaceBoxWidthPx) {
      return AttentionReading(timestamp: timestamp, state: AttentionState.uncertain);
    }

    final leftEar = _eyeAspectRatio(_leftEyeIdx, pointsByIndex);
    final rightEar = _eyeAspectRatio(_rightEyeIdx, pointsByIndex);
    final avgEar = (leftEar + rightEar) / 2.0;

    double? yawDeg;
    if (hasPosePoints) {
      yawDeg = _approximateYawDegrees(pointsByIndex);
    }

    // Priority: drowsy (safety-relevant) > distracted > focused.
    if (avgEar < earClosedThreshold) {
      return AttentionReading(
        timestamp: timestamp,
        state: AttentionState.drowsy,
        eyeAspectRatio: avgEar,
        headYawDeg: yawDeg,
      );
    }

    if (yawDeg != null && yawDeg.abs() > distractedYawDegThreshold) {
      return AttentionReading(
        timestamp: timestamp,
        state: AttentionState.distracted,
        eyeAspectRatio: avgEar,
        headYawDeg: yawDeg,
      );
    }

    return AttentionReading(
      timestamp: timestamp,
      state: AttentionState.focused,
      eyeAspectRatio: avgEar,
      headYawDeg: yawDeg,
    );
  }

  /// Standard 6-point eye-aspect-ratio (EAR) formula:
  /// EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
  /// where p1/p4 are the eye corners and p2,p3,p5,p6 are the upper/lower lid
  /// points. Indices below follow the order defined in [_leftEyeIdx]/[_rightEyeIdx]:
  /// [p1(outer corner), p2(upper-outer lid), p3(upper-inner lid),
  ///  p4(inner corner), p5(lower-inner lid), p6(lower-outer lid)]
  double _eyeAspectRatio(List<int> idx, Map<int, FaceMeshPoint> points) {
    final p1 = points[idx[0]]!;
    final p2 = points[idx[1]]!;
    final p3 = points[idx[2]]!;
    final p4 = points[idx[3]]!;
    final p5 = points[idx[4]]!;
    final p6 = points[idx[5]]!;

    final vertical1 = _distance2D(p2, p6);
    final vertical2 = _distance2D(p3, p5);
    final horizontal = _distance2D(p1, p4);

    if (horizontal == 0) return 1.0; // avoid div-by-zero; treat as open
    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  double _distance2D(FaceMeshPoint a, FaceMeshPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Rough, cheap yaw estimate: compares the nose tip's horizontal offset
  /// from the midpoint of the two face-edge landmarks, scaled by face width.
  /// This is NOT a calibrated 3D head-pose solve (that would need a full
  /// PnP/solvePnP approach) — it's a lightweight proxy good enough to flag
  /// "looking substantially away from the screen" for the break-alert logic.
  /// Documented as a known limitation in the technical evidence doc.
  double _approximateYawDegrees(Map<int, FaceMeshPoint> points) {
    final nose = points[_noseTipIdx]!;
    final leftEdge = points[_leftFaceEdgeIdx]!;
    final rightEdge = points[_rightFaceEdgeIdx]!;

    final faceWidth = (rightEdge.x - leftEdge.x).abs();
    if (faceWidth == 0) return 0.0;

    final midX = (leftEdge.x + rightEdge.x) / 2.0;
    final offset = (nose.x - midX) / faceWidth; // roughly -0.5..0.5

    // Map normalized offset to an approximate degree range (empirically
    // tuned proxy, not a geometric derivation) — recalibrate per README.
    return offset * 90.0;
  }
}
