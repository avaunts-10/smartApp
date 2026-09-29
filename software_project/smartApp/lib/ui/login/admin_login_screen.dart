import 'package:flutter/material.dart';
import 'smart_login_page.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SmartLoginPage(
      role: UserRole.admin,
      onQuickRoleTap: (role) {
        switch (role) {
          case UserRole.admin:
            break;
          case UserRole.teacher:
            Navigator.pushReplacementNamed(context, '/login/teacher');
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
