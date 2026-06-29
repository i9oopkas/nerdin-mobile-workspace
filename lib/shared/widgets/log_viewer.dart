import 'package:flutter/material.dart';

/// A reusable, auto-sizing log/error display widget.
///
/// Features:
/// - Shows a title (optional) and body text in a styled container
/// - Auto-adjusts height to available space via [BoxConstraints]
/// - Internal scrolling — no overflow ever
/// - Monospace font for code/log readability
/// - Selectable text for copy/paste
/// - Optional accent color for the title
///
/// Use this anywhere you need to display a log, stack trace, error details,
/// or any multi-line text that should scroll without overflowing the layout.
class LogViewer extends StatelessWidget {
  /// Optional title shown above the body (e.g. "Stack trace" or "Error").
  final String? title;

  /// The main body text to display.
  final String body;

  /// Accent color for the title text and left border.
  final Color accentColor;

  /// Background color of the container (default: very dark).
  final Color backgroundColor;

  /// Maximum height constraint. Defaults to 300 logical pixels.
  /// The widget will never exceed this height; it scrolls internally if needed.
  final double maxHeight;

  /// Minimum height. Defaults to 60 so empty content still looks reasonable.
  final double minHeight;

  /// Whether text should be selectable (for copy/paste).
  final bool selectable;

  const LogViewer({
    super.key,
    this.title,
    required this.body,
    this.accentColor = const Color(0xFF00FF88),
    this.backgroundColor = const Color(0xFF0D0D1A),
    this.maxHeight = 300,
    this.minHeight = 60,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Clamp height to available space to prevent overflow
        final effectiveMaxHeight =
            constraints.hasBoundedHeight
                ? constraints.maxHeight
                : maxHeight;

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: minHeight,
            maxHeight: effectiveMaxHeight,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: accentColor.withOpacity(0.5), width: 3),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (selectable)
                  SelectableText(
                    body,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFE0E0E0),
                      height: 1.4,
                    ),
                  )
                else
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFE0E0E0),
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
