import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import 'auth_background.dart';
import 'smart_login_page.dart' show UserRole, UserRoleX;

/// Public sign-up form. Visitors may create a Student or Teacher account
/// (admins are seeded server-side). On success the user is logged straight in.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  UserRole _role = UserRole.student;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    final confirm = _confirm.text;

    if (email.isEmpty || pass.isEmpty) {
      _snack('Please enter an email and password');
      return;
    }
    if (pass.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }
    if (pass != confirm) {
      _snack('Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      await authService.register(
        email: email,
        password: pass,
        role: _role.apiValue,
      );
      if (!mounted) return;
      _snack('Account created', error: false);
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2D66F6);

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.5),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      child: const Icon(Icons.person_add_alt_1,
                          color: primaryBlue, size: 26),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join the Smart Classroom platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 26),
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
                          const _Label('I am a'),
                          const SizedBox(height: 8),
                          SegmentedButton<UserRole>(
                            segments: const [
                              ButtonSegment(
                                value: UserRole.student,
                                label: Text('Student'),
                                icon: Icon(Icons.school_outlined),
                              ),
                              ButtonSegment(
                                value: UserRole.teacher,
                                label: Text('Teacher'),
                                icon: Icon(Icons.co_present_outlined),
                              ),
                            ],
                            selected: {_role},
                            onSelectionChanged: (s) =>
                                setState(() => _role = s.first),
                          ),
                          const SizedBox(height: 16),
                          const _Label('Email Address'),
                          const SizedBox(height: 8),
                          _Field(
                            controller: _email,
                            hint: 'you@school.edu',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          const _Label('Password'),
                          const SizedBox(height: 8),
                          _Field(
                            controller: _password,
                            hint: 'At least 6 characters',
                            obscure: _obscure,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _Label('Confirm Password'),
                          const SizedBox(height: 8),
                          _Field(
                            controller: _confirm,
                            hint: 'Re-enter your password',
                            obscure: _obscure,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _submit,
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 18),
                              label: Text(
                                  _loading ? 'Creating...' : 'Create Account'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pushReplacementNamed(
                                      context, '/login/admin'),
                              child: const Text('Already have an account? Sign in'),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.25)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: const Color(0xFF2D66F6).withOpacity(0.5)),
        ),
      ),
    );
  }
}
