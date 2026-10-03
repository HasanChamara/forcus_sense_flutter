import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences — kept as a single service so the
/// rest of the app never touches raw string keys directly.
class PreferencesService {
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyEarThreshold = 'ear_closed_threshold';
  static const _keyYawThreshold = 'distracted_yaw_deg_threshold';

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, value);
  }

  Future<double?> getEarThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyEarThreshold);
  }

  Future<double?> getYawThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyYawThreshold);
  }

  Future<void> saveThresholds({
    required double earThreshold,
    required double yawThreshold,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyEarThreshold, earThreshold);
    await prefs.setDouble(_keyYawThreshold, yawThreshold);
  }
}
