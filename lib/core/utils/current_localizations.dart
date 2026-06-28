import 'package:flutter/material.dart';

/// Stub for current_app_localizations.
/// The full OWUI localization system has been removed.
/// Minimal implementation so tweakcn_themes.dart compiles.
String currentAppLocalizations() {
  return 'en';
}

/// Stub AppLocalizations class providing all getters needed by
/// TweakcnThemeDefinition label/description builders.
class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations();
  }

  String get themePaletteClaudeLabel => 'Claude';
  String get themePaletteClaudeDescription => 'Claude-inspired theme';
  String get themePaletteT3ChatLabel => 'T3 Chat';
  String get themePaletteT3ChatDescription => 'T3 Chat inspired theme';
  String get themePaletteNerdinLabel => 'Nerdin';
  String get themePaletteNerdinDescription => 'Default Nerdin theme';
  String get themePaletteCatppuccinLabel => 'Catppuccin';
  String get themePaletteCatppuccinDescription => 'Catppuccin-inspired theme';
  String get themePaletteTangerineLabel => 'Tangerine';
  String get themePaletteTangerineDescription => 'Tangerine-inspired theme';
  String get conduit => 'Nerdin';
  String get nerdin => 'Nerdin';
  String get unknown => 'Unknown';
}
