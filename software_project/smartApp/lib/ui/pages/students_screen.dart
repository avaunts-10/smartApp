import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/attendance/attendance_service.dart';
import 'app_shell.dart';
import 'face_view.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool _loading = true;
  String? _error;
  List<Student> _students = const [];
  String? _token;

  @override
  void initState() {
    super.initState();
    apiClient.currentToken().then((t) => setState(() => _token = t));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await attendanceService.students();
      if (!mounted) return;
      setState(() {
        _students = s;
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

  Future<void> _addStudent() async {
    final created = await showDialog<Student>(
      context: context,
      builder: (_) => const _AddStudentDialog(),
    );
    if (created == null) return;

    await _load();
    if (!mounted) return;
    await _enroll(created);
  }

  Future<void> _enroll(Student s) async {
    if (_token == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _EnrollDialog(
        url:
            '$apiBaseUrl/face/index.html?mode=enroll&studentId=${s.id}&token=$_token',
        studentName: s.name,
      ),
    );
    _load();
  }

  Future<void> _clearFaces(Student s) async {
    await attendanceService.clearFaces(s.id);
    _load();
  }

  Future<void> _delete(Student s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: const Text('This also removes their attendance and face data.'),
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
      await attendanceService.deleteStudent(s.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Students',
      subtitle: 'Roster and facial-recognition enrollment',
      selectedRoute: '/attendance',
      actions: [
        TextButton.icon(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/attendance'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to Attendance'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _addStudent,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Student'),
        ),
      ],
      body: SingleChildScrollView(
        child: _loading
            ? const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Could not load students\n$_error',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          ElevatedButton(
                              onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final s in _students)
                        _StudentTile(
                          student: s,
                          onEnroll: () => _enroll(s),
                          onClear: () => _clearFaces(s),
                          onDelete: () => _delete(s),
                        ),
                      if (_students.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('No students yet — add one to start.',
                              style: TextStyle(
                                  color: Colors.black.withOpacity(0.5))),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.onEnroll,
    required this.onClear,
    required this.onDelete,
  });

  final Student student;
  final VoidCallback onEnroll;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enrolled = student.enrolled;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEAF1FF),
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Color(0xFF2D66F6), fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(student.studentCode,
                    style: TextStyle(
                        fontSize: 12, color: Colors.black.withOpacity(0.55))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: enrolled
                  ? const Color(0xFFDDFBE7)
                  : const Color(0xFFFFE9B8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              enrolled ? '${student.faceCount} face(s)' : 'not enrolled',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: enrolled
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFB45309),
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: onEnroll,
            icon: const Icon(Icons.face_retouching_natural, size: 18),
            label: Text(enrolled ? 'Re-enroll' : 'Enroll Face'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'clear' ? onClear() : onDelete(),
            itemBuilder: (_) => [
              if (enrolled)
                const PopupMenuItem(
                    value: 'clear', child: Text('Clear face data')),
              const PopupMenuItem(value: 'delete', child: Text('Delete student')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddStudentDialog extends StatefulWidget {
  const _AddStudentDialog();

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() => _err = 'Name and student ID are required');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final student = await attendanceService.createStudent(
        name: _name.text.trim(),
        studentCode: _code.text.trim(),
        email: _email.text.trim(),
      );
      if (mounted) Navigator.pop(context, student);
    } catch (e) {
      setState(() {
        _err = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Student'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(
                controller: _code,
                decoration:
                    const InputDecoration(labelText: 'Student ID (unique)')),
            const SizedBox(height: 10),
            TextField(
                controller: _email,
                decoration:
                    const InputDecoration(labelText: 'Email (optional)')),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Add & Enroll Face'),
        ),
      ],
    );
  }
}

class _EnrollDialog extends StatelessWidget {
  const _EnrollDialog({required this.url, required this.studentName});
  final String url;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enroll face — $studentName'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FaceView(url: url),
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done')),
      ],
    );
  }
}
