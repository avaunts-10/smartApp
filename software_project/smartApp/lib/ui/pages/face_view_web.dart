import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

Widget buildFaceView(
  String url,
  void Function(Map<String, dynamic> message)? onMessage,
) {
  return _FaceViewWeb(url: url, onMessage: onMessage);
}

int _seq = 0;

class _FaceViewWeb extends StatefulWidget {
  const _FaceViewWeb({required this.url, this.onMessage});

  final String url;
  final void Function(Map<String, dynamic> message)? onMessage;

  @override
  State<_FaceViewWeb> createState() => _FaceViewWebState();
}

class _FaceViewWebState extends State<_FaceViewWeb> {
  late final String _viewType;
  html.EventListener? _listener;

  @override
  void initState() {
    super.initState();
    _viewType = 'face-view-${_seq++}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final el = html.IFrameElement()
        ..src = widget.url
        ..allow = 'camera;microphone'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return el;
    });

    if (widget.onMessage != null) {
      _listener = (html.Event event) {
        final data = (event as html.MessageEvent).data;
        if (data is Map && data['source'] == 'face') {
          widget.onMessage!(Map<String, dynamic>.from(data));
        }
      };
      html.window.addEventListener('message', _listener);
    }
  }

  @override
  void dispose() {
    if (_listener != null) {
      html.window.removeEventListener('message', _listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
