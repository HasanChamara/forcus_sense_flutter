import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/attention_state.dart';

/// Central place for every color, font, and per-state icon used across the
/// app — screens should reference these rather than hardcoding Colors.* or
/// Icons.* so the visual identity stays consistent everywhere.
class AppTheme {
  AppTheme._();

  // Brand seed — a calm teal, deliberately not a generic Material blue, to
  // read as "focus/wellbeing" rather than a generic business-app palette.
  static const Color seed = Color(0xFF0F6E56);

  static const Color focusedColor = Color(0xFF2E7D32); // green 800
  static const Color drowsyColor = Color(0xFFD35400); // burnt orange
  static const Color distractedColor = Color(0xFFB7950B); // amber/gold
  static const Color neutralColor = Color(0xFF757575); // grey 600
  static const Color alertColor = Color(0xFFC0392B); // reserved for sustained alerts

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: base.colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: base.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.colorScheme.surface,
        indicatorColor: seed.withValues(alpha: 0.15),
      ),
    );
  }

  static TextStyle headline(BuildContext context) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle sectionLabel(BuildContext context) => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

/// Maps each [AttentionState] to the icon, color and label used consistently
/// across the Monitor badge, Dashboard list, and timeline strip.
extension AttentionStateVisuals on AttentionState {
  Color get color {
    switch (this) {
      case AttentionState.focused:
        return AppTheme.focusedColor;
      case AttentionState.drowsy:
        return AppTheme.drowsyColor;
      case AttentionState.distracted:
        return AppTheme.distractedColor;
      case AttentionState.uncertain:
        return AppTheme.neutralColor;
      case AttentionState.noFace:
        return AppTheme.neutralColor;
    }
  }

  IconData get icon {
    switch (this) {
      case AttentionState.focused:
        return Icons.visibility_rounded;
      case AttentionState.drowsy:
        return Icons.bedtime_rounded;
      case AttentionState.distracted:
        return Icons.swap_horiz_rounded;
      case AttentionState.uncertain:
        return Icons.help_outline_rounded;
      case AttentionState.noFace:
        return Icons.person_off_rounded;
    }
  }

  String get label {
    switch (this) {
      case AttentionState.focused:
        return 'Focused';
      case AttentionState.drowsy:
        return 'Drowsy';
      case AttentionState.distracted:
        return 'Distracted';
      case AttentionState.uncertain:
        return 'Uncertain';
      case AttentionState.noFace:
        return 'No face detected';
    }
  }
}
