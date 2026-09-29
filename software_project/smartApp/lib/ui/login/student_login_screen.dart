import 'package:flutter/material.dart';
import 'smart_login_page.dart';

class StudentLoginScreen extends StatelessWidget {
  const StudentLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SmartLoginPage(
      role: UserRole.student,
      onQuickRoleTap: (role) {
        switch (role) {
          case UserRole.admin:
            Navigator.pushReplacementNamed(context, '/login/admin');
            break;
          case UserRole.teacher:
            Navigator.pushReplacementNamed(context, '/login/teacher');
            break;
          case UserRole.student:
            break;
        }
      },
      onSignIn: (email, password, role) =>
          signInWithRole(context, email, password, role),
    );
  }
}
