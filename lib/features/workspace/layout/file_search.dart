import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

enum _FileFilter { all, dart, kotlin, python, go, rust, tsjs, web, config, shell }

Set<String> _extensionsFor(_FileFilter filter) {
  switch (filter) {
    case _FileFilter.all:
      return {
        '.dart', '.kt', '.kts', '.py', '.go', '.rs',
        '.js', '.jsx', '.ts', '.tsx',
        '.html', '.css', '.xml',
        '.yaml', '.yml', '.json', '.toml', '.cfg', '.ini',
        '.gradle', '.properties', '.env', '.gitignore',
        '.sh', '.bash',
      };
    case _FileFilter.dart:
      return {'.dart'};
    case _FileFilter.kotlin:
      return {'.kt', '.kts'};
    case _FileFilter.python:
      return {'.py'};
    case _FileFilter.go:
      return {'.go'};
    case _FileFilter.rust:
      return {'.rs'};
    case _FileFilter.tsjs:
      return {'.js', '.jsx', '.ts', '.tsx'};
    case _FileFilter.web:
      return {'.html', '.css', '.xml'};
    case _FileFilter.config:
      return {
        '.yaml', '.yml', '.json', '.toml', '.cfg', '.ini',
        '.gradle', '.properties', '.env', '.gitignore',
      };
    case _FileFilter.shell:
      return {'.sh', '.bash'};
  }
}

class FileSearch extends StatefulWidget {
  final ValueChanged<String>? onFileTap;

  const FileSearch({super.key, this.onFileTap});

  @override
  State<FileSearch> createState() => _FileSearchState();
}

class _FileSearchState extends State<FileSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  List<_SearchResult> _results = [];
  bool _isSearching = false;
  bool _showDebounceIndicator = false;
  String? _error;
  int? _fileCount;

  bool _useRegex = false;
  bool _caseSensitive = false;
  _FileFilter _selectedFilter = _FileFilter.all;

  static const _skipDirs = <String>{
    'node_modules', '.git', 'build', '.dart_tool', '.pub-cache',
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounceTimer?.cancel();
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _showDebounceIndicator = false;
        _error = null;
        _fileCount = null;
      });
      return;
    }

    setState(() => _showDebounceIndicator = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  void _triggerSearch() {
    _debounceTimer?.cancel();
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      _runSearch(query);
    }
  }

  Future<void> _runSearch(String query) async {
    DebugLogger.info('Search: "$query" filter=${_selectedFilter.name}', scope: 'workspace/search');
    setState(() {
      _isSearching = true;
      _showDebounceIndicator = false;
      _error = null;
    });

    try {
      final results = await _search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _fileCount = results.map((r) => r.path).toSet().length;
        });
      }
      DebugLogger.info('Search found ${results.length} results', scope: 'workspace/search');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _error = 'Search error: $e';
        });
      }
    }
  }

  bool _isTextFile(String name, Set<String> allowedExts) {
    if (_selectedFilter == _FileFilter.all && name == 'Dockerfile') {
      return true;
    }
    final dot = name.lastIndexOf('.');
    if (dot == -1) return false;
    return allowedExts.contains(name.substring(dot));
  }

  Future<List<_SearchResult>> _search(String query) async {
    final results = <_SearchResult>[];
    final root = Directory.current;

    RegExp? regex;
    if (_useRegex) {
      try {
        regex = RegExp(query, caseSensitive: _caseSensitive);
      } catch (e) {
        setState(() => _error = 'Invalid regex: $e');
        return [];
      }
    }

    final allowedExts = _extensionsFor(_selectedFilter);
    await _searchRecursive(root, query, regex, results, 0, {}, allowedExts);
    return results;
  }

  Future<void> _searchRecursive(
    Directory dir,
    String query,
    RegExp? regex,
    List<_SearchResult> results,
    int depth,
    Set<String> visited,
    Set<String> allowedExts,
  ) async {
    if (depth > 20 || results.length >= 200) return;

    final resolved = dir.resolveSymbolicLinksSync();
    if (!visited.add(resolved)) return;

    List<FileSystemEntity> entities;
    try {
      entities = dir.listSync();
    } catch (_) {
      return;
    }

    for (final entity in entities) {
      if (results.length >= 200) break;

      final name = entity.uri.pathSegments.last;

      if (entity is Directory) {
        if (name.startsWith('.') || _skipDirs.contains(name)) continue;
        await _searchRecursive(
          Directory(entity.path),
          query,
          regex,
          results,
          depth + 1,
          visited,
          allowedExts,
        );
      } else if (entity is File) {
        if (!_isTextFile(name, allowedExts)) continue;

        try {
          final lines = await entity.readAsLines();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            bool matches;

            if (regex != null) {
              matches = regex.hasMatch(line);
            } else if (_caseSensitive) {
              matches = line.contains(query);
            } else {
              matches = line.toLowerCase().contains(query.toLowerCase());
            }

            if (matches) {
              final contextBefore = <String>[];
              final contextAfter = <String>[];
              if (i > 0) {
                contextBefore.add(lines[i - 1]);
              }
              if (i + 1 < lines.length) {
                contextAfter.add(lines[i + 1]);
              }

              results.add(_SearchResult(
                path: entity.path,
                lineNumber: i + 1,
                line: line,
                contextBefore: contextBefore,
                contextAfter: contextAfter,
              ));
              if (results.length >= 200) break;
            }
          }
        } catch (_) {
          // Skip unreadable/binary files
        }
      }
    }
  }

  void _clearQuery() {
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildSearchBar(colorScheme),
        _buildFilterChips(colorScheme),
        const Divider(height: 1),
        Expanded(
          child: _buildBody(colorScheme),
        ),
      ],
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme) {
    const filters = _FileFilter.values;
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final filter in filters)
            _buildFilterChip(filter, colorScheme),
        ],
      ),
    );
  }

  Widget _buildFilterChip(_FileFilter filter, ColorScheme colorScheme) {
    final selected = filter == _selectedFilter;
    final label = switch (filter) {
      _FileFilter.all => 'All',
      _FileFilter.dart => 'Dart',
      _FileFilter.kotlin => 'Kotlin',
      _FileFilter.python => 'Python',
      _FileFilter.go => 'Go',
      _FileFilter.rust => 'Rust',
      _FileFilter.tsjs => 'TS/JS',
      _FileFilter.web => 'Web',
      _FileFilter.config => 'Config',
      _FileFilter.shell => 'Shell',
    };

    return Padding(
      padding: const EdgeInsets.only(right: 4),
        child: GestureDetector(
          onTap: () {
            DebugLogger.info('Search filter: ${filter.name}', scope: 'workspace/search');
            setState(() => _selectedFilter = filter);
            _triggerSearch();
          },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() => _useRegex = !_useRegex);
              _triggerSearch();
            },
            icon: Text(
              '.*',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: _useRegex ? FontWeight.bold : FontWeight.normal,
                color: _useRegex
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'Use regex',
          ),
          IconButton(
            onPressed: () {
              setState(() => _caseSensitive = !_caseSensitive);
              _triggerSearch();
            },
            icon: Text(
              'Aa',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: _caseSensitive ? FontWeight.bold : FontWeight.normal,
                color: _caseSensitive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'Case sensitive',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search files...',
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
                prefixIcon: _showDebounceIndicator
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Icon(Icons.search, size: 14, color: colorScheme.onSurfaceVariant),
                prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                suffixIcon: _controller.text.isNotEmpty
                    ? GestureDetector(
                        onTap: _clearQuery,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isSearching) {
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

    final query = _controller.text.trim();

    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Type a search query to find files',
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

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No results for "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '${_results.length} results in $_fileCount ${_fileCount == 1 ? 'file' : 'files'}',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: _results.length,
            itemBuilder: (context, index) =>
                _buildResultTile(_results[index], colorScheme),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(
    _SearchResult result,
    ColorScheme colorScheme,
  ) {
    final shortPath = _shortPath(result.path);
    final line = result.line;
    final query = _controller.text.trim();

    final spans = <TextSpan>[];

    if (_useRegex) {
      try {
        final re = RegExp(query, caseSensitive: _caseSensitive);
        int start = 0;
        for (final match in re.allMatches(line)) {
          if (match.start > start) {
            spans.add(TextSpan(text: line.substring(start, match.start)));
          }
          spans.add(TextSpan(
            text: line.substring(match.start, match.end),
            style: TextStyle(
              backgroundColor: Colors.yellow.withValues(alpha: 0.4),
              color: colorScheme.onSurface,
            ),
          ));
          start = match.end;
        }
        if (start < line.length) {
          spans.add(TextSpan(text: line.substring(start)));
        }
      } catch (_) {
        spans.add(TextSpan(text: line));
      }
    } else if (_caseSensitive) {
      int start = 0;
      while (true) {
        final idx = line.indexOf(query, start);
        if (idx == -1) {
          spans.add(TextSpan(text: line.substring(start)));
          break;
        }
        if (idx > start) {
          spans.add(TextSpan(text: line.substring(start, idx)));
        }
        spans.add(TextSpan(
          text: line.substring(idx, idx + query.length),
          style: TextStyle(
            backgroundColor: Colors.yellow.withValues(alpha: 0.4),
            color: colorScheme.onSurface,
          ),
        ));
        start = idx + query.length;
      }
    } else {
      final lowerLine = line.toLowerCase();
      final lowerQuery = query.toLowerCase();
      int start = 0;
      while (true) {
        final idx = lowerLine.indexOf(lowerQuery, start);
        if (idx == -1) {
          spans.add(TextSpan(text: line.substring(start)));
          break;
        }
        if (idx > start) {
          spans.add(TextSpan(text: line.substring(start, idx)));
        }
        spans.add(TextSpan(
          text: line.substring(idx, idx + query.length),
          style: TextStyle(
            backgroundColor: Colors.yellow.withValues(alpha: 0.4),
            color: colorScheme.onSurface,
          ),
        ));
        start = idx + query.length;
      }
    }

    return InkWell(
      onTap: () => widget.onFileTap?.call(result.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$shortPath:${result.lineNumber}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            if (result.contextBefore.isNotEmpty)
              ...result.contextBefore.map((ctxLine) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      ctxLine,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            const SizedBox(height: 1),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface,
                ),
                children: spans,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (result.contextAfter.isNotEmpty)
              ...result.contextAfter.map((ctxLine) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      ctxLine,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _shortPath(String path) {
    final root = Directory.current.path;
    if (path.startsWith(root)) {
      return path.substring(root.length + 1);
    }
    return path;
  }
}

class _SearchResult {
  final String path;
  final int lineNumber;
  final String line;
  final List<String> contextBefore;
  final List<String> contextAfter;

  const _SearchResult({
    required this.path,
    required this.lineNumber,
    required this.line,
    this.contextBefore = const [],
    this.contextAfter = const [],
  });
}
