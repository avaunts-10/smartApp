//slide bar + layout

/*import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedRoute,
    required this.body,
    this.actions,
  });

  final String title;
  final String subtitle;
  final String selectedRoute;
  final Widget body;
  final List<Widget>? actions;

  static const _sidebarWidth = 260.0;

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 980;

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);

    final sidebar = _Sidebar(
      selectedRoute: selectedRoute,
      onNavigate: (route) {
        if (ModalRoute.of(context)?.settings.name == route) return;
        Navigator.pushReplacementNamed(context, route);
      },
    );

    return Scaffold(
      drawer: wide ? null : Drawer(child: SafeArea(child: sidebar)),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: _sidebarWidth,
                child: sidebar,
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: title,
                    subtitle: subtitle,
                    showMenu: !wide,
                    actions: actions,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.showMenu,
    this.actions,
  });

  final String title;
  final String subtitle;
  final bool showMenu;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.55),
                    )),
              ],
            ),
          ),
          ...(actions ?? []),
          const SizedBox(width: 6),
          _UserPill(),
        ],
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFF2D66F6),
            child: Icon(Icons.person, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Admin User',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text('admin',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.55),
                  )),
            ],
          ),
          const SizedBox(width: 10),
          Icon(Icons.logout, size: 18, color: Colors.red.withOpacity(0.85)),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedRoute, required this.onNavigate});

  final String selectedRoute;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.7),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D66F6),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                        color: Colors.black.withOpacity(0.12),
                      )
                    ],
                  ),
                  child:
                      const Icon(Icons.grid_view_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Smart Classroom',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('IoT Management',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: selectedRoute == '/dashboard',
            onTap: () => onNavigate('/dashboard'),
          ),
          _NavItem(
            icon: Icons.thermostat_outlined,
            label: 'Environmental',
            selected: selectedRoute == '/environmental',
            onTap: () => onNavigate('/environmental'),
          ),
          _NavItem(
            icon: Icons.power_settings_new,
            label: 'Device Control',
            selected: selectedRoute == '/device-control',
            onTap: () => onNavigate('/device-control'),
          ),
          _NavItem(
            icon: Icons.how_to_reg_outlined,
            label: 'Attendance',
            selected: selectedRoute == '/attendance',
            onTap: () => onNavigate('/attendance'),
          ),
          _NavItem(
              icon: Icons.query_stats_outlined,
              label: 'Analytics',
              selected: selectedRoute == '/analytics',
              onTap: () => onNavigate('/analytics')),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'AI TEACHING ASSISTANT',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _NavItem(
              icon: Icons.smart_toy_outlined,
              label: 'AI Teacher',
              selected: selectedRoute == '/ai-teacher',
              onTap: () => onNavigate('/ai-teacher')),
          _NavItem(
              icon: Icons.menu_book_outlined,
              label: 'Learning',
              selected: selectedRoute == '/learning',
              onTap: () => onNavigate('/learning')),
          _NavItem(
              icon: Icons.trending_up_outlined,
              label: 'Progress',
              selected: selectedRoute == '/progress',
              onTap: () => onNavigate('/progress')),
          _NavItem(
            icon: Icons.settings_suggest_outlined,
            label: 'AI Management',
            selected: selectedRoute == '/ai-management',
            onTap: () => onNavigate('/ai-management'),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Status',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All systems operational',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.black.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEAF1FF) : Colors.transparent;
    final fg = selected ? const Color(0xFF2D66F6) : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
*/
//after overflow sloving
import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../core/auth/role_access.dart';
import '../../features/auth/auth_service.dart';

/// True when this role's pages render a classroom photo behind the shared
/// shell — the sidebar/top bar go semi-transparent so it shows through.
bool _hasPhotoBg(String? role) =>
    role == 'student' || role == 'admin' || role == 'teacher';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedRoute,
    required this.body,
    this.actions,
    this.solidBackground,
  });

  final String title;
  final String subtitle;
  final String selectedRoute;
  final Widget body;
  final List<Widget>? actions;

  /// When set, replaces the usual per-role classroom-photo background with a
  /// flat color for this screen only (every other screen is unaffected).
  final Color? solidBackground;

  static const _sidebarWidth = 260.0;

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 980;

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    final role = authService.user.value?.role;
    final bgAsset = solidBackground != null ? null : _backgroundFor(role);

    final sidebar = _Sidebar(
      selectedRoute: selectedRoute,
      onNavigate: (route) {
        if (ModalRoute.of(context)?.settings.name == route) return;
        Navigator.pushReplacementNamed(context, route);
      },
    );

    final scaffold = Scaffold(
      backgroundColor:
          solidBackground ?? (bgAsset != null ? Colors.transparent : null),
      drawer: wide ? null : Drawer(child: SafeArea(child: sidebar)),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: _sidebarWidth,
                child: sidebar,
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: title,
                    subtitle: subtitle,
                    showMenu: !wide,
                    actions: actions,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (bgAsset == null) return scaffold;

    // Every page for this role shares a classroom photo behind the
    // (semi-transparent) sidebar/top bar and the gaps between cards.
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(bgAsset, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.32)),
        ),
        scaffold,
      ],
    );
  }

  /// Each role's background photo behind the shared shell, or null for a
  /// plain background.
  static String? _backgroundFor(String? role) {
    switch (role) {
      case 'student':
        return 'assets/images/classroom_bg.jpg';
      case 'admin':
      case 'teacher':
        return 'assets/images/classroom_blue_bg.jpg';
      default:
        return null;
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.showMenu,
    this.actions,
  });

  final String title;
  final String subtitle;
  final bool showMenu;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final hasPhotoBg = _hasPhotoBg(authService.user.value?.role);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(hasPhotoBg ? 0.45 : 0.7),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          ...(actions ?? []),
          const SizedBox(width: 6),
          _UserPill(),
        ],
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login/admin', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: authService.user,
      builder: (context, user, _) {
        final name = user?.email.split('@').first ?? 'Guest';
        final role = user?.role ?? '—';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF2D66F6),
                child: Icon(Icons.person, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => _logout(context),
                icon: Icon(Icons.logout,
                    size: 18, color: Colors.red.withOpacity(0.85)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedRoute, required this.onNavigate});

  final String selectedRoute;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: authService.user,
      builder: (context, user, _) {
        final role = user?.role;
        bool allowed(String route) => canAccessRoute(role, route);

        // Classroom-operations tools: staff only (see roleRoutes).
        final opsItems = <Widget>[
          if (allowed('/dashboard'))
            _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: selectedRoute == '/dashboard',
              onTap: () => onNavigate('/dashboard'),
            ),
          if (allowed('/environmental'))
            _NavItem(
              icon: Icons.thermostat_outlined,
              label: 'Environmental',
              selected: selectedRoute == '/environmental',
              onTap: () => onNavigate('/environmental'),
            ),
          if (allowed('/device-control'))
            _NavItem(
              icon: Icons.power_settings_new,
              label: 'Device Control',
              selected: selectedRoute == '/device-control',
              onTap: () => onNavigate('/device-control'),
            ),
          if (allowed('/attendance'))
            _NavItem(
              icon: Icons.how_to_reg_outlined,
              label: 'Attendance',
              selected: selectedRoute == '/attendance',
              onTap: () => onNavigate('/attendance'),
            ),
          if (allowed('/analytics'))
            _NavItem(
              icon: Icons.query_stats_outlined,
              label: 'Analytics',
              selected: selectedRoute == '/analytics',
              onTap: () => onNavigate('/analytics'),
            ),
          if (allowed('/schedule'))
            _NavItem(
              icon: Icons.calendar_month_outlined,
              label: 'Smart Schedule',
              selected: selectedRoute == '/schedule',
              onTap: () => onNavigate('/schedule'),
            ),
          if (allowed('/admin-users'))
            _NavItem(
              icon: Icons.admin_panel_settings_outlined,
              label: 'User Management',
              selected: selectedRoute == '/admin-users',
              onTap: () => onNavigate('/admin-users'),
            ),
          if (allowed('/notices'))
            _NavItem(
              icon: Icons.campaign_outlined,
              label: 'Notice Board',
              selected: selectedRoute == '/notices',
              onTap: () => onNavigate('/notices'),
            ),
          if (allowed('/materials'))
            _NavItem(
              icon: Icons.folder_copy_outlined,
              label: 'Materials',
              selected: selectedRoute == '/materials',
              onTap: () => onNavigate('/materials'),
            ),
          if (allowed('/quizzes'))
            _NavItem(
              icon: Icons.quiz_outlined,
              label: 'Quizzes',
              selected: selectedRoute == '/quizzes',
              onTap: () => onNavigate('/quizzes'),
            ),
        ];

        // A student's own AI tutor (chat/learning/progress), or a staff
        // member's console for managing that tutor's lessons and rosters.
        final aiItems = <Widget>[
          if (allowed('/ai-teacher'))
            _NavItem(
              icon: Icons.smart_toy_outlined,
              label: 'AI Teacher',
              selected: selectedRoute == '/ai-teacher',
              onTap: () => onNavigate('/ai-teacher'),
            ),
          if (allowed('/learning'))
            _NavItem(
              icon: Icons.menu_book_outlined,
              label: 'Learning',
              selected: selectedRoute == '/learning',
              onTap: () => onNavigate('/learning'),
            ),
          if (allowed('/progress'))
            _NavItem(
              icon: Icons.trending_up_outlined,
              label: 'Progress',
              selected: selectedRoute == '/progress',
              onTap: () => onNavigate('/progress'),
            ),
          if (allowed('/ai-management'))
            _NavItem(
              icon: Icons.settings_suggest_outlined,
              label: 'AI Management',
              selected: selectedRoute == '/ai-management',
              onTap: () => onNavigate('/ai-management'),
            ),
        ];

        return Container(
          color: Colors.white.withOpacity(_hasPhotoBg(role) ? 0.45 : 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D66F6),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                              color: Colors.black.withOpacity(0.12),
                            )
                          ],
                        ),
                        child: const Icon(Icons.grid_view_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Smart Classroom',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('IoT Management',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ...opsItems,
                if (aiItems.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AI TEACHING ASSISTANT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...aiItems,
                ],
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('System Status',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 10, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'All systems operational',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEAF1FF) : Colors.transparent;
    final fg = selected ? const Color(0xFF2D66F6) : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
