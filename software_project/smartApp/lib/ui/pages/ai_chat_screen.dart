import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.subject, this.teacherName});
  final String subject;

  /// Name of the subject's teacher (from /api/ai/teachers), for the title.
  final String? teacherName;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _loading = false;
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await apiClient
          .getAuthed('/api/ai/history?subject=${Uri.encodeComponent(widget.subject)}');
      final list = (data['messages'] as List?) ?? const [];
      setState(() {
        _msgs
          ..clear()
          ..addAll(list.map((e) => _Msg(
                (e as Map)['role'] == 'user',
                e['content'].toString(),
              )));
        if (_msgs.isEmpty) {
          _msgs.add(_Msg(false, "Hi! Ask me anything about ${widget.subject} 😊"));
        }
        _historyLoading = false;
      });
    } catch (_) {
      setState(() {
        _msgs.add(_Msg(false, "Hi! Ask me anything about ${widget.subject} 😊"));
        _historyLoading = false;
      });
    }
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _msgs.add(_Msg(true, text));
      _loading = true;
      _input.clear();
    });
    _jump();

    try {
      final data = await apiClient.postAuthed('/api/ai/teacher', {
        'subject': widget.subject,
        'message': text,
      });
      final reply = (data['reply'] ?? 'No reply').toString();
      setState(() {
        _msgs.add(_Msg(false, reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _msgs.add(_Msg(false, "Error connecting to AI: $e"));
        _loading = false;
      });
    }
    _jump();
  }

  Future<void> _clear() async {
    try {
      await apiClient.deleteAuthed(
          '/api/ai/history?subject=${Uri.encodeComponent(widget.subject)}');
    } catch (_) {}
    setState(() {
      _msgs
        ..clear()
        ..add(_Msg(false, "History cleared. Ask me anything 😊"));
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teacherName == null
            ? "${widget.subject} Teacher"
            : "${widget.teacherName} · ${widget.subject}"),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            onPressed: _historyLoading ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _historyLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _msgs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('…thinking'),
                          ),
                        );
                      }
                      final m = _msgs[i];
                      return Align(
                        alignment: m.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 720),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: m.isUser
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.06)),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color:
                                  m.isUser ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: "Ask about ${widget.subject}…",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _send,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final bool isUser;
  final String text;
  const _Msg(this.isUser, this.text);
}
