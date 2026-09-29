import 'package:flutter/material.dart';

import 'native_teacher_avatar.dart';
import 'teacher3d_view.dart';

/// On native platforms (no `dart.library.html`, so no iframe/WebGL) [url]'s
/// `gender` query param seeds a hand-drawn, on-device-TTS avatar instead.
Widget buildTeacher3dView(
  String url,
  void Function(Map<String, dynamic> message)? onMessage,
  Teacher3dController? controller,
) {
  final gender = Uri.tryParse(url)?.queryParameters['gender'] ?? 'female';
  return NativeTeacherAvatar(initialGender: gender, controller: controller);
}
