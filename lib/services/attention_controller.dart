import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import '../models/attention_state.dart';
import 'attention_aggregator.dart';
import 'attention_classifier.dart';
import 'face_mesh_service.dart';
import 'preferences_service.dart';

enum CameraSessionStatus { notStarted, starting, running, unavailable }

/// Owns the entire live pipeline — camera session, face mesh detection,
/// classification, the rolling-window aggregator, and the resulting history
/// log — as a single ChangeNotifier shared (via provider) across the
/// Monitor, Dashboard and Settings screens.
///
/// Centralizing this here (rather than inside a single screen's State) is
/// what lets the camera session keep running, and history keep accumulating,
/// while the user is looking at the Dashboard or Settings tab.
class AttentionController extends ChangeNotifier {
  final FaceMeshService _faceMeshService = FaceMeshService();
  final AttentionAggregator _aggregator = AttentionAggregator();
  final AttentionClassifier classifier = AttentionClassifier();
  final PreferencesService _prefs = PreferencesService();

  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;

  CameraSessionStatus sessionStatus = CameraSessionStatus.notStarted;
  String? lastErrorMessage;

  AttentionReading? latestReading;

  /// Short rolling buffer purely for the Monitor tab's compact strip —
  /// capped independently of the aggregator's own window.
  final List<AttentionReading> _recentReadings = [];
  List<AttentionReading> get recentReadings => List.unmodifiable(_recentReadings);
  static const int _recentReadingsCap = 60;

  /// Full history shown on the Dashboard tab, newest first.
  final List<HistoryEvent> historyEvents = [];
  static const int _historyCap = 300;
  AttentionState? _lastLoggedState;

  Future<void> loadPersistedThresholds() async {
    final ear = await _prefs.getEarThreshold();
    final yaw = await _prefs.getYawThreshold();
    if (ear != null) classifier.earClosedThreshold = ear;
    if (yaw != null) classifier.distractedYawDegThreshold = yaw;
    notifyListeners();
  }

  Future<void> updateThresholds({
    required double earThreshold,
    required double yawThreshold,
  }) async {
    classifier.earClosedThreshold = earThreshold;
    classifier.distractedYawDegThreshold = yawThreshold;
    await _prefs.saveThresholds(earThreshold: earThreshold, yawThreshold: yawThreshold);
    notifyListeners();
  }

  void clearHistory() {
    historyEvents.clear();
    _lastLoggedState = null;
    notifyListeners();
  }

  Future<void> startCamera() async {
    if (sessionStatus == CameraSessionStatus.running ||
        sessionStatus == CameraSessionStatus.starting) {
      return;
    }
    sessionStatus = CameraSessionStatus.starting;
    notifyListeners();

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        // REQUIRED: FaceMeshService assumes a single-plane NV21 buffer.
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();

      final rotation = _rotationFromSensorOrientation(frontCamera.sensorOrientation);
      await controller.startImageStream((image) {
        _handleFrame(image, frontCamera, rotation);
      });

      _cameraController = controller;
      sessionStatus = CameraSessionStatus.running;
      lastErrorMessage = null;
    } catch (e) {
      sessionStatus = CameraSessionStatus.unavailable;
      lastErrorMessage = '$e';
    }
    notifyListeners();
  }

  InputImageRotation _rotationFromSensorOrientation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _handleFrame(
    CameraImage image,
    CameraDescription camera,
    InputImageRotation rotation,
  ) async {
    if (_faceMeshService.isBusy) return; // keep the stream moving

    final mesh = await _faceMeshService.detectFromCameraImage(
      image: image,
      camera: camera,
      rotation: rotation,
    );

    final reading = classifier.classify(mesh, DateTime.now());
    _recordReading(reading);
  }

  void _recordReading(AttentionReading reading) {
    latestReading = reading;

    _recentReadings.add(reading);
    if (_recentReadings.length > _recentReadingsCap) {
      _recentReadings.removeAt(0);
    }

    final sustained = _aggregator.addReading(reading);

    // Log a history entry on meaningful state changes (skip `uncertain`,
    // which is a low-confidence frame rather than a real state) ...
    final isMeaningfulState = reading.state != AttentionState.uncertain;
    if (isMeaningfulState && reading.state != _lastLoggedState) {
      _lastLoggedState = reading.state;
      historyEvents.insert(
        0,
        HistoryEvent(
          timestamp: reading.timestamp,
          state: reading.state,
          eyeAspectRatio: reading.eyeAspectRatio,
        ),
      );
    }

    // ... plus always log a distinct "sustained" entry, since that's the
    // moment Feature 2 decided attention had been low for long enough to
    // flag — even if the state itself hasn't just changed.
    if (sustained) {
      historyEvents.insert(
        0,
        HistoryEvent(
          timestamp: reading.timestamp,
          state: reading.state,
          isSustainedAlert: true,
          eyeAspectRatio: reading.eyeAspectRatio,
        ),
      );
    }

    if (historyEvents.length > _historyCap) {
      historyEvents.removeRange(_historyCap, historyEvents.length);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceMeshService.dispose();
    super.dispose();
  }
}
