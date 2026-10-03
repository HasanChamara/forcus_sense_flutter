import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/attention_controller.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

/// First screen a new user sees. Two jobs:
///   1. Get explicit camera permission (with a clear "why").
///   2. State plainly that everything runs on-device — no cloud API, no
///      video or landmark data ever leaves the phone — since that's the
///      whole justification for the chosen emerging technology.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _requesting = false;
  bool _permanentlyDenied = false;

  Future<void> _requestPermissionAndContinue() async {
    setState(() {
      _requesting = true;
      _permanentlyDenied = false;
    });

    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isGranted) {
      await PreferencesService().setOnboardingComplete(true);
      if (!mounted) return;
      // Kick off the camera session now, before navigating, so Monitor's
      // first frame arrives sooner.
      context.read<AttentionController>().startCamera();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
      return;
    }

    setState(() {
      _requesting = false;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.visibility_rounded, size: 72, color: colors.primary),
              const SizedBox(height: 24),
              Text(
                'Welcome to FocusSense',
                textAlign: TextAlign.center,
                style: AppTheme.headline(context),
              ),
              const SizedBox(height: 12),
              Text(
                'FocusSense watches for signs of fatigue and lost focus during '
                'long coding sessions, and nudges you to take a break when it '
                'matters.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _buildPrivacyCard(context),
              const SizedBox(height: 24),
              if (_permanentlyDenied) _buildPermanentlyDeniedNotice(context),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _requesting ? null : _requestPermissionAndContinue,
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(_requesting ? 'Requesting…' : 'Enable camera & get started'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can turn this off anytime in Settings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Your privacy', style: AppTheme.sectionLabel(context)),
              ],
            ),
            const SizedBox(height: 10),
            _privacyPoint(context, 'All processing happens on this device.'),
            _privacyPoint(context, 'No cloud API is used — no video or face data is ever uploaded.'),
            _privacyPoint(context, 'Nothing is shared with Anthropic, Google, or anyone else.'),
          ],
        ),
      ),
    );
  }

  Widget _privacyPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3.0),
            child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildPermanentlyDeniedNotice(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            const Text(
              'Camera permission was denied. FocusSense can\'t work without '
              'it — please enable it in system settings.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: openAppSettings,
              child: const Text('Open app settings'),
            ),
          ],
        ),
      ),
    );
  }
}
