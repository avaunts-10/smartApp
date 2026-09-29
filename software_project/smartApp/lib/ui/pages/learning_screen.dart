import 'package:flutter/material.dart';
import '../../core/di/app_di.dart';
import '../../features/learning/learning_service.dart';
import '../../features/lessons/lesson_catalog.dart';
import 'app_shell.dart';
import 'ai_chat_screen.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  int tab = 0; // 0 = Lessons, 1 = Chat, 2 = Code, 3 = Math

  // opens the subject's 3D AI teacher — the same chat used from the AI
  // Teacher hub, so continuing a lesson here picks up the same history
  void _openSubjectTeacher(String subject) {
    Navigator.pushNamed(context, '/ai-teacher-3d', arguments: subject);
  }

  void _openChat(String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiChatScreen(subject: subject)),
    );
  }

  void _notAvailable(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not available in this build.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Learning Studio',
      subtitle: 'Browse lessons, chat with the AI tutor, and keep practising',
      selectedRoute: '/learning',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              _PillTabs(
                labels: const ['Lessons', 'Chat', 'Code', 'Math'],
                selectedIndex: tab,
                onChanged: (i) => setState(() => tab = i),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tab == 0) _LessonsTab(onContinue: _openSubjectTeacher),
          if (tab == 1) _ChatTab(onStart: () => _openChat('Mathematics')),
          if (tab == 2)
            _CodeTab(
              onGetHelp: () => _openChat('Computer Science'),
              onRun: () => _notAvailable('In-browser code execution'),
            ),
          if (tab == 3)
            _MathTab(
              onSolve: (_) => _openChat('Mathematics'),
              onDraw: () => _notAvailable('Handwriting input'),
            ),
        ],
      ),
    );
  }
}

/* -------------------- LESSONS TAB -------------------- */

/// Every lesson in the catalog, each showing the student's own progress in
/// that lesson's subject and a button into that subject's AI teacher — the
/// same 3D chat and history used from the AI Teacher hub, so "continue" here
/// really does continue where the student left off.
class _LessonsTab extends StatefulWidget {
  const _LessonsTab({required this.onContinue});
  final void Function(String subject) onContinue;

  @override
  State<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<_LessonsTab> {
  bool _loading = true;
  Map<String, Subject> _bySubject = const {};

  @override
  void initState() {
    super.initState();
    learningService.overview().then((o) {
      if (!mounted) return;
      setState(() {
        _bySubject = {for (final s in o.subjects) s.name: s};
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final lesson in lessonCatalog) ...[
          _LessonCard(
            lesson: lesson,
            subject: _bySubject[lesson.subject],
            onContinue: () => widget.onContinue(lesson.subject),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.subject,
    required this.onContinue,
  });

  final Lesson lesson;
  final Subject? subject;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final started = (subject?.lessonsCompleted ?? 0) > 0 ||
        (subject?.studyMinutes ?? 0) > 0;
    return _CardSection(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(lesson.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(lesson.level,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${lesson.subject} · ${lesson.duration}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.5))),
                const SizedBox(height: 8),
                Text(lesson.description,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.black.withOpacity(0.7))),
                if (subject != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: subject!.skillFraction,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF2F7),
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Skill level ${subject!.skillLevel.toStringAsFixed(1)}/10 · '
                    '${subject!.lessonsCompleted} lessons completed',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.5)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 132,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: onContinue,
              icon: Icon(
                  started ? Icons.play_arrow_rounded : Icons.rocket_launch,
                  size: 18),
              label: Text(started ? 'Continue' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- CHAT TAB -------------------- */

class _ChatTab extends StatelessWidget {
  const _ChatTab({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Tutor',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions in plain language and get step-by-step explanations. '
            'The tutor is powered by the backend AI service.',
            style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Start AI Tutor Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- CODE TAB -------------------- */

class _CodeTab extends StatefulWidget {
  const _CodeTab({required this.onGetHelp, required this.onRun});
  final VoidCallback onGetHelp;
  final VoidCallback onRun;

  @override
  State<_CodeTab> createState() => _CodeTabState();
}

class _CodeTabState extends State<_CodeTab> {
  final _code = TextEditingController(
    text: '# Write your code here\n'
        'def hello_world():\n'
        '    print("Hello, world!")',
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Python', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _code,
              maxLines: 10,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton(
                  onPressed: widget.onRun, child: const Text('Run Code')),
              const SizedBox(width: 10),
              OutlinedButton(
                  onPressed: widget.onRun, child: const Text('Debug')),
              const Spacer(),
              OutlinedButton(
                  onPressed: widget.onGetHelp, child: const Text('Get Help')),
            ],
          ),
        ],
      ),
    );
  }
}

/* -------------------- MATH TAB -------------------- */

class _MathTab extends StatefulWidget {
  const _MathTab({required this.onSolve, required this.onDraw});
  final void Function(String equation) onSolve;
  final VoidCallback onDraw;

  @override
  State<_MathTab> createState() => _MathTabState();
}

class _MathTabState extends State<_MathTab> {
  final _eq = TextEditingController();

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Math Equation Solver',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _eq,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'e.g. 2x + 5 = 15',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton(
              onPressed: widget.onDraw,
              child: const Text('Enable Drawing'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _submit(_eq.text),
              child: const Text('Solve Equation'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(String v) {
    final eq = v.trim();
    if (eq.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an equation first.')),
      );
      return;
    }
    widget.onSolve(eq);
  }
}

/* -------------------- SHARED WIDGETS -------------------- */

class _CardSection extends StatelessWidget {
  const _CardSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 16),
            color: Colors.black.withOpacity(0.08),
          )
        ],
      ),
      child: child,
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color:
                      selected ? Colors.white : Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
