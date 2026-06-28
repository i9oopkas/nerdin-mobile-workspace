import 'dart:async';
import 'dart:typed_data';

// TODO: iOS platform APIs deleted; restore when iOS directory is re-added.
/// Streams paste payloads delivered by the native iOS text input bridge.
class IosNativePasteService {
  IosNativePasteService._();

  /// Shared singleton for the app-owned iOS paste bridge.
  static final IosNativePasteService instance = IosNativePasteService._();

  final StreamController<IosNativePastePayload> _pasteController =
      StreamController<IosNativePastePayload>.broadcast();

  /// Emits payloads when the native iOS text input view handles a paste.
  Stream<IosNativePastePayload> get onPaste => _pasteController.stream;

  /// Asks the native bridge to read the current iOS pasteboard.
  Future<bool> requestPaste() async {
    return false;
  }
}

/// Represents a payload emitted by the native iOS paste bridge.
sealed class IosNativePastePayload {
  const IosNativePastePayload();

  factory IosNativePastePayload.fromMap(Map<dynamic, dynamic> map) {
    final kind = map['kind'] as String?;

    switch (kind) {
      case 'text':
        return IosNativeTextPaste((map['text'] as String?) ?? '');
      case 'images':
        final rawItems = map['items'] as List<dynamic>? ?? const [];
        final items = rawItems
            .whereType<Map<dynamic, dynamic>>()
            .map(IosNativeImagePasteItem.fromMap)
            .where((item) => item.data.isNotEmpty)
            .toList(growable: false);
        return IosNativeImagePaste(items);
      default:
        return const IosNativeUnsupportedPaste();
    }
  }
}

/// Plain text pasted through the native iOS menu.
final class IosNativeTextPaste extends IosNativePastePayload {
  const IosNativeTextPaste(this.text);

  final String text;
}

/// One or more pasted images from the native iOS menu.
final class IosNativeImagePaste extends IosNativePastePayload {
  const IosNativeImagePaste(this.items);

  final List<IosNativeImagePasteItem> items;
}

/// Unsupported or empty pasted content.
final class IosNativeUnsupportedPaste extends IosNativePastePayload {
  const IosNativeUnsupportedPaste();
}

/// A pasted image item from the native iOS bridge.
final class IosNativeImagePasteItem {
  const IosNativeImagePasteItem({required this.data, required this.mimeType});

  factory IosNativeImagePasteItem.fromMap(Map<dynamic, dynamic> map) {
    final data = switch (map['data']) {
      Uint8List bytes => bytes,
      List<int> bytes => Uint8List.fromList(bytes),
      _ => Uint8List(0),
    };

    return IosNativeImagePasteItem(
      data: data,
      mimeType: (map['mimeType'] as String?) ?? 'image/png',
    );
  }

  final Uint8List data;
  final String mimeType;
}
