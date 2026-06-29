import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/activity_bar.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/side_panel.dart';
import 'package:nerdin_mobile_workspace/features/chat/chat_tab.dart';
import 'package:nerdin_mobile_workspace/features/agent/ui/agent_tab.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/code_editor_tab.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/workspace_providers.dart';

/// Top-level IDE layout.
///
/// MD3 NavigationRail on the left, SidePanel overlay on phone / inline on
/// tablet, and MainArea with tabs in the center.
class WorkspaceLayout extends ConsumerStatefulWidget {
  const WorkspaceLayout({super.key});

  @override
  ConsumerState<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class _WorkspaceLayoutState extends ConsumerState<WorkspaceLayout> {
  @override
  void initState() {
    super.initState();
    // Seed the initial chat tab after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedChatTab();
    });
  }

  void _seedChatTab() {
    final tabs = ref.read(openTabsProvider);
    if (tabs.isNotEmpty) return;
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

  void _openFileTab(String path) {
    final fileName = path.split('/').last;
    ref.read(sidePanelOpenProvider.notifier).state = false;
    ref.read(openTabsProvider.notifier).open(
      WorkspaceTab(
        id: 'file:$path',
        title: fileName,
        icon: Icons.code,
        builder: (_) => CodeEditorTab(filePath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sidePanelOpen = ref.watch(sidePanelOpenProvider);
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    const panelWidth = 280.0;

    if (isTablet) {
      return _buildTabletLayout(context, sidePanelOpen, panelWidth);
    } else {
      return _buildPhoneLayout(context, sidePanelOpen, panelWidth);
    }
  }

  Widget _buildTabletLayout(
    BuildContext context,
    bool sidePanelOpen,
    double panelWidth,
  ) {
    return Row(
      children: [
        const ActivityBar(),
        if (sidePanelOpen)
          SidePanel(width: panelWidth, onFileTap: _openFileTab),
        const Expanded(child: MainArea()),
      ],
    );
  }

  Widget _buildPhoneLayout(
    BuildContext context,
    bool sidePanelOpen,
    double panelWidth,
  ) {
    const navRailWidth = 72.0;

    return Stack(
      children: [
        Row(
          children: [
            const ActivityBar(),
            const Expanded(child: MainArea()),
          ],
        ),
        if (sidePanelOpen)
          GestureDetector(
            onTap: () =>
                ref.read(sidePanelOpenProvider.notifier).state = false,
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        AnimatedPositioned(
          left: sidePanelOpen ? navRailWidth : -panelWidth,
          top: 0,
          bottom: 0,
          width: panelWidth,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: SidePanel(width: panelWidth, onFileTap: _openFileTab),
        ),
      ],
    );
  }
}
