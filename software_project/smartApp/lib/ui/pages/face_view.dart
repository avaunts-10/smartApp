import 'package:flutter/widgets.dart';

import 'face_view_stub.dart'
    if (dart.library.html) 'face_view_web.dart' as impl;

/// Embeds the backend's `/face` capture page (webcam + face-api.js) in an
/// iframe. Web only; on other platforms it shows a short notice.
///
/// [onMessage] receives the `postMessage` events the page emits, e.g.
/// `{type: 'attendance', student: {...}, status: 'present'}` or
/// `{type: 'enrolled', faceCount: 2}`.
class FaceView extends StatelessWidget {
  const FaceView({super.key, required this.url, this.onMessage});

  final String url;
  final void Function(Map<String, dynamic> message)? onMessage;

  @override
  Widget build(BuildContext context) => impl.buildFaceView(url, onMessage);
}
