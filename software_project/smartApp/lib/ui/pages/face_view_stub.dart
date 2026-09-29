import 'package:flutter/material.dart';

Widget buildFaceView(
  String url,
  void Function(Map<String, dynamic> message)? onMessage,
) {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'The facial-recognition camera runs in the web app only.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
