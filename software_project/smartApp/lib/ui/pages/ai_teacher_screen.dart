import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/learning/learning_service.dart';
import '../theme/chalk_shapes.dart';
import '../theme/chalk_theme.dart';
import 'app_shell.dart';

class AiTeacherScreen extends StatefulWidget {
  const AiTeacherScreen({super.key});

  @override
  State<AiTeacherScreen> createState() => _AiTeacherScreenState();
}

class _AiTeacherScreenState extends State<AiTeacherScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Subject> _subjects = const [];
  List<ChatSession> _sessions = const [];
  Map<String, TeacherInfo> _teachers = const {};

  /// Subject name -> its chalk color, assigned once per load by list
  /// position so it stays the same everywhere that subject appears.
  Map<String, Color> _subjectColors = const {};

  static const _revealDuration = Duration(milliseconds: 900);
  static const _staggerStepMs = 40;
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _revealController =
        AnimationController(vsync: this, duration: _revealDuration);
    _load();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final o = await learningService.overview();
      List<ChatSession> sessions = const [];
      try {
        sessions = await learningService.chatSessions();
      } catch (_) {}
      Map<String, TeacherInfo> teachers = const {};
      try {
        teachers = await learningService.teachers();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _subjects = o.subjects;
        _subjectColors = {
          for (var i = 0; i < o.subjects.length; i++)
            o.subjects[i].name: ChalkColors.forSubjectIndex(i),
        };
        _sessions = sessions;
        _teachers = teachers;
        _loading = false;
        _error = null;
      });
      _revealController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Opens the subject's classroom: its own teacher (3D avatar + chat).
  Future<void> _openSubject(String subject) async {
    await Navigator.pushNamed(context, '/ai-teacher-3d', arguments: subject);
    _load(); // refresh Chat History after returning
  }

  Color _colorFor(String subject) =>
      _subjectColors[subject] ?? ChalkColors.chalkSky;

  IconData _iconFor(String name) {
    switch (name) {
      case 'Mathematics':
        return Icons.calculate_outlined;
      case 'Computer Science':
        return Icons.code_rounded;
      case 'Science':
        return Icons.science_outlined;
      case 'Languages':
        return Icons.public;
      case 'History':
        return Icons.access_time_rounded;
      default:
        return Icons.auto_stories_outlined;
    }
  }

  /// Fade+scale-in animation for the subject card at [index], staggered by
  /// [_staggerStepMs] per card.
  Animation<double> _cardReveal(int index) {
    final totalMs = _revealDuration.inMilliseconds;
    final startMs = (index * _staggerStepMs).clamp(0, totalMs);
    final start = startMs / totalMs;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  String _recommendation() {
    final weakest = [..._subjects]
      ..sort((a, b) => a.skillLevel.compareTo(b.skillLevel));
    if (weakest.isEmpty) return 'Start by exploring a subject!';
    final s = weakest.first;
    return 'Focus area: ${s.name} (skill ${s.skillLevel.toStringAsFixed(0)}/10). '
        'Open it to start a guided session.';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'AI Teaching Assistant',
      subtitle:
          'Your personalized learning companion for interactive education',
      selectedRoute: '/ai-teacher',
      solidBackground: ChalkColors.paper,
      body: _loading
          ? const SizedBox(
              height: 300, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load subjects\n$_error',
                            textAlign: TextAlign.center,
                            style: ChalkText.body()),
                        const SizedBox(height: 10),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChalkHeroCard(onTap: () => _openSubject('General')),
                    const SizedBox(height: 24),
                    Text('Choose a Subject', style: ChalkText.heading(size: 16)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final s = _subjects[i];
                          final color = _colorFor(s.name);
                          return SizedBox(
                            width: 172,
                            child: AnimatedBuilder(
                              animation: _revealController,
                              builder: (context, child) {
                                final anim = _cardReveal(i);
                                return Opacity(
                                  opacity: anim.value,
                                  child: Transform.scale(
                                    scale: 0.85 + 0.15 * anim.value,
                                    child: child,
                                  ),
                                );
                              },
                              child: _SubjectCard(
                                title: s.name,
                                teacher: _teachers[s.name],
                                icon: _iconFor(s.name),
                                color: color,
                                skillLevel: s.skillLevel,
                                onTap: () => _openSubject(s.name),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_sessions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionHeading(
                          title: 'Chat History', icon: Icons.history),
                      const SizedBox(height: 10),
                      for (final cs in _sessions)
                        _ChatBubbleCard(
                          session: cs,
                          color: _colorFor(cs.subject),
                          onTap: () => _openSubject(cs.subject),
                        ),
                    ],
                    const SizedBox(height: 24),
                    const _SectionHeading(
                        title: 'Your Progress', icon: Icons.trending_up),
                    const SizedBox(height: 12),
                    _ProgressCard(
                      subjects: _subjects,
                      colorFor: _colorFor,
                      onViewDetails: () =>
                          Navigator.pushNamed(context, '/progress'),
                    ),
                    const SizedBox(height: 24),
                    _RecommendedLessonsCard(
                      text: _recommendation(),
                      onExplore: () =>
                          Navigator.pushNamed(context, '/learning'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
    );
  }
}

/* ---------------- widgets ---------------- */

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: ChalkText.heading(size: 15))),
        Icon(icon, size: 18, color: ChalkColors.ink.withOpacity(0.5)),
      ],
    );
  }
}

class _ChalkHeroCard extends StatelessWidget {
  const _ChalkHeroCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 184,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: ChalkBlobPainter(
                  color: ChalkColors.chalkboard, variant: 0),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.view_in_ar_rounded,
                      color: Colors.white, size: 30),
                  const SizedBox(height: 10),
                  Text('Meet your 3D AI Teacher',
                      style: ChalkText.heading(size: 19, color: Colors.white)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      'Each subject has its own teacher. Tap one to enter '
                      'their classroom, or start here with the general tutor.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ChalkText.body(
                          size: 12.5,
                          color: Colors.white.withOpacity(0.82),
                          height: 1.35),
                    ),
                  ),
                  ChalkTapScale(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: ChalkColors.chalkYellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Start Learning',
                              style: ChalkText.body(
                                  size: 13,
                                  weight: FontWeight.w800,
                                  color: ChalkColors.ink)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: ChalkColors.ink),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.skillLevel,
    required this.onTap,
    this.teacher,
  });

  final String title;
  final TeacherInfo? teacher;
  final IconData icon;
  final Color color;
  final double skillLevel; // 0..10
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChalkTapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 12),
              color: ChalkColors.ink.withOpacity(0.08),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(52, 52),
                    painter: ChalkBlobPainter(color: color, variant: 1),
                  ),
                  Icon(icon, color: ChalkColors.onColor(color), size: 22),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ChalkText.heading(size: 14)),
            if (teacher != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.view_in_ar_rounded, size: 13, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(teacher!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ChalkText.body(
                            size: 11, color: ChalkColors.ink.withOpacity(0.6))),
                  ),
                ],
              ),
            ],
            const Spacer(),
            Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(38, 38),
                        painter: ChalkArcPainter(
                          progress: (skillLevel / 10).clamp(0, 1).toDouble(),
                          color: color,
                          strokeWidth: 4.5,
                        ),
                      ),
                      Text(skillLevel.toStringAsFixed(0),
                          style: ChalkText.body(
                              size: 12, weight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Skill Level',
                      style: ChalkText.body(
                          size: 10.5, color: ChalkColors.ink.withOpacity(0.55))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubbleCard extends StatelessWidget {
  const _ChatBubbleCard({
    required this.session,
    required this.color,
    required this.onTap,
  });

  final ChatSession session;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipPath(
          clipper: const ChatBubbleClipper(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 20),
            color: color.withOpacity(0.14),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.subject,
                          style: ChalkText.heading(size: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        session.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ChalkText.body(
                            size: 11.5, color: ChalkColors.ink.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('${session.count} msg',
                    style: ChalkText.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: ChalkColors.ink.withOpacity(0.45))),
                Icon(Icons.chevron_right,
                    size: 18, color: ChalkColors.ink.withOpacity(0.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.subjects,
    required this.colorFor,
    required this.onViewDetails,
  });

  final List<Subject> subjects;
  final Color Function(String subject) colorFor;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final studied = subjects.where((s) => s.studyMinutes > 0).take(4).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 16),
            color: ChalkColors.ink.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (studied.isEmpty)
            Text('No study time logged yet.',
                style: ChalkText.body(
                    size: 12, color: ChalkColors.ink.withOpacity(0.55)))
          else
            for (final s in studied) ...[
              _ChalkRingRow(subject: s, color: colorFor(s.name)),
              const SizedBox(height: 14),
            ],
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onViewDetails,
              child: Text('View Detailed Progress',
                  style: ChalkText.body(
                      size: 12,
                      weight: FontWeight.w800,
                      color: ChalkColors.chalkSky)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChalkRingRow extends StatelessWidget {
  const _ChalkRingRow({required this.subject, required this.color});
  final Subject subject;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(52, 52),
                painter: ChalkArcPainter(
                  progress: subject.skillFraction,
                  color: color,
                  strokeWidth: 5.5,
                ),
              ),
              Text(subject.skillLevel.toStringAsFixed(0),
                  style: ChalkText.body(size: 13, weight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject.name, style: ChalkText.heading(size: 13.5)),
              const SizedBox(height: 2),
              Text(subject.studyLabel,
                  style: ChalkText.body(
                      size: 11.5, color: ChalkColors.ink.withOpacity(0.55))),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendedLessonsCard extends StatelessWidget {
  const _RecommendedLessonsCard({required this.text, required this.onExplore});
  final String text;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: ChalkBlobPainter(
                  color: ChalkColors.chalkYellow.withOpacity(0.22),
                  variant: 2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 18, color: ChalkColors.chalkCoral),
                      const SizedBox(width: 8),
                      Text('Recommended Lessons',
                          style: ChalkText.heading(size: 15)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(text,
                      style: ChalkText.body(
                          size: 12.5,
                          color: ChalkColors.ink.withOpacity(0.65),
                          height: 1.4)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onExplore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChalkColors.chalkboard,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                        textStyle: ChalkText.body(
                            size: 13, weight: FontWeight.w800),
                      ),
                      child: const Text('Explore All Lessons'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
