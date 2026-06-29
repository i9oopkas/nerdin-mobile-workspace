import 'package:flutter/material.dart';

/// A container that fills available space and shows a scrollbar
/// when content overflows.
///
/// Uses [LayoutBuilder] + [SingleChildScrollView] + [ConstrainedBox] to
/// automatically adapt to parent constraints — fills available vertical
/// space, and scrolls if the child content is taller.
///
/// Can be used globally for any scrollable content:
/// - Stack traces / error logs
/// - Code blocks
/// - Long text outputs
/// - Any content that should fill space and scroll on overflow
///
/// Example:
/// ```dart
/// AdaptiveContentContainer(
///   backgroundColor: const Color(0xFF0D0D1A),
///   padding: const EdgeInsets.all(12),
///   child: SelectableText(
///     logContents,
///     style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent),
///   ),
/// )
/// ```
class AdaptiveContentContainer extends StatelessWidget {
  /// The content to display.
  final Widget child;

  /// Padding around the [child] inside the container.
  final EdgeInsetsGeometry? padding;

  /// Margin around the entire container.
  final EdgeInsetsGeometry? margin;

  /// Background decoration (e.g. rounded corners, border).
  final Decoration? decoration;

  /// Background color (applied if [decoration] is null).
  final Color? backgroundColor;

  /// Minimum height — defaults to the available height from parent.
  /// Set this if you want a taller minimum than what the parent provides.
  final double? minHeight;

  /// Whether to always show the scrollbar thumb. Defaults to true.
  final bool alwaysShowScrollbar;

  /// Optional scroll controller for external scroll management.
  final ScrollController? scrollController;

  /// Border radius shorthand (applied as BoxDecoration if [decoration] is null).
  final BorderRadiusGeometry? borderRadius;

  const AdaptiveContentContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.backgroundColor,
    this.minHeight,
    this.alwaysShowScrollbar = true,
    this.scrollController,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute effective decoration
        final BoxDecoration? effectiveDecoration;
        if (decoration != null) {
          effectiveDecoration = decoration as BoxDecoration?;
        } else if (backgroundColor != null || borderRadius != null) {
          effectiveDecoration = BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
          );
        } else {
          effectiveDecoration = null;
        }

        return Container(
          margin: margin,
          decoration: effectiveDecoration,
          color: effectiveDecoration == null ? backgroundColor : null,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: alwaysShowScrollbar,
            child: SingleChildScrollView(
              controller: scrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minHeight ?? constraints.maxHeight,
                ),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
