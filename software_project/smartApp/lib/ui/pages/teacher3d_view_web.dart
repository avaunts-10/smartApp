import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'teacher3d_view.dart';

Widget buildTeacher3dView(
  String url,
  void Function(Map<String, dynamic> message)? onMessage,
  Teacher3dController? controller,
) {
  return _Teacher3dViewWeb(url: url, onMessage: onMessage, controller: controller);
}

int _seq = 0;

class _Teacher3dViewWeb extends StatefulWidget {
  const _Teacher3dViewWeb({required this.url, this.onMessage, this.controller});

  final String url;
  final void Function(Map<String, dynamic> message)? onMessage;
  final Teacher3dController? controller;

  @override
  State<_Teacher3dViewWeb> createState() => _Teacher3dViewWebState();
}

class _Teacher3dViewWebState extends State<_Teacher3dViewWeb> {
  late final String _viewType;
  html.EventListener? _listener;
  html.IFrameElement? _frame;

  @override
  void initState() {
    super.initState();
    _viewType = 'teacher3d-view-${_seq++}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      _frame = html.IFrameElement()
        ..src = widget.url
        ..allow = 'microphone; autoplay'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      widget.controller?.attach((m) => _frame?.contentWindow?.postMessage(m, '*'));
      return _frame!;
    });

    if (widget.onMessage != null) {
      _listener = (html.Event event) {
        final data = (event as html.MessageEvent).data;
        if (data is Map && data['source'] == 'teacher3d') {
          widget.onMessage!(Map<String, dynamic>.from(data));
        }
      };
      html.window.addEventListener('message', _listener);
    }
  }

  @override
  void dispose() {
    widget.controller?.attach(null);
    if (_listener != null) {
      html.window.removeEventListener('message', _listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
