import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/admin/admin_service.dart';
import 'app_shell.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  String? _error;
  UserDirectory? _dir;
  String _filter = 'all'; // all | admin | teacher | student

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;
  bool _mid(BuildContext c) => MediaQuery.of(c).size.width >= 680;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = await adminService.users();
      if (!mounted) return;
      setState(() {
        _dir = dir;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openAddUser() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddUserDialog(),
    );
    if (created == true) _load();
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
            '${user.email} (${user.role}) will lose access immediately. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await adminService.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.email} removed')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpiCols = _wide(context) ? 4 : (_mid(context) ? 2 : 1);

    return AppShell(
      title: 'User Management',
      subtitle: 'Every account on the platform, by role',
      selectedRoute: '/admin-users',
      actions: [
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: _openAddUser,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Add User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
        ),
      ],
      body: _loading
          ? const SizedBox(
              height: 300, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load users\n$_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _content(kpiCols),
    );
  }

  Widget _content(int kpiCols) {
    final dir = _dir!;
    final filtered = _filter == 'all'
        ? dir.users
        : dir.users.where((u) => u.role == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Grid(
          columns: kpiCols,
          children: [
            _KpiCard(
              title: 'Total Accounts',
              value: '${dir.total}',
              icon: Icons.groups_outlined,
              iconBg: const Color(0xFFDCEBFF),
              iconColor: const Color(0xFF2563EB),
            ),
            _KpiCard(
              title: 'Admins',
              value: '${dir.admins}',
              icon: Icons.admin_panel_settings_outlined,
              iconBg: const Color(0xFFF1E8FF),
              iconColor: const Color(0xFF7C3AED),
            ),
            _KpiCard(
              title: 'Teachers',
              value: '${dir.teachers}',
              icon: Icons.school_outlined,
              iconBg: const Color(0xFFDDFBE7),
              iconColor: const Color(0xFF16A34A),
            ),
            _KpiCard(
              title: 'Students',
              value: '${dir.students}',
              icon: Icons.face_outlined,
              iconBg: const Color(0xFFFFF0D6),
              iconColor: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text('All Accounts',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
            _RoleFilter(
              selected: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CardShell(
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No accounts in this role.')),
                )
              : Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1, color: Colors.black.withOpacity(0.05)),
                      _UserRow(
                        user: filtered[i],
                        isSelf: filtered[i].id == authService.user.value?.id,
                        onDelete: () => _confirmDelete(filtered[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/* ---------------- add user dialog ---------------- */

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'student';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await adminService.createUser(
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add teacher or student'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email address'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                  labelText: 'Password (min 6 characters)'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'teacher', label: Text('Teacher')),
                ButtonSegment(value: 'student', label: Text('Student')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

/* ---------------- widgets ---------------- */

class _RoleFilter extends StatelessWidget {
  const _RoleFilter({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('all', 'All'),
      ('admin', 'Admins'),
      ('teacher', 'Teachers'),
      ('student', 'Students'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final sel = o.$1 == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(o.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                o.$2,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.onDelete,
  });
  final AdminUser user;
  final bool isSelf;
  final VoidCallback onDelete;

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF7C3AED);
      case 'teacher':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.role);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(Icons.person, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Joined ${_fmtDate(user.createdAt)}',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.black.withOpacity(0.5))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.role,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: color),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: isSelf
                ? Tooltip(
                    message: "That's you — sign out to remove this account",
                    child: Icon(Icons.lock_outline,
                        size: 18, color: Colors.black.withOpacity(0.25)),
                  )
                : IconButton(
                    tooltip: 'Remove account',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: Colors.red.withOpacity(0.75)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 16),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      const spacing = 14.0;
      final w = c.maxWidth;
      final itemW = (w - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            children.map((e) => SizedBox(width: itemW, child: e)).toList(),
      );
    });
  }
}
