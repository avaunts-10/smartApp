import '../../core/network/api_client.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String role; // 'admin' | 'teacher' | 'student'
  final DateTime createdAt;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: (j['id'] as num).toInt(),
        email: j['email'] as String,
        role: j['role'] as String,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class UserDirectory {
  const UserDirectory({
    required this.users,
    required this.admins,
    required this.teachers,
    required this.students,
  });

  final List<AdminUser> users;
  final int admins;
  final int teachers;
  final int students;

  int get total => users.length;
}

/// Admin-only account management, backed by `/api/auth/users`.
class AdminService {
  AdminService(this.api);
  final ApiClient api;

  Future<UserDirectory> users() async {
    final res = await api.getAuthed('/api/auth/users');
    final list = ((res['users'] as List?) ?? const [])
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
    final counts = (res['counts'] as Map?) ?? const {};
    return UserDirectory(
      users: list,
      admins: (counts['admin'] as num?)?.toInt() ?? 0,
      teachers: (counts['teacher'] as num?)?.toInt() ?? 0,
      students: (counts['student'] as num?)?.toInt() ?? 0,
    );
  }

  /// Creates a teacher or student account. Throws a user-safe message on
  /// failure (email taken, weak password, …).
  Future<AdminUser> createUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await api.postAuthed('/api/auth/users', {
      'email': email,
      'password': password,
      'role': role,
    });
    return AdminUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(int id) => api.deleteAuthed('/api/auth/users/$id');
}
