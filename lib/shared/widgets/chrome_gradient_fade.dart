import 'package:flutter/widgets.dart';

import '../theme/theme_extensions.dart';

const double kNerdinChromeFadeHeight = 30.0;

enum NerdinChromeFadeEdge { top, bottom }

/// Gradient-only chrome edge used when custom Flutter bars replace native bars.
///
/// This intentionally does not blur. It gives transparent custom chrome the
/// same soft scroll-edge separation as the adaptive bars while keeping the
/// underlying content readable.
class NerdinChromeGradientFade extends StatelessWidget {
  const NerdinChromeGradientFade({
    super.key,
    required this.edge,
    required this.contentHeight,
    this.fadeHeight = kNerdinChromeFadeHeight,
  });

  const NerdinChromeGradientFade.top({
    super.key,
    required this.contentHeight,
    this.fadeHeight = kNerdinChromeFadeHeight,
  }) : edge = NerdinChromeFadeEdge.top;

  const NerdinChromeGradientFade.bottom({
    super.key,
    required this.contentHeight,
    this.fadeHeight = kNerdinChromeFadeHeight,
  }) : edge = NerdinChromeFadeEdge.bottom;

  final NerdinChromeFadeEdge edge;
  final double contentHeight;
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    final baseColor = context.nerdinTheme.surfaceBackground;
    final height = contentHeight + fadeHeight;
    final colors = edge == NerdinChromeFadeEdge.top
        ? [
            baseColor.withValues(alpha: 0.92),
            baseColor.withValues(alpha: 0.72),
            baseColor.withValues(alpha: 0.28),
            baseColor.withValues(alpha: 0.0),
          ]
        : [
            baseColor.withValues(alpha: 0.0),
            baseColor.withValues(alpha: 0.28),
            baseColor.withValues(alpha: 0.72),
            baseColor.withValues(alpha: 0.92),
          ];

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
              stops: const [0.0, 0.3, 0.65, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
