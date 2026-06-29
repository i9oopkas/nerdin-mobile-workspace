import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/workspace_layout.dart';

/// Single-route GoRouter — no auth, no server, no ShellRoute.
///
/// WorkspaceLayout is self-contained — it manages all workspace tabs
/// (chat, agent, file editing) internally via Riverpod providers.
/// Router is only used for the initial app entry point.
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/chat',
    routes: [
      GoRoute(
        path: '/chat',
        builder: (context, state) => const WorkspaceLayout(),
      ),
    ],
    errorBuilder: (context, state) {
      return const Scaffold(
        body: Center(child: Text('Route not found — use /chat')),
      );
    },
  );

  DebugLogger.navigation('GoRouter initialized: /chat route', scope: 'router/init');
  return router;
});
