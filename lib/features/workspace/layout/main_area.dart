import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/bottom_bar.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/bottom_bar_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';

/// The main content area of the workspace layout.
///
/// Shows a horizontal tab bar at the top when tabs are open,
/// the active tab's content below the bar, and optionally a
/// [BottomBar] at the bottom when the active tab supports
/// text input (chat / agent).
class MainArea extends ConsumerWidget {
  const MainArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final openTabs = ref.watch(openTabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);
    final showBottomBar = ref.watch(bottomBarVisibleProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Tab bar — visible when at least one tab is open
          if (openTabs.isNotEmpty)
            _TabBar(
              tabs: openTabs,
              activeTabId: activeTabId,
              onSelect: (id) =>
                  ref.read(activeTabIdProvider.notifier).state = id,
              onClose: (id) =>
                  ref.read(openTabsProvider.notifier).close(id),
              colorScheme: colorScheme,
            ),
          // Content area
          Expanded(
            child: _resolveContent(openTabs, activeTabId, context),
          ),
          // Bottom bar — visible for chat/agent tabs
          if (showBottomBar) const BottomBar(),
        ],
      ),
    );
  }

  Widget _resolveContent(
    List<WorkspaceTab> openTabs,
    String activeTabId,
    BuildContext context,
  ) {
    // No tabs → welcome state (shouldn't normally happen)
    if (openTabs.isEmpty) {
      return const _EmptyState();
    }

    // Active tab found → build its content
    final activeTab =
        openTabs.where((t) => t.id == activeTabId).firstOrNull;
    if (activeTab != null) return activeTab.builder(context);

    // Fallback: show first tab
    return openTabs.first.builder(context);
  }
}

/// Empty state when no tabs are open.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Open a file or start a chat',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// A horizontal strip of tab items at the top of the main area.
class _TabBar extends StatelessWidget {
  final List<WorkspaceTab> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final ColorScheme colorScheme;

  const _TabBar({
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = tab.id == activeTabId;
          return GestureDetector(
            onTap: () => onSelect(tab.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 14,
                      color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    tab.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (tab.closable) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onClose(tab.id),
                      child: Icon(Icons.close, size: 14,
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
