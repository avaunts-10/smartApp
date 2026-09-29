import '../../core/network/api_client.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.sortOrder,
    this.correctOption,
  });

  final int id;
  final int quizId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final int sortOrder;

  /// A/B/C/D — null when the backend hid it from a student before submission.
  final String? correctOption;

  String optionText(String letter) {
    switch (letter) {
      case 'A':
        return optionA;
      case 'B':
        return optionB;
      case 'C':
        return optionC;
      case 'D':
        return optionD;
      default:
        return '';
    }
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: (j['id'] as num).toInt(),
        quizId: (j['quizId'] as num).toInt(),
        questionText: j['questionText'] as String,
        optionA: j['optionA'] as String,
        optionB: j['optionB'] as String,
        optionC: j['optionC'] as String,
        optionD: j['optionD'] as String,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        correctOption: j['correctOption'] as String?,
      );
}

class Quiz {
  const Quiz({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    this.createdBy,
    this.createdAt,
    this.questionCount = 0,
    this.attemptCount,
    this.attempted,
    this.myScore,
    this.myTotal,
    this.mySubmittedAt,
  });

  final int id;
  final int subjectId;
  final String title;
  final String? description;
  final int? createdBy;
  final DateTime? createdAt;
  final int questionCount;

  /// Teacher/admin listing only.
  final int? attemptCount;

  /// Student listing only.
  final bool? attempted;
  final int? myScore;
  final int? myTotal;
  final DateTime? mySubmittedAt;

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        id: (j['id'] as num).toInt(),
        subjectId: (j['subjectId'] as num).toInt(),
        title: j['title'] as String,
        description: j['description'] as String?,
        createdBy: (j['createdBy'] as num?)?.toInt(),
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String),
        questionCount: (j['questionCount'] as num?)?.toInt() ?? 0,
        attemptCount: (j['attemptCount'] as num?)?.toInt(),
        attempted: j['attempted'] as bool?,
        myScore: (j['myScore'] as num?)?.toInt(),
        myTotal: (j['myTotal'] as num?)?.toInt(),
        mySubmittedAt: j['mySubmittedAt'] == null
            ? null
            : DateTime.tryParse(j['mySubmittedAt'] as String),
      );
}

class QuizDetail {
  const QuizDetail({required this.quiz, required this.questions});
  final Quiz quiz;
  final List<QuizQuestion> questions;
}

class QuizAnswerResult {
  const QuizAnswerResult({
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.correctOption,
  });

  final int questionId;
  final String selectedOption;
  final bool isCorrect;
  final String correctOption;

  factory QuizAnswerResult.fromJson(Map<String, dynamic> j) =>
      QuizAnswerResult(
        questionId: (j['questionId'] as num).toInt(),
        selectedOption: j['selectedOption'] as String,
        isCorrect: j['isCorrect'] as bool,
        correctOption: j['correctOption'] as String,
      );
}

class QuizSubmitResult {
  const QuizSubmitResult({
    required this.score,
    required this.total,
    this.submittedAt,
    required this.answers,
  });

  final int score;
  final int total;
  final DateTime? submittedAt;
  final List<QuizAnswerResult> answers;

  factory QuizSubmitResult.fromJson(Map<String, dynamic> j) =>
      QuizSubmitResult(
        score: (j['score'] as num).toInt(),
        total: (j['total'] as num).toInt(),
        submittedAt: j['submittedAt'] == null
            ? null
            : DateTime.tryParse(j['submittedAt'] as String),
        answers: ((j['answers'] as List?) ?? const [])
            .map((e) => QuizAnswerResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One student's attempt, as shown on the teacher/admin results screen.
class QuizAttemptResult {
  const QuizAttemptResult({
    required this.attemptId,
    required this.studentId,
    required this.studentEmail,
    required this.score,
    required this.total,
    this.submittedAt,
  });

  final int attemptId;
  final int studentId;
  final String studentEmail;
  final int score;
  final int total;
  final DateTime? submittedAt;

  factory QuizAttemptResult.fromJson(Map<String, dynamic> j) =>
      QuizAttemptResult(
        attemptId: (j['attemptId'] as num).toInt(),
        studentId: (j['studentId'] as num).toInt(),
        studentEmail: j['studentEmail'] as String,
        score: (j['score'] as num).toInt(),
        total: (j['total'] as num).toInt(),
        submittedAt: j['submittedAt'] == null
            ? null
            : DateTime.tryParse(j['submittedAt'] as String),
      );
}

class QuizService {
  QuizService(this.api);
  final ApiClient api;

  Future<List<Quiz>> list({int? subjectId}) async {
    final path = subjectId == null
        ? '/api/quizzes'
        : '/api/quizzes?subject_id=$subjectId';
    final res = await api.getAuthed(path);
    return ((res['quizzes'] as List?) ?? const [])
        .map((e) => Quiz.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QuizDetail> detail(int id) async {
    final res = await api.getAuthed('/api/quizzes/$id');
    return QuizDetail(
      quiz: Quiz.fromJson(res['quiz'] as Map<String, dynamic>),
      questions: ((res['questions'] as List?) ?? const [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Quiz> create({
    required int subjectId,
    required String title,
    String? description,
    required List<Map<String, dynamic>> questions,
  }) async {
    final res = await api.postAuthed('/api/quizzes', {
      'subject_id': subjectId,
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'questions': questions,
    });
    return Quiz.fromJson(res['quiz'] as Map<String, dynamic>);
  }

  /// [answers] is a list of {'question_id': int, 'selected_option': 'A'..'D'}.
  /// Throws if the student already has an attempt (backend returns 409).
  Future<QuizSubmitResult> submit(
    int quizId,
    List<Map<String, dynamic>> answers,
  ) async {
    final res = await api.postAuthedJson('/api/quizzes/$quizId/submit', answers);
    return QuizSubmitResult.fromJson(res);
  }

  Future<List<QuizAttemptResult>> results(int quizId) async {
    final res = await api.getAuthed('/api/quizzes/$quizId/results');
    return ((res['results'] as List?) ?? const [])
        .map((e) => QuizAttemptResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(int id) => api.deleteAuthed('/api/quizzes/$id');
}
