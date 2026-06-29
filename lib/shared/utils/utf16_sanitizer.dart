import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Replaces unpaired UTF-16 surrogates with U+FFFD so Flutter text layout
/// does not crash on malformed strings.
String sanitizeUtf16(String input) {
  if (input.isEmpty) {
    return input;
  }

  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final codeUnit = input.codeUnitAt(i);

    if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      if (i + 1 < input.length) {
        final nextCodeUnit = input.codeUnitAt(i + 1);
        if (nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF) {
          buffer
            ..writeCharCode(codeUnit)
            ..writeCharCode(nextCodeUnit);
          i++;
          continue;
        }
      }

      buffer.writeCharCode(0xFFFD);
      continue;
    }

    if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
      buffer.writeCharCode(0xFFFD);
      continue;
    }

    buffer.writeCharCode(codeUnit);
  }

  final result = buffer.toString();
  DebugLogger.info('UTF-16 sanitize: ${input.length} → ${result.length} chars', scope: 'utils/utf16');
  return result;
}
