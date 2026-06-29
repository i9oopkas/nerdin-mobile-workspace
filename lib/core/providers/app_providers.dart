import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tweakcn_themes.dart';

// ── Theme Mode ─────────────────────────────────────────────────

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    DebugLogger.info('AppThemeModeNotifier initialized', scope: 'theme/notifier');
    return ThemeMode.system;
  }

  void setTheme(ThemeMode mode) {
    DebugLogger.info('Theme toggled', scope: 'theme/toggle', data: {'mode': '$mode'});
    state = mode;
  }
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

// ── Theme Palette ──────────────────────────────────────────────

class AppThemePaletteNotifier extends Notifier<TweakcnThemeDefinition> {
  @override
  TweakcnThemeDefinition build() => TweakcnThemes.conduit;
}

final appThemePaletteProvider =
    NotifierProvider<AppThemePaletteNotifier, TweakcnThemeDefinition>(
  AppThemePaletteNotifier.new,
);

// ── Material Themes ────────────────────────────────────────────

final appLightThemeProvider = Provider<ThemeData>((ref) {
  final palette = ref.watch(appThemePaletteProvider);
  return AppTheme.light(palette);
});

final appDarkThemeProvider = Provider<ThemeData>((ref) {
  final palette = ref.watch(appThemePaletteProvider);
  return AppTheme.dark(palette);
});

// ── Cupertino Themes ───────────────────────────────────────────

final appCupertinoLightThemeProvider = Provider<CupertinoThemeData>((ref) {
  final palette = ref.watch(appThemePaletteProvider);
  return AppTheme.cupertinoLight(palette);
});

final appCupertinoDarkThemeProvider = Provider<CupertinoThemeData>((ref) {
  final palette = ref.watch(appThemePaletteProvider);
  return AppTheme.cupertinoDark(palette);
});

// ── Locale ─────────────────────────────────────────────────────

class AppLocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void setLocale(Locale? locale) => state = locale;
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);
