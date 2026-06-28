import 'dart:io';

/// Where a tool should execute.
enum ExecutionTarget {
  local('local'),
  termux('termux'),
  server('server');

  final String value;
  const ExecutionTarget(this.value);

  static ExecutionTarget? fromString(String s) =>
      ExecutionTarget.values.where((e) => e.value == s).firstOrNull;
}

/// Abstract interface for Termux file operations.
/// Implemented by [TermuxFileService] in the termux package.
abstract class TermuxFileBackend {
  Future<String> readFile(String path, {int? maxBytes});
  Future<void> writeFile(String path, String content, {String? mode, bool append});
}

/// Abstract interface for Termux command execution.
abstract class TermuxCommandBackend {
  Future<String> runCommand(String cmd, {String? workdir, int? timeout});
}

/// Container for available tool execution backends.
///
/// Passed to [createBuiltinTools] to wire up target-specific implementations.
class ToolBackends {
  final TermuxCommandBackend? termuxCommand;
  final TermuxFileBackend? termuxFile;

  const ToolBackends({this.termuxCommand, this.termuxFile});

  Set<ExecutionTarget> get availableTargets {
    final targets = <ExecutionTarget>{ExecutionTarget.local};
    if (termuxCommand != null || termuxFile != null) {
      targets.add(ExecutionTarget.termux);
    }
    return targets;
  }
}

/// The operation type used for permission checking.
/// Maps to the `action` field in PermissionRule.
enum ToolOperationType {
  read('read'),
  edit('edit'),
  grep('grep'),
  glob('glob'),
  runCommand('run_command');

  final String value;
  const ToolOperationType(this.value);
}

/// A tool available to the agent.
///
/// Combines the OpenAI tool definition format with a Dart handler
/// that performs the actual operation on a given [ExecutionTarget].
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final ToolOperationType operationType;

  /// Handler function that performs the tool's work on a given target.
  ///
  /// Takes the parsed arguments map and the chosen [ExecutionTarget],
  /// returns a string result (the observation sent back to the LLM).
  final Future<String> Function(Map<String, dynamic> args, ExecutionTarget target) handler;

  /// Whether this tool accesses file system paths that should be
  /// checked for workspace boundaries.
  final bool isFileSystemTool;

  /// The default [ExecutionTarget] when the LLM does not specify one.
  final ExecutionTarget defaultTarget;

  /// The set of [ExecutionTarget]s this tool supports.
  final List<ExecutionTarget> supportedTargets;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.operationType,
    required this.handler,
    required this.defaultTarget,
    required this.supportedTargets,
    this.isFileSystemTool = true,
  });

  /// The input schema augmented with a `target` parameter when
  /// multiple execution targets are supported.
  Map<String, dynamic> get effectiveInputSchema {
    if (supportedTargets.length <= 1) return inputSchema;

    final properties = Map<String, dynamic>.from(
        inputSchema['properties'] as Map? ?? {});
    properties['target'] = {
      'type': 'string',
      'enum': supportedTargets.map((t) => t.value).toList(),
      'description':
          'Execution target: ${supportedTargets.map((t) => t.value).join(", ")}. '
          'Default: ${defaultTarget.value}',
    };
    return {
      ...inputSchema,
      'properties': properties,
    };
  }

  /// Convert to OpenAI tool format for the API request.
  Map<String, dynamic> toOpenAiTool() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': effectiveInputSchema,
        },
      };

  /// Extract the resource path(s) from the arguments for permission checking.
  ///
  /// Returns a list of path strings to check against PermissionRules.
  List<String> extractResources(Map<String, dynamic> args) {
    final resources = <String>[];
    if (args.containsKey('path') && args['path'] is String) {
      resources.add(args['path'] as String);
    }
    if (args.containsKey('include') && args['include'] is String) {
      resources.add(args['include'] as String);
    }
    if (args.containsKey('pattern') && args['pattern'] is String) {
      resources.add('pattern:${args['pattern']}');
    }
    return resources;
  }
}

/// ============================================================================
/// Local (dart:io) helper implementations
/// ============================================================================

Future<String> _localReadFile(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final stat = await file.stat();
    if (stat.size > 1024 * 1024) {
      final content = await file.readAsString();
      final truncated = content.substring(0, 1024 * 1024);
      return 'Warning: File is large (${_formatSize(stat.size)}). '
          'Showing first 1MB:\n\n$truncated';
    }

    final content = await file.readAsString();
    final lineCount = '\n'.allMatches(content).length + 1;
    return content.isEmpty
        ? 'File is empty: $path ($lineCount lines)'
        : content;
  } catch (e) {
    return 'Error reading file $path: $e';
  }
}

Future<String> _localWriteFile(String path, String content) async {
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    final stat = await file.stat();
    return 'Successfully wrote ${_formatSize(stat.size)} to $path';
  } catch (e) {
    return 'Error writing to $path: $e';
  }
}

Future<String> _localEditFile(String path, String oldStr, String newStr) async {
  try {
    final file = File(path);
    if (!await file.exists()) {
      return 'Error: File not found: $path';
    }

    final content = await file.readAsString();
    final index = content.indexOf(oldStr);
    if (index == -1) {
      return 'Error: Could not find old_string in $path. '
          'The text to replace was not found.';
    }

    final newContent = content.replaceFirst(oldStr, newStr);
    await file.writeAsString(newContent);

    final lineCount = '\n'.allMatches(newContent).length + 1;
    return 'Successfully applied edit to $path '
        '(${_formatSize(oldStr.length)} → ${_formatSize(newStr.length)}, $lineCount lines)';
  } catch (e) {
    return 'Error editing $path: $e';
  }
}

Future<String> _localGrep(String pattern, String? include, String path) async {
  try {
    final rootDir = Directory(path);
    if (!await rootDir.exists()) {
      return 'Error: Directory not found: $path';
    }

    final results = <String>[];
    final regex = RegExp(pattern, caseSensitive: true);
    int totalMatches = 0;

    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final filePath = entity.path;

      if (include != null && !filePath.contains(include)) continue;
      if (_shouldSkip(filePath)) continue;

      try {
        final lines = await entity.readAsLines();
        for (int i = 0; i < lines.length; i++) {
          if (regex.hasMatch(lines[i])) {
            results.add('${entity.path}:${i + 1}: ${lines[i].trimLeft()}');
            totalMatches++;
          }
        }
      } catch (_) {}

      if (results.length > 200) {
        results.add('... (truncated at 200 matches)');
        break;
      }
    }

    if (results.isEmpty) {
      return 'No matches found for pattern: $pattern in $path';
    }

    return 'Found $totalMatches matches for "$pattern" in $path:\n\n'
        '${results.join('\n')}';
  } catch (e) {
    return 'Error searching in $path: $e';
  }
}

Future<String> _localGlob(String pattern, String path) async {
  try {
    final rootDir = Directory(path);
    if (!await rootDir.exists()) {
      return 'Error: Directory not found: $path';
    }

    final matches = <String>[];
    final patternPieces = pattern.split('/');
    final hasRecursive = patternPieces.contains('**');

    await for (final entity in rootDir.list(
      recursive: hasRecursive,
      followLinks: false,
    )) {
      final relativePath = entity.path;

      if (_globMatch(relativePath, pattern)) {
        matches.add(relativePath);
      }

      if (matches.length > 500) {
        matches.add('... (truncated at 500 matches)');
        break;
      }
    }

    if (matches.isEmpty) {
      return 'No files matching "$pattern" in $path';
    }

    return 'Found ${matches.length} file(s) matching "$pattern" in $path:\n'
        '${matches.join('\n')}';
  } catch (e) {
    return 'Error searching for "$pattern" in $path: $e';
  }
}

Future<String> _localSearch(String query, String path, int maxResults) async {
  try {
    final rootDir = Directory(path);
    if (!await rootDir.exists()) {
      return 'Error: Directory not found: $path';
    }

    final results = <String>[];
    final queryLower = query.toLowerCase();

    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (_shouldSkip(entity.path)) continue;

      final name = entity.path.split('/').last;
      if (name.toLowerCase().contains(queryLower)) {
        results.add(entity.path);
      }

      if (results.length >= maxResults) {
        results.add('... (truncated at $maxResults results)');
        break;
      }
    }

    if (results.isEmpty) {
      return 'No files matching "$query" in $path';
    }

    return 'Found ${results.length} file(s) matching "$query" in $path:\n'
        '${results.join('\n')}';
  } catch (e) {
    return 'Error searching for "$query" in $path: $e';
  }
}

/// ============================================================================
/// Tool factory functions
/// ============================================================================

ToolDefinition _createReadFileTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'read_file',
    description: 'Read the contents of a file at the given path. '
        'Returns the file contents as text. For large files (>1MB), '
        'only the first 1MB is returned.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Absolute or relative path to the file to read',
        },
      },
      'required': ['path'],
    },
    operationType: ToolOperationType.read,
    defaultTarget: ExecutionTarget.local,
    supportedTargets: [ExecutionTarget.local, ExecutionTarget.termux],
    handler: (args, target) async {
      final path = args['path'] as String?;
      if (path == null || path.isEmpty) return 'Error: path is required';

      switch (target) {
        case ExecutionTarget.local:
          return _localReadFile(path);
        case ExecutionTarget.termux:
          final backend = backends?.termuxFile;
          if (backend == null) {
            return 'Error: Termux backend not available. '
                'Connect to Termux daemon first, or omit target '
                '(defaults to local).';
          }
          final maxBytes = args['max_bytes'] as int?;
          return backend.readFile(path, maxBytes: maxBytes);
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

ToolDefinition _createWriteFileTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'write_file',
    description: 'Write content to a file at the given path. '
        'Creates parent directories if they don\'t exist. '
        'Overwrites existing files. Use edit_file for targeted changes.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Absolute or relative path to the file to write',
        },
        'content': {
          'type': 'string',
          'description': 'The full content to write to the file',
        },
      },
      'required': ['path', 'content'],
    },
    operationType: ToolOperationType.edit,
    defaultTarget: ExecutionTarget.local,
    supportedTargets: [ExecutionTarget.local, ExecutionTarget.termux],
    handler: (args, target) async {
      final path = args['path'] as String?;
      final content = args['content'] as String?;
      if (path == null || path.isEmpty) return 'Error: path is required';
      if (content == null) return 'Error: content is required';

      switch (target) {
        case ExecutionTarget.local:
          return _localWriteFile(path, content);
        case ExecutionTarget.termux:
          final backend = backends?.termuxFile;
          if (backend == null) {
            return 'Error: Termux backend not available. '
                'Connect to Termux daemon first, or omit target '
                '(defaults to local).';
          }
          final mode = args['mode'] as String?;
          final append = args['append'] as bool? ?? false;
          await backend.writeFile(path, content, mode: mode, append: append);
          return 'Successfully wrote ${content.length} bytes to $path';
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

ToolDefinition _createEditFileTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'edit_file',
    description: 'Perform a search-and-replace edit on a file. '
        'Replaces the FIRST occurrence of old_string with new_string. '
        'Use this for targeted changes instead of write_file when you '
        'only need to modify a specific section of a file.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Absolute or relative path to the file to edit',
        },
        'old_string': {
          'type': 'string',
          'description': 'The exact text to search for and replace',
        },
        'new_string': {
          'type': 'string',
          'description': 'The text to replace old_string with',
        },
      },
      'required': ['path', 'old_string', 'new_string'],
    },
    operationType: ToolOperationType.edit,
    defaultTarget: ExecutionTarget.local,
    supportedTargets: [ExecutionTarget.local],
    handler: (args, target) async {
      final path = args['path'] as String?;
      final oldString = args['old_string'] as String?;
      final newString = args['new_string'] as String?;

      if (path == null || path.isEmpty) return 'Error: path is required';
      if (oldString == null || oldString.isEmpty) return 'Error: old_string is required';
      if (newString == null) return 'Error: new_string is required';

      switch (target) {
        case ExecutionTarget.local:
          return _localEditFile(path, oldString, newString);
        case ExecutionTarget.termux:
          return 'Error: edit_file on Termux target is not yet supported. '
              'Use write_file with the full content instead.';
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

ToolDefinition _createGrepTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'grep',
    description: 'Search file contents for a regex pattern. '
        'Returns matching lines with file paths and line numbers. '
        'Useful for finding code patterns, function definitions, '
        'variable references, or any text across the codebase.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'pattern': {
          'type': 'string',
          'description': 'The regex pattern to search for',
        },
        'include': {
          'type': 'string',
          'description': 'Optional: only search files whose path contains this string',
        },
        'path': {
          'type': 'string',
          'description': 'Optional: directory to search in (default: current directory)',
        },
      },
      'required': ['pattern'],
    },
    operationType: ToolOperationType.grep,
    defaultTarget: ExecutionTarget.local,
    supportedTargets: [ExecutionTarget.local],
    isFileSystemTool: false,
    handler: (args, target) async {
      final pattern = args['pattern'] as String?;
      final include = args['include'] as String?;
      final path = args['path'] as String? ?? '.';

      if (pattern == null || pattern.isEmpty) return 'Error: pattern is required';

      switch (target) {
        case ExecutionTarget.local:
          return _localGrep(pattern, include, path);
        case ExecutionTarget.termux:
          return 'Error: grep on Termux target is not yet supported.';
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

ToolDefinition _createGlobTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'glob',
    description: 'Find files and directories matching a glob pattern. '
        'Supports * (single level), ** (recursive), and ? (single char). '
        'Useful for exploring the project structure and finding files.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'pattern': {
          'type': 'string',
          'description': 'Glob pattern to match (e.g., "**/*.dart", "lib/**")',
        },
        'path': {
          'type': 'string',
          'description': 'Optional: directory to search in (default: current directory)',
        },
      },
      'required': ['pattern'],
    },
    operationType: ToolOperationType.glob,
    defaultTarget: ExecutionTarget.local,
    supportedTargets: [ExecutionTarget.local],
    isFileSystemTool: false,
    handler: (args, target) async {
      final pattern = args['pattern'] as String?;
      final path = args['path'] as String? ?? '.';

      if (pattern == null || pattern.isEmpty) return 'Error: pattern is required';

      switch (target) {
        case ExecutionTarget.local:
          return _localGlob(pattern, path);
        case ExecutionTarget.termux:
          return 'Error: glob on Termux target is not yet supported.';
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

ToolDefinition _createSearchTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'search',
    description: 'Find files by name (case-insensitive partial match). '
        'Like running `find -name "*query*"`. Useful when you remember '
        'part of a filename but not its exact location.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The filename to search for (partial, case-insensitive)',
        },
        'path': {
          'type': 'string',
          'description': 'Optional: directory to search in (default: current directory)',
        },
        'max_results': {
          'type': 'number',
          'description': 'Optional: maximum number of results (default: 50)',
        },
      },
      'required': ['query'],
    },
    operationType: ToolOperationType.glob,
    defaultTarget: ExecutionTarget.local,
    supportedTargets: [ExecutionTarget.local],
    isFileSystemTool: false,
    handler: (args, target) async {
      final query = args['query'] as String?;
      final path = args['path'] as String? ?? '.';
      final maxResults = args['max_results'] as int? ?? 50;

      if (query == null || query.isEmpty) return 'Error: query is required';

      switch (target) {
        case ExecutionTarget.local:
          return _localSearch(query, path, maxResults);
        case ExecutionTarget.termux:
          return 'Error: search on Termux target is not yet supported.';
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

ToolDefinition _createRunCommandTool(ToolBackends? backends) {
  return ToolDefinition(
    name: 'run_command',
    description: 'Execute a shell command in the Termux environment. '
        'Use this to install packages, run scripts, compile code, '
        'manage files, or perform any shell operation. '
        'Returns stdout, stderr, and the final exit code.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'command': {
          'type': 'string',
          'description': 'The shell command to execute',
        },
        'workdir': {
          'type': 'string',
          'description': 'Working directory (default: home directory)',
        },
        'timeout': {
          'type': 'integer',
          'description': 'Timeout in seconds',
        },
      },
      'required': ['command'],
    },
    operationType: ToolOperationType.runCommand,
    defaultTarget: ExecutionTarget.termux,
    supportedTargets: [ExecutionTarget.termux],
    isFileSystemTool: false,
    handler: (args, target) async {
      final cmd = args['command'] as String?;
      if (cmd == null || cmd.isEmpty) return 'Error: "command" is required';

      switch (target) {
        case ExecutionTarget.local:
          return 'Error: run_command is not available on local target. '
              'Use target="termux" to run shell commands in Termux.';
        case ExecutionTarget.termux:
          final backend = backends?.termuxCommand;
          if (backend == null) {
            return 'Error: Termux backend not available. '
                'Connect to Termux daemon first.';
          }
          final workdir = args['workdir'] as String?;
          final timeout = args['timeout'] as int?;
          return backend.runCommand(cmd, workdir: workdir, timeout: timeout);
        case ExecutionTarget.server:
          return 'Error: Server execution not yet implemented';
      }
    },
  );
}

/// ============================================================================
/// Utility helpers
/// ============================================================================

/// Format bytes to human-readable size.
String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Check if a file path should be skipped (binary, .git, etc.).
bool _shouldSkip(String path) {
  final skipDirs = [
    '.git', '.dart_tool', '.pub-cache', 'build', '.idea',
    'node_modules', '.mypy_cache', '__pycache__',
  ];
  final skipExts = [
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.svg',
    '.ttf', '.otf', '.woff', '.woff2', '.eot',
    '.zip', '.tar', '.gz', '.bz2', '.7z', '.rar',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx',
    '.mp3', '.mp4', '.avi', '.mov', '.mkv',
    '.o', '.so', '.dylib', '.exe', '.dll',
    '.class', '.jar',
    '.lock', '.map',
  ];

  final segments = path.split('/');
  for (final dir in skipDirs) {
    if (segments.contains(dir)) return true;
  }

  final ext = path.split('.').last.toLowerCase();
  if (skipExts.contains('.$ext')) return true;

  return false;
}

/// Simple glob pattern matching.
///
/// Supports:
/// - `*` — matches any characters except `/`
/// - `**` — matches any characters including `/`
/// - `?` — matches a single character except `/`
bool _globMatch(String path, String pattern) {
  if (path.startsWith('./')) path = path.substring(2);
  if (pattern.startsWith('./')) pattern = pattern.substring(2);

  final regexStr = StringBuffer('^');
  int i = 0;
  while (i < pattern.length) {
    final c = pattern[i];
    if (c == '*') {
      if (i + 1 < pattern.length && pattern[i + 1] == '*') {
        regexStr.write('.*');
        if (i + 2 < pattern.length && pattern[i + 2] == '/') {
          i += 3;
          continue;
        }
        i += 2;
        continue;
      } else {
        regexStr.write('[^/]*');
      }
    } else if (c == '?') {
      regexStr.write('[^/]');
    } else if (c == '.') {
      regexStr.write('\\.');
    } else {
      regexStr.write(c);
    }
    i++;
  }
  regexStr.write('\$');

  return RegExp(regexStr.toString()).hasMatch(path);
}

/// Create all built-in tool definitions for the agent.
///
/// If [backends] is provided, tools that support Termux execution
/// will use the backends for non-local targets. Without backends,
/// tools fall back to local-only execution (and return error messages
/// if a Termux target is requested).
List<ToolDefinition> createBuiltinTools({ToolBackends? backends}) {
  return [
    _createReadFileTool(backends),
    _createWriteFileTool(backends),
    _createEditFileTool(backends),
    _createGrepTool(backends),
    _createGlobTool(backends),
    _createSearchTool(backends),
    _createRunCommandTool(backends),
  ];
}
