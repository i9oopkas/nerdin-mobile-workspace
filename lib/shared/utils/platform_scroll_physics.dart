import 'package:flutter/material.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

ScrollPhysics platformAlwaysScrollablePhysics(BuildContext context) {
  DebugLogger.info('platform_scroll_physics: accessed', scope: 'utils/general');
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    _ => const AlwaysScrollableScrollPhysics(),
  };
}
