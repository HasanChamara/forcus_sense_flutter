import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/attention_controller.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<AttentionController>(
        builder: (context, controller, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Detection sensitivity',
                icon: Icons.tune_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjust these if FocusSense feels too sensitive or not '
                      'sensitive enough for your lighting and camera setup. '
                      'See the README for calibration tips.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _ThresholdSlider(
                      label: 'Eye-closure sensitivity',
                      helper: 'Lower = triggers "drowsy" more easily',
                      value: controller.classifier.earClosedThreshold,
                      min: 0.15,
                      max: 0.30,
                      onChangeEnd: (value) => controller.updateThresholds(
                        earThreshold: value,
                        yawThreshold: controller.classifier.distractedYawDegThreshold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ThresholdSlider(
                      label: 'Head-turn sensitivity',
                      helper: 'Lower = triggers "distracted" more easily',
                      value: controller.classifier.distractedYawDegThreshold,
                      min: 15,
                      max: 45,
                      onChangeEnd: (value) => controller.updateThresholds(
                        earThreshold: controller.classifier.earClosedThreshold,
                        yawThreshold: value,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Your privacy',
                icon: Icons.shield_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _PrivacyRow('All face-mesh processing happens on this device.'),
                    _PrivacyRow('No cloud API is used — no video or face data is ever uploaded.'),
                    _PrivacyRow('Camera frames are never saved to disk; only the attention state and timestamp are logged.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Data',
                icon: Icons.storage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${controller.historyEvents.length} entries logged on this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: controller.historyEvents.isEmpty ? null : controller.clearHistory,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Clear history'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'About',
                icon: Icons.info_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FocusSense detects signs of fatigue and lost focus during '
                      'desk-based coding sessions using on-device computer vision '
                      '(Google ML Kit Face Mesh), built for IT6070 Assignment II.',
                    ),
                    const SizedBox(height: 12),
                    Text('Version 0.2.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _resetOnboarding(context),
                      child: const Text('Reset onboarding (dev utility)'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resetOnboarding(BuildContext context) async {
    await PreferencesService().setOnboardingComplete(false);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text(title, style: AppTheme.sectionLabel(context)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Stateful so the thumb tracks the drag gesture smoothly; the parent
/// (and persisted storage) is only updated once the user releases the
/// slider, via [onChangeEnd] — recalibrating on every pixel of drag would
/// mean a storage write per frame.
class _ThresholdSlider extends StatefulWidget {
  final String label;
  final String helper;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChangeEnd;

  const _ThresholdSlider({
    required this.label,
    required this.helper,
    required this.value,
    required this.min,
    required this.max,
    required this.onChangeEnd,
  });

  @override
  State<_ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<_ThresholdSlider> {
  late double _localValue = widget.value;

  @override
  void didUpdateWidget(covariant _ThresholdSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep in sync if the value changes externally (e.g. loaded from
    // persisted preferences after this widget was first built).
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(_localValue.toStringAsFixed(2)),
          ],
        ),
        Slider(
          value: _localValue,
          min: widget.min,
          max: widget.max,
          onChanged: (v) => setState(() => _localValue = v),
          onChangeEnd: widget.onChangeEnd,
        ),
        Text(widget.helper, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final String text;
  const _PrivacyRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3.0),
            child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
