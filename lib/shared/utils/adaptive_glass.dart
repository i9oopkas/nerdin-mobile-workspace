import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Whether Nerdin can rely on native iOS Liquid Glass rendering.
bool nerdinSupportsNativeGlass({bool? isIOS, int? iosMajorVersion}) {
  final effectiveIsIOS = isIOS ?? PlatformInfo.isIOS;
  if (!effectiveIsIOS) {
    return false;
  }

  final effectiveIosVersion = iosMajorVersion ?? PlatformInfo.iOSVersion;
  return effectiveIosVersion >= 26;
}

/// Whether glass-styled chrome should use Nerdin's opaque fallback treatment.
bool nerdinUsesOpaqueGlassFallback({
  bool? isAndroid,
  bool? isIOS,
  int? iosMajorVersion,
}) {
  if (isAndroid ?? PlatformInfo.isAndroid) {
    return true;
  }

  final effectiveIsIOS = isIOS ?? PlatformInfo.isIOS;
  return effectiveIsIOS &&
      !nerdinSupportsNativeGlass(
        isIOS: effectiveIsIOS,
        iosMajorVersion: iosMajorVersion,
      );
}
