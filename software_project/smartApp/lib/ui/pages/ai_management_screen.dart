import 'package:flutter/material.dart';
import '../../features/lessons/lesson_catalog.dart';
import 'app_shell.dart';

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what is not available in this build yet.')),
  );
}

class AiManagementScreen extends StatefulWidget {
  const AiManagementScreen({super.key});

  @override
  State<AiManagementScreen> createState() => _AiManagementScreenState();
}

class _AiManagementScreenState extends State<AiManagementScreen> {
  int tab = 1; // 0 students, 1 lessons, 2 analytics

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;
  bool _mid(BuildContext c) => MediaQuery.of(c).size.width >= 680;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Teacher Management',
      subtitle: 'Monitor student progress and manage AI learning resources',
      selectedRoute: '/ai-management',
      actions: [
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: () => _soon(context, 'Lesson authoring'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Lesson'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tabs(
            selected: tab,
            onChanged: (i) => setState(() => tab = i),
          ),
          const SizedBox(height: 14),
          _CardShell(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: tab == 0
                    ? const _StudentsTab(key: ValueKey('students'))
                    : tab == 1
                        ? _LessonsTab(
                            key: const ValueKey('lessons'),
                            columns:
                                _wide(context) ? 3 : (_mid(context) ? 2 : 1),
                          )
                        : _AnalyticsTab(
                            key: const ValueKey('analytics'),
                            columns: _wide(context) ? 2 : 1,
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Tabs ---------------- */

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        _TabItem(
          icon: Icons.people_outline,
          label: 'Students',
          selected: selected == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 18),
        _TabItem(
          icon: Icons.menu_book_outlined,
          label: 'Lessons',
          selected: selected == 1,
          onTap: () => onChanged(1),
        ),
        const SizedBox(width: 18),
        _TabItem(
          icon: Icons.bar_chart_rounded,
          label: 'Analytics',
          selected: selected == 2,
          onTap: () => onChanged(2),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg =
        selected ? const Color(0xFF2563EB) : Colors.black.withOpacity(0.55);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 12.5, color: fg)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 2.2,
            width: 92,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- card shell ---------------- */

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 16),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}

/* ---------------- Students tab (placeholder) ---------------- */

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Text(
          'Students (connect data later)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.black.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Lessons tab ---------------- */

class _LessonsTab extends StatelessWidget {
  const _LessonsTab({super.key, required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WrapGrid(
          columns: columns,
          children: [
            ...lessonCatalog.map((l) => _LessonCard(lesson: l)),
            const _CreateLessonCard(),
          ],
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.black.withOpacity(0.35)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${lesson.subject}\n${lesson.level}',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Text(
                lesson.description,
                overflow: TextOverflow.ellipsis,
                maxLines: 6,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Colors.black.withOpacity(0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Duration:',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text(lesson.duration,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 36,
                width: 92,
                child: ElevatedButton(
                  onPressed: () => _soon(context, 'Lesson editing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 14),
              TextButton(
                onPressed: () => _soon(context, 'Lesson preview'),
                child: const Text('Preview',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateLessonCard extends StatelessWidget {
  const _CreateLessonCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _soon(context, 'Lesson authoring'),
      child: Container(
      height: 290,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.black.withOpacity(0.10), style: BorderStyle.solid),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: const Icon(Icons.add, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 12),
            const Text('Create New Lesson',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'Add custom content\nand exercises',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/* ---------------- Analytics tab ---------------- */

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({super.key, required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Learning Analytics',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _WrapGrid(
          columns: columns,
          children: const [
            _PlaceholderChartCard(
                title: 'Usage Over Time Chart',
                subtitle: 'Weekly active sessions'),
            _PlaceholderChartCard(
                title: 'Student Performance Chart',
                subtitle: 'Average progress by subject'),
          ],
        ),
        const SizedBox(height: 14),
        _WrapGrid(
          columns: columns,
          children: const [
            _PopularLessonsCard(),
            _ChallengesCard(),
          ],
        ),
      ],
    );
  }
}

class _PlaceholderChartCard extends StatelessWidget {
  const _PlaceholderChartCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _PopularLessonsCard extends StatelessWidget {
  const _PopularLessonsCard();

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('1', 'Introduction to\nAlgebra', '42', 'sessions'),
      ('2', 'Python Basics', '35', 'sessions'),
      ('3', "Newton's Laws of\nMotion", '28', 'sessions'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Most Popular Lessons',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...items.map((e) => _PopularRow(
              rank: e.$1, title: e.$2, rightNum: e.$3, rightText: e.$4)),
        ],
      ),
    );
  }
}

class _PopularRow extends StatelessWidget {
  const _PopularRow({
    required this.rank,
    required this.title,
    required this.rightNum,
    required this.rightText,
  });

  final String rank;
  final String title;
  final String rightNum;
  final String rightText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Center(
              child: Text(rank,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rightNum,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(rightText,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengesCard extends StatelessWidget {
  const _ChallengesCard();

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Calculus: Derivatives', '68% difficulty', Color(0xFFF59E0B)),
      ('Physics: Quantum\nMechanics', '75%\ndifficulty', Color(0xFFEF4444)),
      ('CS: Recursion\nConcepts', '62%\ndifficulty', Color(0xFFF59E0B)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Common Learning Challenges',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...items.map(
              (e) => _ChallengeRow(title: e.$1, difficulty: e.$2, color: e.$3)),
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow(
      {required this.title, required this.difficulty, required this.color});
  final String title;
  final String difficulty;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Text(
            difficulty,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

/* ---------------- layout util ---------------- */

class _WrapGrid extends StatelessWidget {
  const _WrapGrid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final spacing = 14.0;
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
