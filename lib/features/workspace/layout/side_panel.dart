import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/file_explorer.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/workspace_providers.dart';

/// The collapsible side panel that shows context-appropriate content
/// based on the selected [SidePanelTab].
///
/// The panel itself is just the content container — its position and
/// animation are managed by [WorkspaceLayout] so it can behave as a
/// layout-embedded panel on tablets or an overlay on phones.
class SidePanel extends ConsumerWidget {
  final double width;
  final ValueChanged<String>? onFileTap;

  const SidePanel({super.key, required this.width, this.onFileTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePanel = ref.watch(activeSidePanelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(activePanel, colorScheme, ref),
          const Divider(height: 1),
          Expanded(
            child: _buildPanelContent(activePanel, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(SidePanelTab tab, ColorScheme colorScheme, WidgetRef ref) {
    final titles = <SidePanelTab, String>{
      SidePanelTab.explorer: 'Explorer',
      SidePanelTab.search: 'Search',
      SidePanelTab.git: 'Source Control',
      SidePanelTab.agent: 'Agent Log',
      SidePanelTab.extensions: 'Extensions',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titles[tab] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(sidePanelOpenProvider.notifier).state = false,
            child: Icon(
              Icons.close,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(SidePanelTab tab, ColorScheme colorScheme) {
    switch (tab) {
      case SidePanelTab.explorer:
        return FileExplorer(onFileTap: onFileTap);
      case SidePanelTab.search:
        return _PlaceholderPanel(
          icon: Icons.search,
          message: 'Search\n(coming in Phase 3)',
          colorScheme: colorScheme,
        );
      case SidePanelTab.git:
        return _PlaceholderPanel(
          icon: Icons.code_branch,
          message: 'Git\n(coming in Phase 3)',
          colorScheme: colorScheme,
        );
      case SidePanelTab.agent:
        return _PlaceholderPanel(
          icon: Icons.smart_toy_outlined,
          message: 'Agent Log\n(coming in Step 5)',
          colorScheme: colorScheme,
        );
      case SidePanelTab.extensions:
        return _PlaceholderPanel(
          icon: Icons.extension_outlined,
          message: 'Extensions\n(coming in Phase 3)',
          colorScheme: colorScheme,
        );
    }
  }
}

class _PlaceholderPanel extends StatelessWidget {
  final IconData icon;
  final String message;
  final ColorScheme colorScheme;

  const _PlaceholderPanel({
    required this.icon,
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
