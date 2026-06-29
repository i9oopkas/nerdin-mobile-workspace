import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:highlight/languages/all.dart'; // registers all languages

/// A read-only code viewer tab that shows file content with
/// syntax highlighting using [flutter_highlight].
///
/// Supports both light and dark themes. File content is loaded
/// synchronously with [File.readAsStringSync] so it's suitable
/// for reasonably-sized files.
class CodeEditorTab extends StatefulWidget {
  final String filePath;

  const CodeEditorTab({super.key, required this.filePath});

  @override
  State<CodeEditorTab> createState() => _CodeEditorTabState();
}

class _CodeEditorTabState extends State<CodeEditorTab> {
  String? _content;
  String? _error;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadFile();
      _loaded = true;
    }
  }

  @override
  void didUpdateWidget(CodeEditorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loaded = false;
      _content = null;
      _error = null;
      _loadFile();
    }
  }

  void _loadFile() {
    DebugLogger.info('Code editor opened: ${widget.filePath}', scope: 'workspace/editor');
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        _error = 'File not found: ${widget.filePath}';
        return;
      }
      final size = file.lengthSync();
      if (size > 1024 * 1024) {
        // > 1MB — warn but still try to load
        _content = file.readAsStringSync();
        return;
      }
      _content = file.readAsStringSync();
    } catch (e) {
      _error = 'Error reading file: $e';
    }
  }

  String _detectLanguage(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'java':
        return 'java';
      case 'py':
        return 'python';
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'json':
        return 'json';
      case 'xml':
      case 'html':
        return 'xml';
      case 'css':
        return 'css';
      case 'md':
        return 'markdown';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'dockerfile':
        return 'dockerfile';
      case 'sql':
        return 'sql';
      case 'rb':
        return 'ruby';
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
        return 'c_cpp';
      default:
        return 'plaintext';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade400),
              ),
            ],
          ),
        ),
      );
    }

    if (_content == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final language = _detectLanguage(widget.filePath);

    return Column(
      children: [
        // File header
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.filePath.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                language,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        // Code view
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: HighlightView(
                _content!,
                language: language,
                theme: isDark ? draculaTheme : githubTheme,
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
