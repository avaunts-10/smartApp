import 'package:flutter/material.dart';

import 'core/di/app_di.dart';
import 'core/auth/role_access.dart';
import 'features/auth/auth_service.dart';

import 'ui/login/admin_login_screen.dart';
import 'ui/login/teacher_login_screen.dart';
import 'ui/login/student_login_screen.dart';
import 'ui/login/register_screen.dart';

import 'ui/pages/dashboard_screen.dart';
import 'ui/pages/environmental_screen.dart';
import 'ui/pages/device_control_screen.dart';
import 'ui/pages/attendance_screen.dart';
import 'ui/pages/ai_teacher_screen.dart';
import 'ui/pages/subject_teacher_screen.dart';
import 'ui/pages/learning_screen.dart';
import 'ui/pages/progress_screen.dart';
import 'ui/pages/ai_management_screen.dart';
import 'ui/pages/analytics_screen.dart';
import 'ui/pages/schedule_screen.dart';
import 'ui/pages/students_screen.dart';
import 'ui/pages/admin_users_screen.dart';
import 'ui/pages/notice_board_screen.dart';
import 'ui/pages/materials_screen.dart';
import 'ui/pages/quizzes_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Wraps a screen so it can only be viewed while logged in. If there is no
  /// authenticated user (including a manual URL like /dashboard on web), it
  /// shows the login screen instead.
  static Widget _guarded(Widget page) => _AuthGuard(child: page);

  /// Like [_guarded], but also checks the signed-in user's role against
  /// [roleRoutes] for [route] — typing a staff URL as a student (or vice
  /// versa) bounces back to the dashboard instead of opening the page.
  static Widget _roleGuarded(String route, Widget page) =>
      _AuthGuard(child: _RoleGuard(route: route, child: page));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Classroom IoT',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D66F6)),
        scaffoldBackgroundColor: const Color(0xFFF6F9FF),
      ),
      home: const _AuthGate(),
      routes: {
        '/login/admin': (_) => const AdminLoginScreen(),
        '/login/teacher': (_) => const TeacherLoginScreen(),
        '/login/student': (_) => const StudentLoginScreen(),
        '/register': (_) => const RegisterScreen(),

        '/dashboard': (_) => _guarded(const DashboardScreen()),
        '/environmental': (_) =>
            _roleGuarded('/environmental', const EnvironmentalScreen()),
        '/device-control': (_) =>
            _roleGuarded('/device-control', const DeviceControlScreen()),
        '/attendance': (_) =>
            _roleGuarded('/attendance', const AttendanceScreen()),
        '/students': (_) => _roleGuarded('/students', const StudentsScreen()),
        '/analytics': (_) =>
            _roleGuarded('/analytics', const AnalyticsScreen()),
        '/schedule': (_) => _roleGuarded('/schedule', const ScheduleScreen()),

        '/ai-teacher': (_) =>
            _roleGuarded('/ai-teacher', const AiTeacherScreen()),
        // a subject's classroom: its own 3D teacher + conversation
        '/ai-teacher-3d': (ctx) => _roleGuarded(
              '/ai-teacher-3d',
              SubjectTeacherScreen(
                subject: (ModalRoute.of(ctx)?.settings.arguments as String?) ??
                    'General',
              ),
            ),
        '/learning': (_) => _roleGuarded('/learning', const LearningScreen()),
        '/progress': (_) => _roleGuarded('/progress', const ProgressScreen()),
        '/ai-management': (_) =>
            _roleGuarded('/ai-management', const AiManagementScreen()),
        '/admin-users': (_) =>
            _roleGuarded('/admin-users', const AdminUsersScreen()),
        '/notices': (_) => _roleGuarded('/notices', const NoticeBoardScreen()),
        '/materials': (_) =>
            _roleGuarded('/materials', const MaterialsScreen()),
        '/quizzes': (_) => _roleGuarded('/quizzes', const QuizzesScreen()),
      },
    );
  }
}

/// Shown first. Restores any existing session, then routes to the dashboard
/// (already logged in) or the login screen.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<void> _boot = authService.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ValueListenableBuilder<AuthUser?>(
          valueListenable: authService.user,
          builder: (context, user, _) {
            return user == null
                ? const AdminLoginScreen()
                : const DashboardScreen();
          },
        );
      },
    );
  }
}

class _AuthGuard extends StatelessWidget {
  const _AuthGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: authService.user,
      builder: (context, user, _) {
        if (user == null) return const AdminLoginScreen();
        return child;
      },
    );
  }
}

/// Bounces to the dashboard when the signed-in user's role isn't allowed on
/// [route] (see [roleRoutes]) — e.g. a student who types a staff URL by hand.
/// Assumes it runs inside [_AuthGuard], so a user is always present here.
class _RoleGuard extends StatelessWidget {
  const _RoleGuard({required this.route, required this.child});

  final String route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: authService.user,
      builder: (context, user, _) {
        if (!canAccessRoute(user?.role, route)) {
          return _AccessDenied(route: route);
        }
        return child;
      },
    );
  }
}

class _AccessDenied extends StatefulWidget {
  const _AccessDenied({required this.route});
  final String route;

  @override
  State<_AccessDenied> createState() => _AccessDeniedState();
}

class _AccessDeniedState extends State<_AccessDenied> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("That page isn't available for your account.")),
      );
      Navigator.of(context).pushReplacementNamed('/dashboard');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
