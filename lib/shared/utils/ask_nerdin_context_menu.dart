import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

import '../../features/chat/providers/chat_providers.dart';

const String _askNerdinLabel = 'Ask Nerdin';

bool get _canShowAskNerdinSelectionAction =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String? selectedTextFromEditableTextState(EditableTextState editableTextState) {
  final value = editableTextState.textEditingValue;
  final selection = value.selection;
  if (!selection.isValid ||
      selection.isCollapsed ||
      selection.end > value.text.length) {
    return null;
  }
  return selection.textInside(value.text);
}

List<ContextMenuButtonItem> withAskNerdinContextMenuItem({
  required List<ContextMenuButtonItem> items,
  required WidgetRef ref,
  required String? selectedText,
  required String? composerTargetId,
  required VoidCallback hideToolbar,
}) {
  DebugLogger.info('ask_nerdin_context_menu: accessed', scope: 'utils/general');
  final text = selectedText;
  if (!_canShowAskNerdinSelectionAction ||
      composerTargetId == null ||
      composerTargetId.isEmpty ||
      text == null ||
      text.trim().isEmpty) {
    return items;
  }

  return [
    ...items,
    ContextMenuButtonItem(
      label: _askNerdinLabel,
      onPressed: () {
        hideToolbar();
        ref
            .read(composerTextInsertionProvider.notifier)
            .insert(targetId: composerTargetId, text: text);
      },
    ),
  ];
}

Widget buildAskNerdinSelectionAreaContextMenu({
  required SelectableRegionState selectableRegionState,
  required WidgetRef ref,
  required String? selectedText,
  required String? composerTargetId,
}) {
  final defaultItems = selectableRegionState.contextMenuButtonItems;
  final items = withAskNerdinContextMenuItem(
    items: defaultItems,
    ref: ref,
    selectedText: selectedText,
    composerTargetId: composerTargetId,
    hideToolbar: () => selectableRegionState.hideToolbar(false),
  );

  if (identical(items, defaultItems)) {
    return AdaptiveTextSelectionToolbar.selectableRegion(
      selectableRegionState: selectableRegionState,
    );
  }

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: selectableRegionState.contextMenuAnchors,
    buttonItems: items,
  );
}
