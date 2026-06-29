import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which panel is shown in the side panel.
enum SidePanelTab { explorer, search, git, agent, extensions }

// ── Active Side Panel Tab ─────────────────────────────────────

class ActiveSidePanelNotifier extends Notifier<SidePanelTab> {
  @override
  SidePanelTab build() => SidePanelTab.explorer;
}

final activeSidePanelProvider =
    NotifierProvider<ActiveSidePanelNotifier, SidePanelTab>(
  ActiveSidePanelNotifier.new,
);

// ── Side Panel Open State ─────────────────────────────────────

class SidePanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() => true;
}

final sidePanelOpenProvider =
    NotifierProvider<SidePanelOpenNotifier, bool>(
  SidePanelOpenNotifier.new,
);
