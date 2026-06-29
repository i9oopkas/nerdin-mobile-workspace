import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/chat/chat_tab.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';

/// Seeds the initial chat tab after app startup.
///
/// Uses `await Future<void>.delayed(Duration.zero)` to ensure it runs
/// after all widgets have been built and all pending microtasks have
/// completed. Avoids the '!_dirty' assertion that occurs when changing
/// provider state during the Flutter build phase.
final chatTabSeedProvider = FutureProvider<void>((ref) async {
  DebugLogger.info('chatTabSeedProvider: seeding chat tab', scope: 'chat/seed');
  await Future<void>.delayed(Duration.zero);

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

  debugPrint('chatSeedProvider: chat tab seeded');
});
