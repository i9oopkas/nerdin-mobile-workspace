import 'package:flutter/services.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

SystemUiOverlayStyle systemUiOverlayStyleForBrightness(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final iconBrightness = isDark ? Brightness.light : Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarBrightness: brightness,
    statusBarIconBrightness: iconBrightness,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// Applies a single System UI overlay style after first frame to avoid flicker
/// at startup and to align with the active theme brightness.
void applySystemUiOverlayStyleOnce({required Brightness brightness}) {
  DebugLogger.info('System UI overlay applied', scope: 'system/ui', data: {'brightness': '$brightness'});
  SystemChrome.setSystemUIOverlayStyle(
    systemUiOverlayStyleForBrightness(brightness),
  );
}
