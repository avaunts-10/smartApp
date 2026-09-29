import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/learning/learning_service.dart';
import 'app_shell.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  String? _error;
  List<Subject> _subjects = const [];
  LearningSummary? _summary;

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;
  bool _mid(BuildContext c) => MediaQuery.of(c).size.width >= 680;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final o = await learningService.overview();
      if (!mounted) return;
      setState(() {
        _subjects = o.subjects;
        _summary = o.summary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Color _barColor(String name) {
    switch (name) {
      case 'Mathematics':
        return const Color(0xFF2563EB);
      case 'Computer Science':
        return const Color(0xFF16A34A);
      case 'Science':
        return const Color(0xFF7C3AED);
      case 'Languages':
        return const Color(0xFFF59E0B);
      case 'History':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpiCols = _wide(context) ? 4 : (_mid(context) ? 2 : 1);

    return AppShell(
      title: 'Learning Progress',
      subtitle:
          'Track your learning journey and identify areas for improvement',
      selectedRoute: '/progress',
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
                        Text('Could not load progress\n$_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _content(kpiCols),
    );
  }

  Widget _content(int kpiCols) {
    final s = _summary!;
    final studied = _subjects.where((x) => x.studyMinutes > 0).toList();
    final improve = _subjects.where((x) => x.skillLevel < 7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Grid(
          columns: kpiCols,
          children: [
            _MiniKpi(
              title: 'Learning\nTime',
              big: s.totalLabel,
              sub: 'Total time spent\nlearning',
              icon: Icons.schedule,
              iconBg: const Color(0xFFDCEBFF),
              iconColor: const Color(0xFF2563EB),
            ),
            _MiniKpi(
              title: 'Skill\nLevel',
              big: '${s.avgSkill.toStringAsFixed(1)}/10',
              sub: 'Average across\nstudied subjects',
              icon: Icons.trending_up,
              iconBg: const Color(0xFFDDFBE7),
              iconColor: const Color(0xFF16A34A),
            ),
            _MiniKpi(
              title: 'Subjects',
              big: '${s.subjectsStudied}',
              sub: 'Subjects being\nstudied',
              icon: Icons.menu_book,
              iconBg: const Color(0xFFF1E8FF),
              iconColor: const Color(0xFF7C3AED),
            ),
            _MiniKpi(
              title: 'Lessons',
              big: '${s.lessonsCompleted}',
              sub: 'Lessons\ncompleted',
              icon: Icons.emoji_events,
              iconBg: const Color(0xFFFFF0D6),
              iconColor: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CardSection(
          title: 'Subject Progress',
          child: Column(
            children: [
              for (int i = 0; i < studied.length; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                _SubjectProgressRow(
                  title: studied[i].name,
                  subtitle:
                      '${studied[i].lessonsCompleted} lessons completed',
                  scoreText:
                      '${studied[i].skillLevel.toStringAsFixed(0)} /10',
                  value: studied[i].skillFraction,
                  color: _barColor(studied[i].name),
                ),
              ],
              if (studied.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No subjects studied yet.',
                      style:
                          TextStyle(color: Colors.black.withOpacity(0.55))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TwoCardsRow(
          left: _CardSection(
            title: 'Areas for Improvement',
            trailing: const _TinyCircle(
                icon: Icons.error_outline, color: Color(0xFFF59E0B)),
            child: Column(
              children: [
                for (final x in improve) _ImproveRow(label: x.name),
                if (improve.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Every subject is at skill 7+ — great work!',
                        style:
                            TextStyle(color: Colors.black.withOpacity(0.55))),
                  ),
              ],
            ),
          ),
          right: _CardSection(
            title: 'How the AI Tutor Adapts',
            child: const _InfoBox(),
          ),
        ),
      ],
    );
  }
}

/* ---------------- UI ---------------- */

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      const spacing = 14.0;
      final w = c.maxWidth;
      final itemW = (w - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            children.map((e) => SizedBox(width: itemW, child: e)).toList(),
      );
    });
  }
}

class _TwoCardsRow extends StatelessWidget {
  const _TwoCardsRow({required this.left, required this.right});
  final Widget left;
  final Widget right;

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;

  @override
  Widget build(BuildContext context) {
    if (_wide(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      children: [
        left,
        const SizedBox(height: 14),
        right,
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

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
              color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w900))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.title,
    required this.big,
    required this.sub,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final String big;
  final String sub;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 14),
              color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(big,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SubjectProgressRow extends StatelessWidget {
  const _SubjectProgressRow({
    required this.title,
    required this.subtitle,
    required this.scoreText,
    required this.value,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String scoreText;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Text(scoreText,
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ImproveRow extends StatelessWidget {
  const _ImproveRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          const Text('Focus on this',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB))),
        ],
      ),
    );
  }
}

class _TinyCircle extends StatelessWidget {
  const _TinyCircle({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration:
          BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Text(
        'The AI tutor uses your skill level and time spent per subject to '
        'pick what to review next and how much to explain. Keep studying a '
        'subject to raise its skill level.',
        style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: Colors.black.withOpacity(0.6),
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
