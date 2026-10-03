import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/attention_controller.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final onboardingComplete = await PreferencesService().isOnboardingComplete();

  runApp(FocusSenseApp(startAtOnboarding: !onboardingComplete));
}

class FocusSenseApp extends StatefulWidget {
  final bool startAtOnboarding;
  const FocusSenseApp({super.key, required this.startAtOnboarding});

  @override
  State<FocusSenseApp> createState() => _FocusSenseAppState();
}

class _FocusSenseAppState extends State<FocusSenseApp> {
  late final AttentionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AttentionController();
    _controller.loadPersistedThresholds();
    // If onboarding was already completed in a previous session, camera
    // permission should already be granted — start the session immediately
    // rather than waiting for MonitorScreen's first build.
    if (!widget.startAtOnboarding) {
      _controller.startCamera();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AttentionController>.value(
      value: _controller,
      child: MaterialApp(
        title: 'FocusSense',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: widget.startAtOnboarding ? const OnboardingScreen() : const MainScreen(),
      ),
    );
  }
}
