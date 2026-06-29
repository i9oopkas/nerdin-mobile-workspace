import 'dart:async';

import 'package:nerdin_mobile_workspace/core/services/haptic_service.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Platform-specific utilities for enhanced user experience.
///
/// Provides convenience methods for triggering haptic feedback
/// on supported platforms (iOS and Android).
class PlatformUtils {
  PlatformUtils._();

  /// Whether the current device supports haptic feedback.
  static bool get supportsHaptics => NerdinHaptics.supportsHaptics;

  /// Trigger light haptic feedback.
  static void lightHaptic() {
    DebugLogger.info('Haptic: light', scope: 'utils/haptic');
    if (supportsHaptics) {
      unawaited(NerdinHaptics.lightImpact());
    }
  }

  /// Trigger medium haptic feedback.
  static void mediumHaptic() {
    DebugLogger.info('Haptic: medium', scope: 'utils/haptic');
    if (supportsHaptics) {
      unawaited(NerdinHaptics.mediumImpact());
    }
  }

  /// Trigger heavy haptic feedback.
  static void heavyHaptic() {
    if (supportsHaptics) {
      unawaited(NerdinHaptics.heavyImpact());
    }
  }

  /// Trigger selection haptic feedback.
  static void selectionHaptic() {
    if (supportsHaptics) {
      unawaited(NerdinHaptics.selectionClick());
    }
  }
}
