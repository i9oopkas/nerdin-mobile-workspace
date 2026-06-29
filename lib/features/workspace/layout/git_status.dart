import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

class GitStatus extends StatefulWidget {
  const GitStatus({super.key});

  @override
  State<GitStatus> createState() => _GitStatusState();
}

class _GitStatusState extends State<GitStatus> {
  String _branch = '';
  List<_GitFile> _files = [];
  String? _expandedFile;
  final _commitController = TextEditingController();
  String _diffContent = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _commitController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await Process.run('git', ['status', '--porcelain', '-b'],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode != 0) {
        throw Exception(result.stderr.toString().trim());
      }

      _parseStatus(result.stdout.toString());
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Git error: $e';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _parseStatus(String output) {
    final lines = const LineSplitter().convert(output.trim());
    if (lines.isEmpty) {
      _branch = '(no branch)';
      _files = [];
      return;
    }

    final branchLine = lines[0];
    if (branchLine.startsWith('## ')) {
      _branch = branchLine.substring(3).split('...')[0];
    } else {
      _branch = branchLine;
    }

    _files = [];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.length < 3) continue;

      if (line.startsWith('??')) {
        _files.add(_GitFile(
          path: line.substring(3),
          stagedStatus: ' ',
          workingStatus: '?',
        ));
      } else {
        _files.add(_GitFile(
          path: line.substring(3),
          stagedStatus: line[0],
          workingStatus: line[1],
        ));
      }
    }
    DebugLogger.info('Git status: branch=$_branch ${_files.length} changed', scope: 'workspace/git');
  }

  Future<String> _getDiff(String filePath) async {
    try {
      final result = await Process.run(
        'git',
        ['diff', '--unified=5', filePath],
        workingDirectory: Directory.current.path,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  void _toggleFile(String path) async {
    if (_expandedFile == path) {
      setState(() {
        _expandedFile = null;
        _diffContent = '';
      });
      return;
    }

    DebugLogger.info('Git diff shown: $path', scope: 'workspace/git');
    setState(() {
      _expandedFile = path;
      _diffContent = '';
    });

    final diff = await _getDiff(path);
    if (mounted) {
      setState(() => _diffContent = diff);
    }
  }

  Future<void> _commit() async {
    final message = _commitController.text.trim();
    DebugLogger.info('Git commit: ${message.length} chars', scope: 'workspace/git');
    if (message.isEmpty) return;

    try {
      await Process.run('git', ['add', '-A'],
        workingDirectory: Directory.current.path,
      );

      final result = await Process.run(
        'git',
        ['commit', '-m', message],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode != 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commit failed: ${result.stderr}',
                style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.red.shade400,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      _commitController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commit error: $e',
              style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildBranchHeader(colorScheme),
        const Divider(height: 1),
        Expanded(child: _buildBody(colorScheme)),
        const Divider(height: 1),
        _buildCommitBar(colorScheme),
      ],
    );
  }

  Widget _buildBranchHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.call_split, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _branch,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${_files.length}',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(fontSize: 12, color: Colors.red.shade400),
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No changes detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: _files.length,
        itemBuilder: (context, index) => _buildFileTile(_files[index], colorScheme),
      ),
    );
  }

  Widget _buildFileTile(_GitFile file, ColorScheme colorScheme) {
    final isExpanded = _expandedFile == file.path;
    final statusIcon = _statusIcon(file);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            DebugLogger.info('Git staged/unstaged: ${file.path}', scope: 'workspace/git');
            _toggleFile(file.path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  Text(statusIcon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.path,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded && _diffContent.isNotEmpty)
          _buildDiffView(colorScheme),
      ],
    );
  }

  Widget _buildDiffView(ColorScheme colorScheme) {
    final lines = const LineSplitter().convert(_diffContent);
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 32, right: 12, bottom: 4),
        child: Text(
          '(no diff content)',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 32, right: 12, bottom: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            _buildDiffLine(line, colorScheme),
        ],
      ),
    );
  }

  Widget _buildDiffLine(String line, ColorScheme colorScheme) {
    Color? bgColor;
    Color textColor = colorScheme.onSurface;

    if (line.startsWith('@@')) {
      textColor = Colors.cyan;
    } else if (line.startsWith('--- a/') || line.startsWith('+++ b/')) {
      textColor = colorScheme.onSurfaceVariant;
    } else if (line.startsWith('-')) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      textColor = Colors.red.shade300;
    } else if (line.startsWith('+')) {
      bgColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green.shade300;
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      child: Text(
        line,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: textColor,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildCommitBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commitController,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Commit message...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _commit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Commit',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusIcon(_GitFile file) {
    final s = file.stagedStatus;
    final w = file.workingStatus;
    if (w == '?') return '❓';
    if (s == 'M' || w == 'M') return '✏️';
    if (s == 'A' || w == 'A') return '➕';
    if (s == 'D' || w == 'D') return '🗑️';
    if (s == 'R' || w == 'R') return '🔀';
    return '✏️';
  }
}

class _GitFile {
  final String path;
  final String stagedStatus;
  final String workingStatus;

  const _GitFile({
    required this.path,
    required this.stagedStatus,
    required this.workingStatus,
  });
}
