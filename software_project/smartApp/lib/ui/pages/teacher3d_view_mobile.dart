import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'teacher3d_view.dart';

/// Picked by the `dart.library.io` branch of the conditional import — i.e.
/// every non-web platform (mobile AND desktop). Mobile gets a real WebView;
/// desktop (no bundled WebView plugin here) falls back to the same short
/// notice `teacher3d_view_stub.dart` shows.
Widget buildTeacher3dView(
  String url,
  void Function(Map<String, dynamic> message)? onMessage,
  Teacher3dController? controller,
) {
  if (Platform.isAndroid || Platform.isIOS) {
    return _Teacher3dViewMobile(
        url: url, onMessage: onMessage, controller: controller);
  }
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'The 3D AI teacher runs in the web app or the mobile app only.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

const _channelName = 'Teacher3dChannel';

// main.js emits with `parent.postMessage({source:'teacher3d', ...}, '*')`,
// written for the web build where the page sits in an iframe and `parent` is
// the embedding Flutter web page. In a WebView there's no real parent frame,
// so `parent` resolves to `window` itself and that call would just fire a
// 'message' event nobody listens for. This override forwards it to our
// JavaScriptChannel instead, keeping the same {source:'teacher3d', type, ...}
// payload shape teacher3d_view_web.dart already hands to `onMessage`.
const _bridgeScript = '''
(function() {
  if (window.__teacher3dBridged) return;
  window.__teacher3dBridged = true;
  window.postMessage = function(data) {
    try { $_channelName.postMessage(JSON.stringify(data)); } catch (e) {}
  };
})();
''';

class _Teacher3dViewMobile extends StatefulWidget {
  const _Teacher3dViewMobile({
    required this.url,
    this.onMessage,
    this.controller,
  });

  final String url;
  final void Function(Map<String, dynamic> message)? onMessage;
  final Teacher3dController? controller;

  @override
  State<_Teacher3dViewMobile> createState() => _Teacher3dViewMobileState();
}

class _Teacher3dViewMobileState extends State<_Teacher3dViewMobile> {
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        _channelName,
        onMessageReceived: (JavaScriptMessage message) {
          final onMessage = widget.onMessage;
          if (onMessage == null) return;
          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map && decoded['source'] == 'teacher3d') {
              onMessage(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _webController.runJavaScript(_bridgeScript);
            widget.controller?.attach(_send);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // Mirrors main.js's own `window.addEventListener('message', ...)` handler,
  // which the page uses to receive 'ask'/'setGender' commands from its host.
  // Rather than fake a MessageEvent through the bridge, call the same public
  // API the page already exposes for this (`window.teacher3d`).
  void _send(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'ask':
        final question = message['question'];
        if (question is String) {
          _webController.runJavaScript(
              'window.teacher3d && window.teacher3d.ask(${jsonEncode(question)});');
        }
        break;
      case 'setGender':
        final gender = message['gender'];
        if (gender is String) {
          _webController.runJavaScript(
              'window.teacher3d && window.teacher3d.switchGender(${jsonEncode(gender)});');
        }
        break;
    }
  }

  @override
  void dispose() {
    widget.controller?.attach(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: _webController);
}
