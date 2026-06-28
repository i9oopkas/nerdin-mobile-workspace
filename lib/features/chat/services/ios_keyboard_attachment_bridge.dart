import 'dart:async';

// TODO: iOS platform APIs deleted; restore when iOS directory is re-added.
class IosKeyboardAttachmentBridge {
  IosKeyboardAttachmentBridge._();

  static final IosKeyboardAttachmentBridge instance =
      IosKeyboardAttachmentBridge._();

  final StreamController<IosKeyboardAttachmentEvent> _events =
      StreamController<IosKeyboardAttachmentEvent>.broadcast();

  Stream<IosKeyboardAttachmentEvent> get events => _events.stream;

  Future<void> configure({
    required List<IosKeyboardAttachmentActionConfig> actions,
  }) {
    return Future<void>.value();
  }

  Future<bool> toggle({
    required List<IosKeyboardAttachmentActionConfig> actions,
  }) async {
    return false;
  }

  Future<void> hide() {
    return Future<void>.value();
  }
}

class IosKeyboardAttachmentActionConfig {
  const IosKeyboardAttachmentActionConfig({
    required this.id,
    required this.label,
    required this.sfSymbol,
    required this.section,
    this.subtitle,
    this.enabled = true,
    this.selected = false,
    this.dismissesKeyboard = true,
  });

  final String id;
  final String label;
  final String? subtitle;
  final String sfSymbol;
  final String section;
  final bool enabled;
  final bool selected;
  final bool dismissesKeyboard;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'label': label,
      'subtitle': subtitle,
      'sfSymbol': sfSymbol,
      'section': section,
      'enabled': enabled,
      'selected': selected,
      'dismissesKeyboard': dismissesKeyboard,
    };
  }

  // TODO: toPlatform() removed with Pigeon-generated types; restore when iOS dir is re-added.
}

sealed class IosKeyboardAttachmentEvent {
  const IosKeyboardAttachmentEvent();
}

final class IosKeyboardAttachmentAction extends IosKeyboardAttachmentEvent {
  const IosKeyboardAttachmentAction(this.id);

  final String id;
}

final class IosKeyboardAttachmentVisibilityChanged
    extends IosKeyboardAttachmentEvent {
  const IosKeyboardAttachmentVisibilityChanged({required this.visible});

  final bool visible;
}
