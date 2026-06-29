import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_providers.dart';
import 'package:nerdin_mobile_workspace/features/agent/ui/agent_tab.dart';
import 'package:nerdin_mobile_workspace/features/chat/chat_tab.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/code_editor_tab.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/workspace_providers.dart';

/// MD3 NavigationRail — replaces the old VS Code-style ActivityBar.
///
/// Shows destinations for Chat, Agent, Files, Search, Git, and Settings.
/// Selecting Chat/Agent switches the active tab in MainArea.
/// Selecting Files/Search/Git opens the SidePanel overlay with the
/// corresponding panel content.
/// Selecting Settings opens the Zen API key dialog.
class ActivityBar extends ConsumerWidget {
  const ActivityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTabId = ref.watch(activeTabIdProvider);
    final activePanel = ref.watch(activeSidePanelProvider);
    final sidePanelOpen = ref.watch(sidePanelOpenProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final selectedIndex = _resolveIndex(activeTabId, activePanel, sidePanelOpen);

    DebugLogger.info('ActivityBar built', scope: 'workspace/activity');

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) =>
          _onDestinationSelected(index, ref, context),
      labelType: NavigationRailLabelType.all,
      minWidth: 56,
      groupAlignment: -0.3,
      backgroundColor: colorScheme.surfaceContainerLow,
      indicatorColor: colorScheme.secondaryContainer,
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Icon(
          Icons.code_rounded,
          size: 28,
          color: colorScheme.primary,
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: Text('Chat'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.smart_toy_outlined),
          selectedIcon: Icon(Icons.smart_toy),
          label: Text('Agent'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: Text('Files'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.search),
          label: Text('Search'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.source),
          label: Text('Git'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }

  /// Resolve which navigation index is currently selected.
  int? _resolveIndex(
      String activeTabId, SidePanelTab activePanel, bool sidePanelOpen) {
    if (sidePanelOpen) {
      switch (activePanel) {
        case SidePanelTab.explorer:
          return 2;
        case SidePanelTab.search:
          return 3;
        case SidePanelTab.git:
          return 4;
        case SidePanelTab.agent:
        case SidePanelTab.extensions:
          break;
      }
    }
    if (activeTabId == 'chat') return 0;
    if (activeTabId == 'agent') return 1;
    return null;
  }

  void _onDestinationSelected(int index, WidgetRef ref, BuildContext context) {
    final labels = ['Chat', 'Agent', 'Files', 'Search', 'Git', 'Settings'];
    DebugLogger.navigation('Tab selected', scope: 'workspace/nav', data: {'tab': labels[index]});
    switch (index) {
      case 0:
        _openChatTab(ref);
        ref.read(sidePanelOpenProvider.notifier).state = false;
      case 1:
        _openAgentTab(ref);
        ref.read(sidePanelOpenProvider.notifier).state = false;
      case 2:
        ref.read(activeSidePanelProvider.notifier).state = SidePanelTab.explorer;
        ref.read(sidePanelOpenProvider.notifier).state = true;
      case 3:
        ref.read(activeSidePanelProvider.notifier).state = SidePanelTab.search;
        ref.read(sidePanelOpenProvider.notifier).state = true;
      case 4:
        ref.read(activeSidePanelProvider.notifier).state = SidePanelTab.git;
        ref.read(sidePanelOpenProvider.notifier).state = true;
      case 5:
        _showZenSettings(context, ref);
    }
  }

  void _openChatTab(WidgetRef ref) {
    final tabs = ref.read(openTabsProvider);
    if (tabs.any((t) => t.id == 'chat')) {
      ref.read(activeTabIdProvider.notifier).state = 'chat';
      return;
    }
    ref.read(openTabsProvider.notifier).resetTo(
      WorkspaceTab(
        id: 'chat',
        title: 'Chat',
        icon: Icons.chat_bubble_outlined,
        builder: (_) => const ChatTab(),
        closable: false,
      ),
    );
  }

  void _openAgentTab(WidgetRef ref) {
    final tabs = ref.read(openTabsProvider);
    if (tabs.any((t) => t.id == 'agent')) {
      ref.read(activeTabIdProvider.notifier).state = 'agent';
      return;
    }
    ref.read(openTabsProvider.notifier).open(
      WorkspaceTab(
        id: 'agent',
        title: 'Agent',
        icon: Icons.smart_toy_outlined,
        builder: (_) => const AgentTab(),
        closable: false,
      ),
    );
  }

  void _showZenSettings(BuildContext context, WidgetRef ref) {
    final zen = ref.read(zenConfigProvider);
    final controller = TextEditingController(text: zen.apiKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LLM Provider: Zen API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Key (from opencode.ai/auth):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'zen-...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Text(
              'Default model: ${zen.defaultModel}\n'
              'Base URL: ${zen.baseUrl}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final key = controller.text.trim();
              ref.read(zenConfigProvider.notifier).updateApiKey(
                    key.isEmpty ? null : key,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
