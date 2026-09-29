import 'package:flutter/material.dart' show Color;

import '../../core/network/api_client.dart';

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.skillLevel, // 0..10
    required this.studyMinutes,
    required this.lessonsCompleted,
  });

  final int id;
  final String name;
  final double skillLevel;
  final int studyMinutes;
  final int lessonsCompleted;

  double get skillFraction => (skillLevel / 10).clamp(0, 1).toDouble();

  String get studyLabel {
    final h = studyMinutes ~/ 60;
    final m = studyMinutes % 60;
    return '${h}h ${m}m';
  }

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        skillLevel: (j['skillLevel'] as num).toDouble(),
        studyMinutes: (j['studyMinutes'] as num).toInt(),
        lessonsCompleted: (j['lessonsCompleted'] as num).toInt(),
      );
}

class LearningSummary {
  const LearningSummary({
    required this.totalMinutes,
    required this.avgSkill,
    required this.subjectsStudied,
    required this.lessonsCompleted,
  });

  final int totalMinutes;
  final double avgSkill;
  final int subjectsStudied;
  final int lessonsCompleted;

  String get totalLabel {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m}m';
  }

  factory LearningSummary.fromJson(Map<String, dynamic> j) => LearningSummary(
        totalMinutes: (j['totalMinutes'] as num).toInt(),
        avgSkill: (j['avgSkill'] as num).toDouble(),
        subjectsStudied: (j['subjectsStudied'] as num).toInt(),
        lessonsCompleted: (j['lessonsCompleted'] as num).toInt(),
      );
}

class LearningOverview {
  const LearningOverview({required this.subjects, required this.summary});
  final List<Subject> subjects;
  final LearningSummary summary;
}

/// The named teacher assigned to a subject (see backend/public_teacher3d/teachers.json).
class TeacherInfo {
  const TeacherInfo({
    required this.subject,
    required this.name,
    required this.title,
    required this.gender,
    required this.accent,
    required this.greeting,
    this.alt,
  });

  final String subject;
  final String name;
  final String title;
  final String gender; // 'female' | 'male'
  final Color accent;
  final String greeting;

  /// The subject's other character (opposite gender), if the roster defines
  /// one — lets the student switch between a female and a male teacher.
  final TeacherAlt? alt;

  factory TeacherInfo.fromJson(Map<String, dynamic> j) => TeacherInfo(
        subject: j['subject'] as String,
        name: (j['name'] ?? 'AI Teacher') as String,
        title: (j['title'] ?? '') as String,
        gender: (j['gender'] ?? 'female') as String,
        accent: _hex((j['accent'] ?? '#2563EB') as String),
        greeting: (j['greeting'] ?? '') as String,
        alt: j['alt'] is Map
            ? TeacherAlt.fromJson(j['alt'] as Map<String, dynamic>)
            : null,
      );

  static Color _hex(String h) {
    final v = int.tryParse(h.replaceFirst('#', ''), radix: 16) ?? 0x2563EB;
    return Color(0xFF000000 | v);
  }
}

/// The other character (female/male) a subject's teacher can switch to.
class TeacherAlt {
  const TeacherAlt({
    required this.name,
    required this.title,
    required this.gender,
    required this.greeting,
  });

  final String name;
  final String title;
  final String gender;
  final String greeting;

  factory TeacherAlt.fromJson(Map<String, dynamic> j) => TeacherAlt(
        name: (j['name'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        gender: (j['gender'] ?? '') as String,
        greeting: (j['greeting'] ?? '') as String,
      );
}

class ChatSession {
  const ChatSession({
    required this.subject,
    required this.lastMessage,
    required this.count,
  });

  final String subject;
  final String lastMessage;
  final int count;

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        subject: j['subject'] as String,
        lastMessage: (j['lastMessage'] ?? '') as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class LearningMaterial {
  const LearningMaterial({
    required this.id,
    required this.subjectId,
    this.subjectName,
    required this.title,
    this.description,
    required this.fileUrl,
    this.fileName,
    this.fileType,
    this.uploadedBy,
    this.createdAt,
  });

  final int id;
  final int subjectId;
  final String? subjectName;
  final String title;
  final String? description;
  final String fileUrl;
  final String? fileName;
  final String? fileType;
  final int? uploadedBy;
  final DateTime? createdAt;

  factory LearningMaterial.fromJson(Map<String, dynamic> j) =>
      LearningMaterial(
        id: (j['id'] as num).toInt(),
        subjectId: (j['subjectId'] as num).toInt(),
        subjectName: j['subjectName'] as String?,
        title: j['title'] as String,
        description: j['description'] as String?,
        fileUrl: j['fileUrl'] as String,
        fileName: j['fileName'] as String?,
        fileType: j['fileType'] as String?,
        uploadedBy: (j['uploadedBy'] as num?)?.toInt(),
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String),
      );
}

class LearningService {
  LearningService(this.api);
  final ApiClient api;

  Future<List<ChatSession>> chatSessions() async {
    final res = await api.getAuthed('/api/ai/sessions');
    return ((res['sessions'] as List?) ?? const [])
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Subject name -> its teacher. Empty map if the backend has no roster.
  Future<Map<String, TeacherInfo>> teachers() async {
    final res = await api.getAuthed('/api/ai/teachers');
    final list = ((res['teachers'] as List?) ?? const [])
        .map((e) => TeacherInfo.fromJson(e as Map<String, dynamic>));
    return {for (final t in list) t.subject: t};
  }

  Future<LearningOverview> overview() async {
    final res = await api.getAuthed('/api/learning/subjects');
    return LearningOverview(
      subjects: ((res['subjects'] as List?) ?? const [])
          .map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: LearningSummary.fromJson(res['summary'] as Map<String, dynamic>),
    );
  }

  /// Materials for one subject, or every subject when [subjectId] is null.
  Future<List<LearningMaterial>> materials({int? subjectId}) async {
    final path = subjectId == null
        ? '/api/materials'
        : '/api/materials?subject_id=$subjectId';
    final res = await api.getAuthed(path);
    return ((res['materials'] as List?) ?? const [])
        .map((e) => LearningMaterial.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LearningMaterial> uploadMaterial({
    required int subjectId,
    required String title,
    String? description,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final res = await api.postMultipartAuthed(
      '/api/materials',
      {
        'subject_id': subjectId.toString(),
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
      fileFieldName: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
    );
    return LearningMaterial.fromJson(res['material'] as Map<String, dynamic>);
  }

  Future<void> deleteMaterial(int id) => api.deleteAuthed('/api/materials/$id');
}
