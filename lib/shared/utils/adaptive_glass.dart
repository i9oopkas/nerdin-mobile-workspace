import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Whether Nerdin can rely on native iOS Liquid Glass rendering.
bool nerdinSupportsNativeGlass({bool? isIOS, int? iosMajorVersion}) {
  final effectiveIsIOS = isIOS ?? PlatformInfo.isIOS;
  if (!effectiveIsIOS) {
    return false;
  }

  final effectiveIosVersion = iosMajorVersion ?? PlatformInfo.iOSVersion;
  final result = effectiveIosVersion >= 26;
  DebugLogger.info('Glass support check: iOS >= 26 → $result', scope: 'utils/glass');
  return result;
}

/// Whether glass-styled chrome should use Nerdin's opaque fallback treatment.
bool nerdinUsesOpaqueGlassFallback({
  bool? isAndroid,
  bool? isIOS,
  int? iosMajorVersion,
}) {
  if (isAndroid ?? PlatformInfo.isAndroid) {
    DebugLogger.info('Glass fallback: true', scope: 'utils/glass');
    return true;
  }

  final effectiveIsIOS = isIOS ?? PlatformInfo.isIOS;
  final result = effectiveIsIOS &&
      !nerdinSupportsNativeGlass(
        isIOS: effectiveIsIOS,
        iosMajorVersion: iosMajorVersion,
      );
  DebugLogger.info('Glass fallback: $result', scope: 'utils/glass');
  return result;
}
