import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/workspace_providers.dart';

/// Left-side vertical icon column (Activity Bar) — VS Code style.
///
/// Controls which panel is shown in the [SidePanel]. The top section
/// contains workspace navigation icons; the bottom contains settings.
///
/// [onAgentTap] opens the Agent workspace tab (not just the side panel).
class ActivityBar extends ConsumerWidget {
  final VoidCallback? onAgentTap;

  const ActivityBar({super.key, this.onAgentTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePanel = ref.watch(activeSidePanelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    const iconSize = 22.0;

    return Container(
      width: 48,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Top section — workspace navigation
          _ActivityIcon(
            icon: Icons.folder_outlined,
            isActive: activePanel == SidePanelTab.explorer,
            tooltip: 'Explorer',
            colorScheme: colorScheme,
            size: iconSize,
            onTap: () => _selectPanel(ref, SidePanelTab.explorer),
          ),
          _ActivityIcon(
            icon: Icons.search,
            isActive: activePanel == SidePanelTab.search,
            tooltip: 'Search',
            colorScheme: colorScheme,
            size: iconSize,
            onTap: () => _selectPanel(ref, SidePanelTab.search),
          ),
          _ActivityIcon(
            icon: Icons.code_branch,
            isActive: activePanel == SidePanelTab.git,
            tooltip: 'Source Control',
            colorScheme: colorScheme,
            size: iconSize,
            onTap: () => _selectPanel(ref, SidePanelTab.git),
          ),
          _ActivityIcon(
            icon: Icons.smart_toy_outlined,
            isActive: activePanel == SidePanelTab.agent,
            tooltip: 'Agent',
            colorScheme: colorScheme,
            size: iconSize,
            onTap: () {
              _selectPanel(ref, SidePanelTab.agent);
              onAgentTap?.call();
            },
          ),
          _ActivityIcon(
            icon: Icons.extension_outlined,
            isActive: activePanel == SidePanelTab.extensions,
            tooltip: 'Extensions',
            colorScheme: colorScheme,
            size: iconSize,
            onTap: () => _selectPanel(ref, SidePanelTab.extensions),
          ),
          const Spacer(),
          // Bottom section — settings / Zen config
          _ActivityIcon(
            icon: Icons.settings_outlined,
            isActive: false,
            tooltip: 'Settings — LLM Provider',
            colorScheme: colorScheme,
            size: iconSize,
            onTap: () => _showSettingsDialog(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _selectPanel(WidgetRef ref, SidePanelTab tab) {
    ref.read(activeSidePanelProvider.notifier).state = tab;
    ref.read(sidePanelOpenProvider.notifier).state = true;
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
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

/// A single icon button in the activity bar.
class _ActivityIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final ColorScheme colorScheme;
  final double size;
  final VoidCallback onTap;

  const _ActivityIcon({
    required this.icon,
    required this.isActive,
    required this.tooltip,
    required this.colorScheme,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isActive ? colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Icon(
              icon,
              size: size,
              color: isActive
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
