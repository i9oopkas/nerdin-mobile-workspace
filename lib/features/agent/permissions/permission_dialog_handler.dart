import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_dialog.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_providers.dart';

/// A non-visual widget that watches for pending permission requests
/// and automatically shows the [PermissionDialog] when a new request
/// appears.
///
/// Place this widget near the root of the widget tree (inside
/// [Navigator] context) so it can show dialogs.
///
/// Requests are shown one at a time — the next request is shown only
/// after the previous dialog is dismissed.
class PermissionDialogHandler extends ConsumerStatefulWidget {
  final Widget child;

  const PermissionDialogHandler({super.key, required this.child});

  @override
  ConsumerState<PermissionDialogHandler> createState() =>
      _PermissionDialogHandlerState();
}

class _PermissionDialogHandlerState
    extends ConsumerState<PermissionDialogHandler> {
  /// Track which request ID was last shown to avoid re-showing.
  String? _lastShownRequestId;

  /// Whether a dialog is currently being displayed.
  bool _isShowingDialog = false;

  @override
  Widget build(BuildContext context) {
    final pendingRequests = ref.watch(pendingPermissionRequestsProvider);

    // If there are pending requests and we're not currently showing a dialog
    // and we haven't shown this request yet
    if (pendingRequests.isNotEmpty && !_isShowingDialog) {
      final request = pendingRequests.first;
      if (request.id != _lastShownRequestId) {
        _lastShownRequestId = request.id;
        _showDialog(request.id);
      }
    }

    return widget.child;
  }

  void _showDialog(String requestId) {
    // Get the request from the current state (it should still be there)
    final requests = ref.read(pendingPermissionRequestsProvider);
    final request = requests.where((r) => r.id == requestId).firstOrNull;
    if (request == null) return;

    _isShowingDialog = true;

    // Use WidgetsBinding to ensure we're in a proper context for showDialog
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await PermissionDialog.show(context, request);

      if (!mounted) return;
      _isShowingDialog = false;

      // Trigger a rebuild so the next pending request (if any) gets shown
      setState(() {});
    });
  }
}
