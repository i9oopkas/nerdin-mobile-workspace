import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen crash report widget.
/// Shown when an unhandled Flutter error occurs (e.g. `_dirty` assertion).
class ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails errorDetails;
  final List<FlutterErrorDetails> additionalErrors;
  final VoidCallback? onRestart;

  const ErrorScreen({
    super.key,
    required this.errorDetails,
    this.additionalErrors = const [],
    this.onRestart,
  });

  /// Builds the full crash report text (includes all errors)
  String get _fullLog {
    final buf = StringBuffer();
    buf.writeln('===== Nerdin Mobile Workspace Crash Report =====');
    buf.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buf.writeln('');
    
    // Primary error
    buf.writeln('--- Primary Error ---');
    buf.writeln('Error type: ${errorDetails.exception.runtimeType}');
    buf.writeln('Error message: ${errorDetails.exception}');
    buf.writeln('');
    if (errorDetails.stack != null) {
      buf.writeln('--- Stack trace ---');
      buf.writeln(errorDetails.stack.toString());
    }
    
    // Additional errors
    for (var i = 0; i < additionalErrors.length; i++) {
      final err = additionalErrors[i];
      buf.writeln('');
      buf.writeln('--- Cascading Error #${i + 1} ---');
      buf.writeln('Error type: ${err.exception.runtimeType}');
      buf.writeln('Error message: ${err.exception}');
      buf.writeln('');
      if (err.stack != null) {
        buf.writeln('--- Stack trace ---');
        buf.writeln(err.stack.toString());
      }
    }
    
    buf.writeln('');
    buf.writeln('===== End of report =====');
    return buf.toString();
  }

  Future<File> _saveLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/nerdin_crash_$timestamp.log');
    await file.writeAsString(_fullLog);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Nerdin — Crash Report'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Error header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.red.shade900.withOpacity(0.3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bug_report, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Something went wrong',
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nerdin encountered an unexpected error. '
                        'Please share the crash log to help fix it.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade800.withOpacity(0.5)),
              ),
              child: SelectableText(
                '${errorDetails.exception}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),

          // Stack trace — primary error
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Primary error
                      Text(
                        '❌ ${errorDetails.exception.runtimeType}: ${errorDetails.exception}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        errorDetails.stack?.toString() ?? '(No stack trace)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF00FF88),
                          height: 1.4,
                        ),
                      ),
                      // Additional cascading errors
                      if (additionalErrors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 8),
                        Text(
                          '📋 ${additionalErrors.length} cascading error(s):',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...additionalErrors.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final err = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📎 #$idx ${err.exception.runtimeType}: ${err.exception}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  err.stack?.toString() ?? '(No stack trace)',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Color(0xFFFFCC88),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.copy,
                        label: 'Copy',
                        color: Colors.blueGrey,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _fullLog));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.save_alt,
                        label: 'Save',
                        color: Colors.teal,
                        onTap: () async {
                          try {
                            final file = await _saveLogFile();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved: ${file.path}'),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Save failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        color: Colors.indigo,
                        onTap: () async {
                          try {
                            final file = await _saveLogFile();
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [XFile(file.path)],
                                subject: 'Nerdin Crash Report',
                              ),
                            );
                          } catch (e) {
                            // Fallback: share text directly
                            await SharePlus.instance.share(
                              ShareParams(
                                text: _fullLog,
                                subject: 'Nerdin Crash Report',
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart Nerdin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'If the error persists, please share the crash log with the developer.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded action button for Copy / Save / Share
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.shade800.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.shade600.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.shade200, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.shade200,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
