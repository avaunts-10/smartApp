import 'package:flutter/material.dart';
import 'smart_login_page.dart';

class TeacherLoginScreen extends StatelessWidget {
  const TeacherLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SmartLoginPage(
      role: UserRole.teacher,
      onQuickRoleTap: (role) {
        switch (role) {
          case UserRole.admin:
            Navigator.pushReplacementNamed(context, '/login/admin');
            break;
          case UserRole.teacher:
            break;
          case UserRole.student:
            Navigator.pushReplacementNamed(context, '/login/student');
            break;
        }
      },
      onSignIn: (email, password, role) =>
          signInWithRole(context, email, password, role),
    );
  }
}
