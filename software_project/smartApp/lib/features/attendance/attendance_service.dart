import '../../core/network/api_client.dart';

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.studentCode,
    required this.email,
    required this.faceCount,
  });

  final int id;
  final String name;
  final String studentCode;
  final String? email;
  final int faceCount;

  bool get enrolled => faceCount > 0;

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as int,
        name: j['name'] as String,
        studentCode: j['studentCode'] as String,
        email: j['email'] as String?,
        faceCount: (j['faceCount'] as num?)?.toInt() ?? 0,
      );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.studentCode,
    required this.name,
    required this.method,
    required this.status,
    required this.time,
    this.classTitle,
  });

  final String studentCode;
  final String name;
  final String method; // facial | rfid | manual
  final String status; // present | late
  final DateTime? time;
  final String? classTitle;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        studentCode: j['studentCode'] as String,
        name: j['name'] as String,
        method: (j['method'] ?? 'facial') as String,
        status: (j['status'] ?? 'present') as String,
        time: j['time'] == null ? null : DateTime.tryParse(j['time'] as String),
        classTitle: j['classTitle'] as String?,
      );
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.late,
    required this.absent,
    required this.rate,
  });

  final int total, present, late, absent, rate;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceSummary(
        total: (j['total'] as num).toInt(),
        present: (j['present'] as num).toInt(),
        late: (j['late'] as num).toInt(),
        absent: (j['absent'] as num).toInt(),
        rate: (j['rate'] as num).toInt(),
      );
}

class AttendanceDay {
  const AttendanceDay({required this.summary, required this.records});
  final AttendanceSummary summary;
  final List<AttendanceRecord> records;
}

class AttendanceService {
  AttendanceService(this.api);
  final ApiClient api;

  Future<List<Student>> students() async {
    final res = await api.getAuthed('/api/students');
    return ((res['students'] as List?) ?? const [])
        .map((e) => Student.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Student> createStudent({
    required String name,
    required String studentCode,
    String? email,
  }) async {
    final res = await api.postAuthed('/api/students', {
      'name': name,
      'studentCode': studentCode,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return Student.fromJson(res['student'] as Map<String, dynamic>);
  }

  Future<void> deleteStudent(int id) => api.deleteAuthed('/api/students/$id');

  Future<void> clearFaces(int id) =>
      api.deleteAuthed('/api/students/$id/faces');

  Future<AttendanceDay> today() async {
    final res = await api.getAuthed('/api/attendance');
    return AttendanceDay(
      summary:
          AttendanceSummary.fromJson(res['summary'] as Map<String, dynamic>),
      records: ((res['records'] as List?) ?? const [])
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> markManual(int studentId, {String status = 'present'}) =>
      api.postAuthed('/api/attendance/manual', {
        'studentId': studentId,
        'status': status,
      });
}
