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
/// Uses [ref.listen] to avoid calling setState during build phase,
/// which would trigger the '!_dirty' assertion in Flutter.
class PermissionDialogHandler extends ConsumerStatefulWidget {
  final Widget child;

  const PermissionDialogHandler({super.key, required this.child});

  @override
  ConsumerState<PermissionDialogHandler> createState() =>
      _PermissionDialogHandlerState();
}

class _PermissionDialogHandlerState
    extends ConsumerState<PermissionDialogHandler> {
  bool _isShowingDialog = false;

  @override
  Widget build(BuildContext context) {
    // Listen for new pending requests — fires AFTER build completes
    ref.listen(pendingPermissionRequestsProvider, (_, pendingRequests) {
      if (pendingRequests.isNotEmpty && !_isShowingDialog) {
        _showDialog(pendingRequests.first.id);
      }
    });

    return widget.child;
  }

  void _showDialog(String requestId) {
    final requests = ref.read(pendingPermissionRequestsProvider);
    final request = requests.where((r) => r.id == requestId).firstOrNull;
    if (request == null) return;

    _isShowingDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await PermissionDialog.show(context, request);

      if (!mounted) return;
      _isShowingDialog = false;
      setState(() {});
    });
  }
}
