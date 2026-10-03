import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attention_state.dart';
import '../services/attention_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/attention_timeline.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  @override
  void initState() {
    super.initState();
    // Covers the case where the app was relaunched straight into MainScreen
    // (onboarding already complete) and the camera session hasn't started yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AttentionController>();
      if (controller.sessionStatus == CameraSessionStatus.notStarted) {
        controller.startCamera();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitor')),
      body: Consumer<AttentionController>(
        builder: (context, controller, _) {
          switch (controller.sessionStatus) {
            case CameraSessionStatus.notStarted:
            case CameraSessionStatus.starting:
              return const Center(child: CircularProgressIndicator());
            case CameraSessionStatus.unavailable:
              return _buildFallbackView(context, controller);
            case CameraSessionStatus.running:
              return _buildLiveView(context, controller);
          }
        },
      ),
    );
  }

  Widget _buildFallbackView(BuildContext context, AttentionController controller) {
    // FALLBACK BEHAVIOR (error-handling requirement): camera stream
    // unavailable — degrade gracefully instead of crashing.
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Tracking unavailable', style: AppTheme.headline(context)),
            const SizedBox(height: 8),
            Text(
              controller.lastErrorMessage ?? 'Camera could not be started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.startCamera,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveView(BuildContext context, AttentionController controller) {
    final camera = controller.cameraController!;
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          child: AspectRatio(
            aspectRatio: camera.value.aspectRatio,
            child: CameraPreview(camera),
          ),
        ),
        const SizedBox(height: 20),
        _buildStateBadge(context, controller.latestReading),
        const SizedBox(height: 20),
        Expanded(
          child: AttentionTimeline(readings: controller.recentReadings),
        ),
      ],
    );
  }

  Widget _buildStateBadge(BuildContext context, AttentionReading? reading) {
    if (reading == null) {
      return Text('Starting up…', style: Theme.of(context).textTheme.bodyMedium);
    }

    final state = reading.state;
    return Chip(
      avatar: Icon(state.icon, color: Colors.white, size: 18),
      label: Text(
        reading.eyeAspectRatio != null
            ? '${state.label}  ·  EAR ${reading.eyeAspectRatio!.toStringAsFixed(2)}'
            : state.label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: state.color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}
