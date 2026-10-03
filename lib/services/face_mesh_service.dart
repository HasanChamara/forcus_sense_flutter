import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

/// Wraps Google ML Kit's on-device Face Mesh Detector and handles the
/// boilerplate of turning a raw [CameraImage] frame into the [InputImage]
/// format ML Kit expects.
///
/// NOTE: Face Mesh Detection is Android-only in the current plugin
/// (confirmed as of google_mlkit_face_mesh_detection 0.4.x) — this is exactly
/// why the project targets Android rather than a cross-platform build.
class FaceMeshService {
  final FaceMeshDetector _detector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );

  bool _isBusy = false;

  /// True while a previous frame is still being processed — callers should
  /// skip feeding new frames in while this is true to avoid a backlog
  /// (ML Kit inference is slower than the camera's frame rate).
  bool get isBusy => _isBusy;

  /// Processes a single camera frame and returns the detected face mesh,
  /// or null if no face mesh was found or a frame is dropped for being busy.
  Future<FaceMesh?> detectFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required InputImageRotation rotation,
  }) async {
    if (_isBusy) return null; // drop this frame, keep the pipeline moving
    _isBusy = true;
    try {
      final inputImage = _inputImageFromCameraImage(image, rotation);
      if (inputImage == null) return null;

      final meshes = await _detector.processImage(inputImage);
      if (meshes.isEmpty) return null;
      return meshes.first; // assume a single desk-based user in frame
    } catch (e, st) {
      debugPrint('FaceMeshService: detection failed: $e\n$st');
      return null;
    } finally {
      _isBusy = false;
    }
  }

  /// Converts a [CameraImage] (configured as NV21 on Android — see
  /// HomeScreen's CameraController setup) into the InputImage type ML Kit
  /// needs. This assumes a single-plane NV21 buffer, which is why the
  /// camera controller MUST be created with `imageFormatGroup: nv21`.
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    if (!Platform.isAndroid) return null; // face mesh is Android-only anyway

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final builder = BytesBuilder();
    for (final plane in planes) {
      builder.add(plane.bytes);
    }
    return builder.toBytes();
  }

  /// Must be called when done (e.g. in State.dispose()) to free native
  /// detector resources.
  Future<void> dispose() => _detector.close();
}
