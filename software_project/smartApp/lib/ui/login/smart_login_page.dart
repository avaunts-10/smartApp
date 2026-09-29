import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';

enum UserRole { admin, teacher, student }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
    }
  }

  /// Matches the role strings the backend stores ('admin' | 'teacher' | 'student').
  String get apiValue => name;

  String get defaultEmail {
    switch (this) {
      case UserRole.admin:
        return 'admin@classroom.com';
      case UserRole.teacher:
        return 'teacher@classroom.com';
      case UserRole.student:
        return 'student@classroom.com';
    }
  }
}

/// Shared sign-in flow for all three role login screens.
///
/// Verifies the credentials against the backend, enforces that the account's
/// role matches the login tab that was used, then navigates to the dashboard.
/// Throws a user-safe message on any failure (the caller shows it).
Future<void> signInWithRole(
  BuildContext context,
  String email,
  String password,
  UserRole role,
) async {
  final user = await authService.login(email: email, password: password);

  if (user.role != role.apiValue) {
    await authService.logout();
    throw Exception(
      'This account is not a ${role.label} account. '
      'Please use the correct login for your role.',
    );
  }

  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, '/dashboard');
}

class SmartLoginPage extends StatefulWidget {
  const SmartLoginPage({
    super.key,
    required this.role,
    this.onSignIn,
    this.onQuickRoleTap,
  });

  final UserRole role;
  final Future<void> Function(String email, String password, UserRole role)?
  onSignIn;
  final void Function(UserRole role)? onQuickRoleTap;
    

  @override
  State<SmartLoginPage> createState() => _SmartLoginPageState();
}

class _SmartLoginPageState extends State<SmartLoginPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.role.defaultEmail);
    _password = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant SmartLoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _email.text = widget.role.defaultEmail;
      _password.clear();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _email.text.trim();
    final pass = _password.text;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    if (widget.onSignIn == null) return;

    setState(() => _loading = true);
    try {
      await widget.onSignIn!(email, pass, widget.role);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2D66F6);

    return Scaffold(
      body: _LoginBackground(
        role: widget.role,
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.7),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo box
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            color: Colors.black.withOpacity(0.25),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: primaryBlue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title / subtitle
                    const Text(
                      'Smart Classroom IoT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Intelligent classroom management system',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Card
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                            color: Colors.black.withOpacity(0.12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Email Address'),
                          const SizedBox(height: 8),
                          _AppTextField(
                            controller: _email,
                            hintText: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          const _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          _AppTextField(
                            controller: _password,
                            hintText: 'Enter your password',
                            obscureText: _obscure,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _handleSignIn,
                              icon: const Icon(
                                Icons.verified_user_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _loading ? 'Signing In...' : 'Sign In',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                          Text(
                            'Quick Login:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.55),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _QuickRoleButton(
                                  text: 'Admin',
                                  selected: widget.role == UserRole.admin,
                                  onTap: () => widget.onQuickRoleTap?.call(
                                    UserRole.admin,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickRoleButton(
                                  text: 'Teacher',
                                  selected: widget.role == UserRole.teacher,
                                  onTap: () => widget.onQuickRoleTap?.call(
                                    UserRole.teacher,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickRoleButton(
                                  text: 'Student',
                                  selected: widget.role == UserRole.student,
                                  onTap: () => widget.onQuickRoleTap?.call(
                                    UserRole.student,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 28),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.55),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/register'),
                                  child: const Text(
                                    'Create one',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D66F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All three login screens share the same real classroom photo background.
class _LoginBackground extends StatelessWidget {
  const _LoginBackground({required this.role, required this.child});

  final UserRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/classroom_blue_bg.jpg', fit: BoxFit.cover),
        Container(color: const Color(0xFF0B2A4A).withOpacity(0.35)),
        child,
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: Colors.black.withOpacity(0.7),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.25)),
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFF2D66F6).withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

class _QuickRoleButton extends StatelessWidget {
  const _QuickRoleButton({
    required this.text,
    required this.onTap,
    required this.selected,
  });

  final String text;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Material(
        color: selected ? const Color(0xFFEAF1FF) : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF2D66F6)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
