import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Wildcard pattern matching for permission rules.
///
/// Matches input strings against patterns containing:
/// - `*` — matches zero or more characters
/// - `?` — matches exactly one character
///
/// All other characters are matched literally (including regex special chars
/// which are escaped internally).
///
/// Based on Opencode's `packages/core/src/util/wildcard.ts`.
class Wildcard {
  Wildcard._();

  /// Returns `true` if [input] matches [pattern].
  ///
  /// Examples:
  /// ```dart
  /// Wildcard.match('git status', 'git *');       // true
  /// Wildcard.match('git', 'git *');               // false (needs at least one arg)
  /// Wildcard.match('git commit -m "x"', 'git *'); // true
  /// Wildcard.match('lib/foo.dart', 'lib/*.dart'); // true
  /// Wildcard.match('lib/foo/bar.dart', 'lib/*.dart'); // false (* doesn't cross /)
  /// Wildcard.match('file.env', '*.env');          // true
  /// Wildcard.match('file.env.local', '*.env');    // false
  /// Wildcard.match('abc', 'a?c');                 // true
  /// Wildcard.match('ac', 'a?c');                  // false (? must match exactly 1)
  /// Wildcard.match('anything', '*');              // true
  /// ```
  static bool match(String input, String pattern) {
    if (pattern == '*') {
      DebugLogger.info('Wildcard match: "$pattern" vs "$input" → true', scope: 'permission/wildcard');
      return true;
    }

    // Escape all regex special characters except * and ?
    final escaped = StringBuffer();
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '*') {
        escaped.write('.*');
      } else if (c == '?') {
        escaped.write('.');
      } else if (_regexSpecialChars.contains(c)) {
        escaped.write('\\$c');
      } else {
        escaped.write(c);
      }
    }

    try {
      final regex = RegExp('^${escaped.toString()}\$');
      final result = regex.hasMatch(input);
      DebugLogger.info('Wildcard match: "$pattern" vs "$input" → $result', scope: 'permission/wildcard');
      return result;
    } catch (e) {
      // If the pattern somehow produces an invalid regex, fall back to exact match
      return input == pattern;
    }
  }

  /// Characters that have special meaning in regex and need escaping.
  static const _regexSpecialChars = r'.+^${}()|[]\';
}
