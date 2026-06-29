import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_rules.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_providers.dart';

/// Dialog shown when the agent requests permission to perform an action.
///
/// Displays the action type, resources (paths/commands), and offers
/// the user options: Once, Always Session, Always (forever), Reject, Edit.
class PermissionDialog extends ConsumerStatefulWidget {
  final PermissionRequest request;

  const PermissionDialog({super.key, required this.request});

  /// Show the dialog and return the user's reply.
  static Future<PermissionReply?> show(
    BuildContext context,
    PermissionRequest request,
  ) {
    return showDialog<PermissionReply>(
      context: context,
      barrierDismissible: false, // Must make a choice
      builder: (context) => PermissionDialog(request: request),
    );
  }

  @override
  ConsumerState<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends ConsumerState<PermissionDialog> {
  bool _isEditing = false;
  late TextEditingController _editController;

  PermissionRequest get _request => widget.request;

  @override
  void initState() {
    super.initState();
    DebugLogger.auth('Permission dialog shown: ${_request.action} on ${_request.resources.join(", ")}', scope: 'permission/dialog');
    // Pre-fill edit field with the command (for run_command) or first resource
    final command = _request.metadata?['command'] as String? ??
        _request.resources.first;
    _editController = TextEditingController(text: command);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isEditing) {
      return _buildEditDialog(theme);
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getActionIcon(),
            size: 24,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getDialogTitle(),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getActionColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _request.action.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getActionColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resource(s) display
              if (_request.action == 'run_command') ...[
                Text(
                  'Command:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _request.metadata?['command'] as String? ??
                        _request.resources.first,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Geist Mono',
                      fontFamilyFallback: const ['monospace'],
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Resource:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final resource in _request.resources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        resource,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Geist Mono',
                          fontFamilyFallback: const ['monospace'],
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 16),

              // Description
              Text(
                _getDescription(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Reject
        TextButton(
          onPressed: () => _reply(PermissionReply.reject),
          child: const Text('Reject'),
        ),
        // Edit (only for run_command)
        if (_request.action == 'run_command')
          TextButton(
            onPressed: () {
              setState(() => _isEditing = true);
            },
            child: const Text('Edit'),
          ),
        const Spacer(),
        // Always (forever)
        TextButton(
          onPressed: () => _reply(PermissionReply.always),
          child: const Text('Always'),
        ),
        // Always (session)
        FilledButton.tonal(
          onPressed: () => _reply(PermissionReply.alwaysSession),
          child: const Text('Always Session'),
        ),
        // Once
        FilledButton(
          onPressed: () => _reply(PermissionReply.once),
          child: const Text('Once'),
        ),
      ],
    );
  }

  /// Edit mode dialog — user can modify the command before re-submission.
  Widget _buildEditDialog(ThemeData theme) {
    return AlertDialog(
      title: const Text('Edit Command'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modify the command and submit:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editController,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Geist Mono',
                fontFamilyFallback: const ['monospace'],
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _isEditing = false);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Reject original, return edited text
            _reply(PermissionReply.edit, editedInput: _editController.text);
          },
          child: const Text('Submit Edited'),
        ),
      ],
    );
  }

  void _reply(PermissionReply reply, {String? editedInput}) {
    DebugLogger.auth('User choice: $reply', scope: 'permission/dialog');
    ref.read(pendingPermissionRequestsProvider.notifier).reply(
          _request.id,
          reply,
          editedInput: editedInput,
        );
    Navigator.of(context).pop(reply);
  }

  IconData _getActionIcon() {
    switch (_request.action) {
      case 'run_command':
        return Icons.terminal_rounded;
      case 'read':
        return Icons.file_open_rounded;
      case 'edit':
        return Icons.edit_rounded;
      case 'delete_file':
        return Icons.delete_rounded;
      case 'external_directory':
        return Icons.folder_open_rounded;
      case 'network':
        return Icons.cloud_rounded;
      case 'doom_loop':
        return Icons.loop_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  Color _getActionColor() {
    switch (_request.action) {
      case 'run_command':
        return Colors.orange;
      case 'read':
        return Colors.blue;
      case 'edit':
        return Colors.teal;
      case 'delete_file':
        return Colors.red;
      case 'external_directory':
        return Colors.purple;
      case 'network':
        return Colors.indigo;
      case 'doom_loop':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getDialogTitle() {
    switch (_request.action) {
      case 'run_command':
        return 'Execute Command';
      case 'read':
        return 'Read File';
      case 'edit':
        return 'Edit File';
      case 'delete_file':
        return 'Delete File';
      case 'external_directory':
        return 'Access External Directory';
      case 'network':
        return 'Network Request';
      case 'doom_loop':
        return 'Repetitive Operation Detected';
      default:
        return 'Permission Request: ${_request.action}';
    }
  }

  String _getDescription() {
    switch (_request.action) {
      case 'run_command':
        return 'The agent wants to execute this shell command. '
            'Review the command carefully before allowing.';
      case 'delete_file':
        return 'The agent wants to permanently delete this file. '
            'This action cannot be undone.';
      case 'external_directory':
        return 'The agent wants to access a path outside the project directory.';
      case 'doom_loop':
        return 'The agent has made 3+ similar requests in a row. '
            'This may indicate the agent is stuck in a loop.';
      default:
        return 'Review the request carefully before allowing.';
    }
  }
}
