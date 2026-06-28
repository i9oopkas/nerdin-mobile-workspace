import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tweakcn_themes.dart';

// ── Theme Mode ─────────────────────────────────────────────────

final appThemeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// ── Theme Palette ──────────────────────────────────────────────

final appThemePaletteProvider = StateProvider<TweakcnThemeDefinition>(
  (ref) => TweakcnThemes.conduit,
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

final appLocaleProvider = StateProvider<Locale?>((ref) => null);
