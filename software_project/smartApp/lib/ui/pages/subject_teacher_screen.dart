import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/learning/learning_service.dart';
import 'app_shell.dart';
import 'teacher3d_view.dart';

/// A subject's classroom: the subject's own teacher as a 3D avatar (served by
/// the backend at `/teacher3d`, embedded in an iframe) beside the conversation
/// with them. Questions typed here are sent into the avatar page, which asks
/// `/api/ai/teacher` and speaks the reply; the reply comes back through
/// `postMessage` and is appended to the transcript. History is per subject.
///
/// Which teacher shows up (avatar, voice, persona) is decided by
/// `backend/public_teacher3d/teachers.json`. Open with
/// `Navigator.pushNamed(context, '/ai-teacher-3d', arguments: 'Mathematics')`.
///
/// On non-web platforms the avatar is unavailable and the chat talks to the
/// API directly.
class SubjectTeacherScreen extends StatefulWidget {
  const SubjectTeacherScreen({super.key, this.subject = 'General'});

  final String subject;

  @override
  State<SubjectTeacherScreen> createState() => _SubjectTeacherScreenState();
}

class _SubjectTeacherScreenState extends State<SubjectTeacherScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _avatar = Teacher3dController();
  final List<_Msg> _msgs = [];

  String? _token;
  TeacherInfo? _teacher;
  String _status = 'Loading…';
  bool _historyLoading = true;
  bool _thinking = false;
  bool _avatarReady = false;
  String? _greeting; // spoken by the avatar; shown once history is known to be empty

  // the character currently speaking (female or male) and their name/title —
  // starts as the subject's default teacher, then follows whichever the
  // student picks with the gender toggle
  String? _gender;
  String? _activeName;
  String? _activeTitle;

  List<ChatSession> _sessions = const [];

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;

  @override
  void initState() {
    super.initState();
    apiClient.currentToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
    learningService.teachers().then((map) {
      if (!mounted) return;
      final t = map[widget.subject] ?? map['General'];
      setState(() {
        _teacher = t;
        _gender ??= t?.gender;
        _activeName ??= t?.name;
        _activeTitle ??= t?.title;
      });
    }).catchError((_) {});
    learningService.chatSessions().then((s) {
      if (mounted) setState(() => _sessions = s);
    }).catchError((_) {});
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await apiClient.getAuthed(
          '/api/ai/history?subject=${Uri.encodeComponent(widget.subject)}');
      final list = (data['messages'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _msgs
          ..clear()
          ..addAll(list.map((e) => _Msg(
                (e as Map)['role'] == 'user',
                e['content'].toString(),
              )));
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
    _applyGreeting();
    _jump();
  }

  // the teacher introduces themselves; keep it as the opening line of a fresh
  // conversation only (greeting and history load in either order)
  void _applyGreeting() {
    final g = _greeting;
    if (g == null || _historyLoading || _msgs.isNotEmpty) return;
    setState(() => _msgs.add(_Msg(false, g)));
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

  // events from the avatar page
  void _onMessage(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'ready':
        setState(() {
          _avatarReady = true;
          _status = 'Ready — ask a question';
          final g = m['gender']?.toString();
          if (g != null && g.isNotEmpty) _gender = g;
          final name = m['teacher']?.toString();
          if (name != null && name.isNotEmpty) _activeName = name;
        });
        break;
      case 'character':
        // the student switched the avatar's gender: update the header/name
        setState(() {
          final g = m['gender']?.toString();
          if (g != null && g.isNotEmpty) _gender = g;
          _activeName = (m['name'] ?? _activeName)?.toString();
          _activeTitle = (m['title'] ?? _activeTitle)?.toString();
        });
        break;
      case 'greeting':
        final text = (m['text'] ?? '').toString();
        if (text.isNotEmpty) {
          _greeting = text;
          _applyGreeting();
        }
        break;
      case 'thinking':
        setState(() {
          _thinking = true;
          _status = 'Thinking…';
        });
        break;
      case 'answer':
        setState(() {
          _thinking = false;
          _status = 'Ready — ask a question';
          _msgs.add(_Msg(false, (m['answer'] ?? '').toString()));
        });
        _jump();
        break;
      case 'error':
        setState(() {
          _thinking = false;
          _status = 'Ready';
          _msgs.add(_Msg(false, '⚠️ ${m['message'] ?? 'Something went wrong'}'));
        });
        _jump();
        break;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _thinking) return;
    setState(() {
      _msgs.add(_Msg(true, text));
      _input.clear();
    });
    _jump();

    // web/mobile: let the avatar ask and speak; the answer arrives via _onMessage
    if (_avatarReady && _avatar.isAttached) {
      setState(() => _thinking = true);
      _avatar.ask(text);
      return;
    }

    // no avatar (desktop, or still loading): plain request
    setState(() => _thinking = true);
    try {
      final data = await apiClient.postAuthed('/api/ai/teacher', {
        'subject': widget.subject,
        'message': text,
        if (_gender != null) 'gender': _gender,
      });
      if (!mounted) return;
      final reply = (data['reply'] ?? 'No reply').toString();
      setState(() {
        _msgs.add(_Msg(false, reply));
        _thinking = false;
      });
      // no-op on web (the iframe already spoke its own reply); on native
      // platforms this drives the on-device TTS + lip-sync avatar.
      _avatar.speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg(false, '⚠️ Error connecting to AI: $e'));
        _thinking = false;
      });
    }
    _jump();
  }

  Future<void> _clear() async {
    try {
      await apiClient.deleteAuthed(
          '/api/ai/history?subject=${Uri.encodeComponent(widget.subject)}');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _msgs.clear();
      final g = _activeGreeting;
      if (g != null && g.isNotEmpty) _msgs.add(_Msg(false, g));
    });
  }

  /// The active character's opening line — the subject's default teacher, or
  /// the alternate (opposite-gender) one if the student switched to them.
  String? get _activeGreeting {
    final t = _teacher;
    if (t == null) return null;
    if (_gender != null && t.alt != null && t.alt!.gender == _gender) {
      return t.alt!.greeting;
    }
    return t.greeting;
  }

  /// Switches the active character (avatar + voice + persona) to [gender].
  void _setGender(String gender) {
    if (gender == _gender) return;
    setState(() => _gender = gender);
    _avatar.setGender(gender);
  }

  Future<void> _openHistory() async {
    if (_sessions.isEmpty) {
      try {
        _sessions = await learningService.chatSessions();
      } catch (_) {}
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Chat history',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            if (_sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text('No past conversations yet.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in _sessions)
                      ListTile(
                        leading: Icon(Icons.chat_bubble_outline,
                            color: s.subject == widget.subject
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.black45),
                        title: Text(s.subject,
                            style: TextStyle(
                                fontWeight: s.subject == widget.subject
                                    ? FontWeight.w900
                                    : FontWeight.w600)),
                        subtitle: Text(s.lastMessage,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text('${s.count} msg',
                            style: const TextStyle(fontSize: 11.5)),
                        onTap: () => Navigator.pop(ctx, s.subject),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != widget.subject && mounted) {
      Navigator.pushReplacementNamed(context, '/ai-teacher-3d',
          arguments: chosen);
    }
  }

  String? get _url {
    final token = _token;
    if (token == null) return null;
    final gender = _gender ?? _teacher?.gender;
    return '$apiBaseUrl/teacher3d/index.html'
        '?api=${Uri.encodeComponent(apiBaseUrl)}'
        '&token=$token'
        '&subject=${Uri.encodeComponent(widget.subject)}'
        '&embedded=1'
        '${gender != null ? '&gender=${Uri.encodeComponent(gender)}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final t = _teacher;
    final accent = t?.accent ?? const Color(0xFF2563EB);
    final url = _url;
    final displayName = t == null ? null : (_activeName ?? t.name);
    final displayTitle = t == null ? null : (_activeTitle ?? t.title);

    final avatar = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: url == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : Teacher3dView(
              url: url, onMessage: _onMessage, controller: _avatar),
    );

    final chat = _ChatPanel(
      subject: widget.subject,
      teacher: t,
      displayName: displayName,
      accent: accent,
      messages: _msgs,
      loading: _historyLoading,
      thinking: _thinking,
      scroll: _scroll,
      input: _input,
      onSend: _send,
    );

    final body = _wide(context)
        ? SizedBox(
            height: 600,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: avatar),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: chat),
              ],
            ),
          )
        : Column(
            children: [
              SizedBox(height: 420, child: avatar),
              const SizedBox(height: 14),
              SizedBox(height: 460, child: chat),
            ],
          );

    return AppShell(
      title: displayName ?? '${widget.subject} Teacher',
      subtitle: t == null
          ? _status
          : '${displayTitle ?? t.title} · ${widget.subject} · $_status',
      selectedRoute: '/ai-teacher',
      actions: [
        IconButton(
          tooltip: 'Chat history',
          onPressed: _openHistory,
          icon: const Icon(Icons.history),
        ),
        IconButton(
          tooltip: 'Clear conversation',
          onPressed: _historyLoading ? null : _clear,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t != null) ...[
            _TeacherHeader(
              teacher: t,
              subject: widget.subject,
              displayName: displayName,
              displayTitle: displayTitle,
              gender: _gender ?? t.gender,
              hasAlt: t.alt != null,
              onGenderChanged: _setGender,
            ),
            const SizedBox(height: 14),
          ],
          body,
        ],
      ),
    );
  }
}

/* ---------------- widgets ---------------- */

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({
    required this.teacher,
    required this.subject,
    required this.displayName,
    required this.displayTitle,
    required this.gender,
    required this.hasAlt,
    required this.onGenderChanged,
  });
  final TeacherInfo teacher;
  final String subject;
  final String? displayName;
  final String? displayTitle;
  final String gender;
  final bool hasAlt;
  final void Function(String gender) onGenderChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: teacher.accent.withOpacity(0.15),
            child: Icon(
              gender == 'male' ? Icons.face_rounded : Icons.face_3_rounded,
              color: teacher.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName ?? teacher.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                    '${displayTitle ?? teacher.title} · answers your $subject questions',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.55))),
              ],
            ),
          ),
          if (hasAlt) ...[
            _GenderToggle(gender: gender, onChanged: onGenderChanged),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: teacher.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(subject,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: teacher.accent)),
          ),
        ],
      ),
    );
  }
}

/// Small female/male pill switch — mirrors the toggle drawn inside the
/// avatar's own iframe, for when that overlay is out of reach (narrow
/// layouts, or the plain-text fallback on non-web platforms).
class _GenderToggle extends StatelessWidget {
  const _GenderToggle({required this.gender, required this.onChanged});
  final String gender;
  final void Function(String gender) onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String value, IconData icon, String label) {
      final on = gender == value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: on ? Colors.white : Colors.black54),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : Colors.black54)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('female', Icons.face_3_rounded, 'Female'),
          seg('male', Icons.face_rounded, 'Male'),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.subject,
    required this.teacher,
    this.displayName,
    required this.accent,
    required this.messages,
    required this.loading,
    required this.thinking,
    required this.scroll,
    required this.input,
    required this.onSend,
  });

  final String subject;
  final TeacherInfo? teacher;
  final String? displayName;
  final Color accent;
  final List<_Msg> messages;
  final bool loading;
  final bool thinking;
  final ScrollController scroll;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final who = displayName ?? teacher?.name ?? '$subject teacher';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Conversation with $who',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty && !thinking
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Ask $who anything about $subject.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length + (thinking ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == messages.length) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text('$who is thinking…',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.5),
                                        fontStyle: FontStyle.italic)),
                              ),
                            );
                          }
                          final m = messages[i];
                          return Align(
                            alignment: m.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 520),
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: m.isUser
                                    ? accent
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                m.text,
                                style: TextStyle(
                                  color: m.isUser ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Ask $who…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: thinking || loading ? null : onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: thinking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ask'),
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
  const _Msg(this.isUser, this.text);
  final bool isUser;
  final String text;
}
