import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_event.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/bottom_bar_providers.dart';

/// Bottom bar with model selector dropdown and text input field.
///
/// Shown when the active tab is "chat" or "agent". The send handler
/// is provided by the active tab via [sendMessageHandlerProvider].
class BottomBar extends ConsumerStatefulWidget {
  const BottomBar({super.key});

  @override
  ConsumerState<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<BottomBar> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final handler = ref.read(sendMessageHandlerProvider);
    if (handler == null) return;

    setState(() => _isSending = true);
    _controller.clear();

    try {
      await handler(text);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedModel = ref.watch(selectedModelProvider);
    final availableModelsAsync = ref.watch(availableModelsProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Model selector dropdown
              _ModelDropdown(
                selectedModel: selectedModel,
                asyncModels: availableModelsAsync,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              // Text input
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Send button
              SizedBox(
                height: 40,
                width: 40,
                child: IconButton(
                  onPressed: _isSending ? null : _handleSend,
                  icon: _isSending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(Icons.arrow_upward_rounded, size: 20),
                  color: colorScheme.onPrimary,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown button for selecting the active model.
class _ModelDropdown extends ConsumerWidget {
  final String selectedModel;
  final AsyncValue<List<ModelInfo>> asyncModels;
  final ColorScheme colorScheme;

  const _ModelDropdown({
    required this.selectedModel,
    required this.asyncModels,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine available model IDs
    final modelIds = asyncModels.whenOrNull(
          data: (models) => models.map((m) => m.id).toList(),
        ) ??
        <String>[];

    // Show "..." while loading, model ID when loaded
    final displayText = asyncModels.isLoading
        ? '…'
        : asyncModels.hasError
            ? 'offline'
            : _shortModelName(selectedModel);

    return PopupMenuButton<String>(
      tooltip: 'Select model',
      onSelected: (id) =>
          ref.read(selectedModelProvider.notifier).select(id),
      itemBuilder: (context) {
        if (modelIds.isEmpty) {
          return [
            PopupMenuItem(
              enabled: false,
              child: Text(
                asyncModels.isLoading ? 'Loading...' : 'No models found',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ];
        }
        return modelIds.map((id) {
          final isSelected = id == selectedModel;
          return PopupMenuItem<String>(
            value: id,
            child: Row(
              children: [
                if (isSelected)
                  Icon(Icons.check, size: 16, color: colorScheme.primary),
                if (isSelected) const SizedBox(width: 8),
                Text(
                  id,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _shortModelName(String modelId) {
    if (modelId.length <= 18) return modelId;
    return '…${modelId.substring(modelId.length - 16)}';
  }
}
