import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which panel is shown in the side panel.
enum SidePanelTab { explorer, search, git, agent, extensions }

/// Currently selected side panel tab.
final activeSidePanelProvider = StateProvider<SidePanelTab>(
  (ref) => SidePanelTab.explorer,
);

/// Whether the side panel is open/visible.
final sidePanelOpenProvider = StateProvider<bool>((ref) => true);
