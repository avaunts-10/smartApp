import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/learning/learning_service.dart';
import '../../features/quizzes/quiz_service.dart';
import 'app_shell.dart';

const _optionLetters = ['A', 'B', 'C', 'D'];

/// Subject-scoped multiple-choice quizzes. Teachers/admins build quizzes and
/// review results; students take an unattempted quiz once and then see only
/// their score.
class QuizzesScreen extends StatefulWidget {
  const QuizzesScreen({super.key});

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  bool _loadingSubjects = true;
  bool _loadingQuizzes = false;
  String? _error;
  List<Subject> _subjects = const [];
  Subject? _selected;
  List<Quiz> _quizzes = const [];

  bool get _canManage {
    final role = authService.user.value?.role;
    return role == 'teacher' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _loadingSubjects = true;
      _error = null;
    });
    try {
      final overview = await learningService.overview();
      if (!mounted) return;
      setState(() {
        _subjects = overview.subjects;
        _selected = _subjects.isNotEmpty ? _subjects.first : null;
        _loadingSubjects = false;
      });
      if (_selected != null) _loadQuizzes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingSubjects = false;
      });
    }
  }

  Future<void> _loadQuizzes() async {
    final subject = _selected;
    if (subject == null) return;
    setState(() => _loadingQuizzes = true);
    try {
      final list = await quizService.list(subjectId: subject.id);
      if (!mounted) return;
      setState(() {
        _quizzes = list;
        _loadingQuizzes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingQuizzes = false;
      });
    }
  }

  void _selectSubject(Subject s) {
    if (s.id == _selected?.id) return;
    setState(() => _selected = s);
    _loadQuizzes();
  }

  Future<void> _createQuiz() async {
    final subject = _selected;
    if (subject == null) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _QuizBuilderScreen(subject: subject)),
    );
    if (created == true) _loadQuizzes();
  }

  Future<void> _viewResults(Quiz quiz) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _QuizResultsScreen(quiz: quiz)),
    );
  }

  Future<void> _delete(Quiz quiz) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${quiz.title}"?'),
        content: const Text(
            'This also removes every student attempt for this quiz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await quizService.delete(quiz.id);
      _loadQuizzes();
    }
  }

  Future<void> _openQuiz(Quiz quiz) async {
    if (quiz.attempted == true) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(quiz.title),
          content: Text(
            quiz.myTotal == null
                ? 'You already attempted this quiz.'
                : 'You scored ${quiz.myScore}/${quiz.myTotal} on this quiz.',
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      );
      return;
    }
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _QuizTakingScreen(quiz: quiz)),
    );
    if (submitted == true) _loadQuizzes();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Quizzes',
      subtitle: _canManage
          ? 'Build multiple-choice quizzes for each subject'
          : 'Take quizzes and check your scores',
      selectedRoute: '/quizzes',
      actions: _canManage && _selected != null
          ? [
              FilledButton.icon(
                onPressed: _createQuiz,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Quiz'),
              ),
            ]
          : null,
      body: _loadingSubjects
          ? const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()))
          : _subjects.isEmpty
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            _error != null
                                ? 'Could not load subjects\n$_error'
                                : 'No subjects yet.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                            onPressed: _loadSubjects,
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final s = _subjects[i];
                          final selected = s.id == _selected?.id;
                          return ChoiceChip(
                            label: Text(s.name),
                            selected: selected,
                            onSelected: (_) => _selectSubject(s),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingQuizzes)
                      const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()))
                    else if (_quizzes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('No quizzes for this subject yet.',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.5))),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final q in _quizzes) ...[
                            _QuizCard(
                              quiz: q,
                              canManage: _canManage,
                              onTap: _canManage ? null : () => _openQuiz(q),
                              onViewResults: () => _viewResults(q),
                              onDelete: () => _delete(q),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                  ],
                ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.quiz,
    required this.canManage,
    required this.onTap,
    required this.onViewResults,
    required this.onDelete,
  });

  final Quiz quiz;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback onViewResults;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 12),
              color: Colors.black.withOpacity(0.06)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz_outlined, color: Color(0xFF2D66F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quiz.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900)),
                if (quiz.description != null &&
                    quiz.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(quiz.description!,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black.withOpacity(0.6))),
                ],
                const SizedBox(height: 8),
                if (canManage)
                  Text(
                    '${quiz.questionCount} question(s) · ${quiz.attemptCount ?? 0} attempt(s)',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.5)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: quiz.attempted == true
                          ? const Color(0xFFDDFBE7)
                          : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      quiz.attempted == true
                          ? 'Score: ${quiz.myScore}/${quiz.myTotal}'
                          : 'Not attempted · ${quiz.questionCount} question(s)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: quiz.attempted == true
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF2D66F6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (canManage) ...[
            TextButton.icon(
              onPressed: onViewResults,
              icon: const Icon(Icons.bar_chart_outlined, size: 18),
              label: const Text('View Results'),
            ),
            IconButton(
              tooltip: 'Delete quiz',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.withOpacity(0.75)),
            ),
          ] else
            const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: card,
    );
  }
}

/* -------------------- QUIZ BUILDER (teacher) -------------------- */

class _QuestionDraft {
  _QuestionDraft()
      : text = TextEditingController(),
        a = TextEditingController(),
        b = TextEditingController(),
        c = TextEditingController(),
        d = TextEditingController();

  final TextEditingController text;
  final TextEditingController a;
  final TextEditingController b;
  final TextEditingController c;
  final TextEditingController d;
  String correct = 'A';

  bool get isComplete =>
      text.text.trim().isNotEmpty &&
      a.text.trim().isNotEmpty &&
      b.text.trim().isNotEmpty &&
      c.text.trim().isNotEmpty &&
      d.text.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'question_text': text.text.trim(),
        'option_a': a.text.trim(),
        'option_b': b.text.trim(),
        'option_c': c.text.trim(),
        'option_d': d.text.trim(),
        'correct_option': correct,
      };

  void dispose() {
    text.dispose();
    a.dispose();
    b.dispose();
    c.dispose();
    d.dispose();
  }
}

class _QuizBuilderScreen extends StatefulWidget {
  const _QuizBuilderScreen({required this.subject});
  final Subject subject;

  @override
  State<_QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends State<_QuizBuilderScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<_QuestionDraft> _questions = [_QuestionDraft()];
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(_QuestionDraft()));

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _err = 'Title is required');
      return;
    }
    if (_questions.isEmpty || !_questions.every((q) => q.isComplete)) {
      setState(
          () => _err = 'Every question needs its text and all four options');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await quizService.create(
        subjectId: widget.subject.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        questions: [for (final q in _questions) q.toJson()],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _err = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Quiz · ${widget.subject.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Quiz title')),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          Text('Questions',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (int i = 0; i < _questions.length; i++) ...[
            _QuestionEditor(
              index: i,
              draft: _questions[i],
              onRemove:
                  _questions.length > 1 ? () => _removeQuestion(i) : null,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Question'),
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save Quiz'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _QuestionDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final optionControllers = {
      'A': draft.a,
      'B': draft.b,
      'C': draft.c,
      'D': draft.d,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Question ${index + 1}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: onRemove,
                  icon: Icon(Icons.close, size: 18, color: Colors.red.withOpacity(0.7)),
                ),
            ],
          ),
          TextField(
            controller: draft.text,
            decoration: const InputDecoration(labelText: 'Question text'),
          ),
          const SizedBox(height: 10),
          Text('Pick the correct option:',
              style: TextStyle(
                  fontSize: 11.5, color: Colors.black.withOpacity(0.55))),
          for (final letter in _optionLetters)
            Row(
              children: [
                Radio<String>(
                  value: letter,
                  groupValue: draft.correct,
                  onChanged: (v) {
                    draft.correct = v ?? 'A';
                    onChanged();
                  },
                ),
                SizedBox(
                    width: 20,
                    child: Text(letter,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(
                  child: TextField(
                    controller: optionControllers[letter],
                    decoration:
                        InputDecoration(labelText: 'Option $letter'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/* -------------------- QUIZ TAKING (student) -------------------- */

class _QuizTakingScreen extends StatefulWidget {
  const _QuizTakingScreen({required this.quiz});
  final Quiz quiz;

  @override
  State<_QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<_QuizTakingScreen> {
  bool _loading = true;
  String? _error;
  List<QuizQuestion> _questions = const [];
  final Map<int, String> _answers = {};
  bool _submitting = false;
  QuizSubmitResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await quizService.detail(widget.quiz.id);
      if (!mounted) return;
      setState(() {
        _questions = detail.questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  bool get _allAnswered =>
      _questions.isNotEmpty &&
      _questions.every((q) => _answers.containsKey(q.id));

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await quizService.submit(widget.quiz.id, [
        for (final q in _questions)
          {'question_id': q.id, 'selected_option': _answers[q.id]},
      ]);
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, result != null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, result != null),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load quiz\n$_error',
                          textAlign: TextAlign.center),
                    ),
                  )
                : result != null
                    ? _ResultView(result: result, questions: _questions)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (widget.quiz.description != null &&
                              widget.quiz.description!.isNotEmpty) ...[
                            Text(widget.quiz.description!,
                                style: TextStyle(
                                    color: Colors.black.withOpacity(0.65))),
                            const SizedBox(height: 16),
                          ],
                          for (final q in _questions) ...[
                            _QuestionTakeCard(
                              question: q,
                              selected: _answers[q.id],
                              onChanged: (v) =>
                                  setState(() => _answers[q.id] = v),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _allAnswered && !_submitting
                                  ? _submit
                                  : null,
                              child:
                                  Text(_submitting ? 'Submitting…' : 'Submit Quiz'),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
      ),
    );
  }
}

class _QuestionTakeCard extends StatelessWidget {
  const _QuestionTakeCard({
    required this.question,
    required this.selected,
    required this.onChanged,
  });

  final QuizQuestion question;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.questionText,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          for (final letter in _optionLetters)
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: letter,
              groupValue: selected,
              title: Text(question.optionText(letter)),
              onChanged: (v) => onChanged(v ?? letter),
            ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.questions});
  final QuizSubmitResult result;
  final List<QuizQuestion> questions;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final q in questions) q.id: q};
    final passed = result.total > 0 && result.score >= (result.total / 2);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: passed ? const Color(0xFFDDFBE7) : const Color(0xFFFFE9B8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('Score: ${result.score}/${result.total}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Your attempt has been recorded.',
                  style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final a in result.answers) ...[
          _AnswerReviewTile(
              answer: a, question: byId[a.questionId]),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AnswerReviewTile extends StatelessWidget {
  const _AnswerReviewTile({required this.answer, required this.question});
  final QuizAnswerResult answer;
  final QuizQuestion? question;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answer.isCorrect
              ? const Color(0xFF16A34A).withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            answer.isCorrect ? Icons.check_circle : Icons.cancel,
            color: answer.isCorrect ? const Color(0xFF16A34A) : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (q != null)
                  Text(q.questionText,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Your answer: ${answer.selectedOption}'
                  '${q != null ? " · ${q.optionText(answer.selectedOption)}" : ""}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.black.withOpacity(0.65)),
                ),
                if (!answer.isCorrect)
                  Text(
                    'Correct answer: ${answer.correctOption}'
                    '${q != null ? " · ${q.optionText(answer.correctOption)}" : ""}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- RESULTS (teacher/admin) -------------------- */

class _QuizResultsScreen extends StatefulWidget {
  const _QuizResultsScreen({required this.quiz});
  final Quiz quiz;

  @override
  State<_QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<_QuizResultsScreen> {
  bool _loading = true;
  String? _error;
  List<QuizAttemptResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await quizService.results(widget.quiz.id);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results · ${widget.quiz.title}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load results\n$_error',
                        textAlign: TextAlign.center),
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Text('No attempts yet.',
                          style:
                              TextStyle(color: Colors.black.withOpacity(0.5))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFEAF1FF),
                                child: Text(
                                  r.studentEmail.isNotEmpty
                                      ? r.studentEmail[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Color(0xFF2D66F6),
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(r.studentEmail.split('@').first,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(r.studentEmail,
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.black
                                                .withOpacity(0.5))),
                                  ],
                                ),
                              ),
                              Text('${r.score}/${r.total}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
