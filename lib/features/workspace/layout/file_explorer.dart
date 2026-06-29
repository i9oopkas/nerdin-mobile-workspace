import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:path_provider/path_provider.dart';

/// A simple file tree widget for the side panel's Explorer tab.
///
/// Lists files and directories from a root path and allows expanding
/// folders. Tapping a file emits [onFileTap] so the caller can open
/// it in the editor tab.
class FileExplorer extends StatefulWidget {
  final ValueChanged<String>? onFileTap;

  const FileExplorer({super.key, this.onFileTap});

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  String? _rootPath;
  List<_FileEntry> _rootEntries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  Future<void> _loadRoot() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Try to find a "project" or "workspace" directory, or use documents root
      final root = Directory(dir.path);
      _rootPath = root.path;
      _rootEntries = await _listDirectory(root);
      DebugLogger.info('Directory loaded: $_rootPath, ${_rootEntries.length} items', scope: 'workspace/explorer');
    } catch (e) {
      // Fallback: try current directory
      try {
        final root = Directory.current;
        _rootPath = root.path;
        _rootEntries = await _listDirectory(root);
      } catch (e2) {
        _error = 'Could not load files: $e2';
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<_FileEntry>> _listDirectory(Directory dir) async {
    final entities = dir.listSync()..sort(_compareEntities);
    final entries = <_FileEntry>[];
    for (final entity in entities) {
      // Skip hidden files and common ignore dirs
      final name = entity.uri.pathSegments.last;
      if (name.startsWith('.') || name == 'node_modules' || name == '.dart_tool') {
        continue;
      }
      entries.add(_FileEntry(
        name: name,
        path: entity.path,
        isDirectory: entity is Directory,
      ));
    }
    return entries;
  }

  int _compareEntities(FileSystemEntity a, FileSystemEntity b) {
    // Directories first, then alphabetically
    final aIsDir = a is Directory;
    final bIsDir = b is Directory;
    if (aIsDir && !bIsDir) return -1;
    if (!aIsDir && bIsDir) return 1;
    return a.path.compareTo(b.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            _rootPath ?? '',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
        ..._rootEntries.map((entry) => _FileTreeTile(
              entry: entry,
              depth: 0,
              onFileTap: widget.onFileTap,
            )),
      ],
    );
  }
}

/// A single file/directory entry with metadata.
class _FileEntry {
  final String name;
  final String path;
  final bool isDirectory;

  const _FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });
}

/// An expandable tree tile for a file or directory.
class _FileTreeTile extends StatefulWidget {
  final _FileEntry entry;
  final int depth;
  final ValueChanged<String>? onFileTap;

  const _FileTreeTile({
    required this.entry,
    required this.depth,
    this.onFileTap,
  });

  @override
  State<_FileTreeTile> createState() => _FileTreeTileState();
}

class _FileTreeTileState extends State<_FileTreeTile> {
  bool _expanded = false;
  List<_FileEntry>? _children;
  bool _loadingChildren = false;

  Future<void> _toggleExpand() async {
    if (!widget.entry.isDirectory) {
      DebugLogger.info('File tapped: ${widget.entry.path}', scope: 'workspace/explorer');
      widget.onFileTap?.call(widget.entry.path);
      return;
    }

    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }

    if (_children != null) {
      DebugLogger.info('Directory expanded: ${widget.entry.path}', scope: 'workspace/explorer');
      setState(() => _expanded = true);
      return;
    }

    setState(() => _loadingChildren = true);
    try {
      final dir = Directory(widget.entry.path);
      final entities = dir.listSync()..sort(_compareEntities);
      final children = <_FileEntry>[];
      for (final entity in entities) {
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('.') || name == 'node_modules' || name == '.dart_tool') {
          continue;
        }
        children.add(_FileEntry(
          name: name,
          path: entity.path,
          isDirectory: entity is Directory,
        ));
      }
      _children = children;
    } catch (_) {
      _children = [];
    }
    DebugLogger.info('Directory expanded: ${widget.entry.path}', scope: 'workspace/explorer');
    if (mounted) {
      setState(() {
        _expanded = true;
        _loadingChildren = false;
      });
    }
  }

  int _compareEntities(FileSystemEntity a, FileSystemEntity b) {
    final aIsDir = a is Directory;
    final bIsDir = b is Directory;
    if (aIsDir && !bIsDir) return -1;
    if (!aIsDir && bIsDir) return 1;
    return a.path.compareTo(b.path);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDir = widget.entry.isDirectory;
    final indent = 16.0 + widget.depth * 16.0;

    final icon = isDir
        ? (_expanded ? Icons.folder_open_outlined : Icons.folder_outlined)
        : _getFileIcon(widget.entry.name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _toggleExpand,
            child: Padding(
              padding: EdgeInsets.only(
                left: indent,
                right: 8,
                top: 2,
                bottom: 2,
              ),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isDir
                          ? Colors.amber.shade400
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_loadingChildren)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded && _children != null)
          ..._children!.map((child) => _FileTreeTile(
                entry: child,
                depth: widget.depth + 1,
                onFileTap: widget.onFileTap,
              )),
      ],
    );
  }

  IconData _getFileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.svg')) {
      return Icons.image;
    }
    return Icons.insert_drive_file_outlined;
  }
}
