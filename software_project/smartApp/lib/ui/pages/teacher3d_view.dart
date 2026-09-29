import 'package:flutter/widgets.dart';

import 'teacher3d_view_stub.dart'
    if (dart.library.html) 'teacher3d_view_web.dart'
    if (dart.library.io) 'teacher3d_view_mobile.dart' as impl;

/// Lets the embedding screen talk to the avatar page: `ask()` sends a
/// question that the avatar answers out loud (the reply also arrives through
/// [Teacher3dView.onMessage] as `{type: 'answer', ...}`).
class Teacher3dController {
  void Function(Map<String, dynamic> message)? _send;
  void Function(String text)? _speak;
  void Function(String gender)? _onGenderChanged;

  /// True once the web view is mounted; false on platforms without the iframe.
  bool get isAttached => _send != null;

  void ask(String question) =>
      _send?.call({'type': 'ask', 'question': question});

  /// Switches the avatar's character: 'female' or 'male'.
  void setGender(String gender) {
    _send?.call({'type': 'setGender', 'gender': gender});
    _onGenderChanged?.call(gender);
  }

  /// Called by the platform view; not for screens.
  void attach(void Function(Map<String, dynamic>)? send) => _send = send;

  /// Speaks [text] out loud. No-op on web (the iframe speaks its own
  /// replies); the native avatar uses this to drive on-device TTS + lip-sync.
  void speak(String text) => _speak?.call(text);

  /// Called by the native avatar view; not for screens.
  void attachNative({
    void Function(String text)? speak,
    void Function(String gender)? onGenderChanged,
  }) {
    _speak = speak;
    _onGenderChanged = onGenderChanged;
  }
}

/// Embeds the backend's `/teacher3d` page (three.js avatar + AI chat) — as an
/// iframe on web, and in a native WebView on Android/iOS. Desktop platforms
/// show a short notice instead (see `teacher3d_view_mobile.dart`).
///
/// [onMessage] receives the page's `postMessage` events, e.g.
/// `{type: 'answer', question: ..., answer: ...}` or `{type: 'error', ...}`.
class Teacher3dView extends StatelessWidget {
  const Teacher3dView({
    super.key,
    required this.url,
    this.onMessage,
    this.controller,
  });

  final String url;
  final void Function(Map<String, dynamic> message)? onMessage;
  final Teacher3dController? controller;

  @override
  Widget build(BuildContext context) =>
      impl.buildTeacher3dView(url, onMessage, controller);
}
