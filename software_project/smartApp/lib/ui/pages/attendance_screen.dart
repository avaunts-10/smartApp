import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/attendance/attendance_service.dart';
import 'app_shell.dart';
import 'face_view.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _filter = 'all';
  bool _loading = true;
  String? _error;
  AttendanceDay? _day;

  bool _cameraOn = false;
  String? _token;
  Timer? _poll;

  bool _wide(BuildContext c) => MediaQuery.of(c).size.width >= 980;
  bool _mid(BuildContext c) => MediaQuery.of(c).size.width >= 680;

  @override
  void initState() {
    super.initState();
    apiClient.currentToken().then((t) => setState(() => _token = t));
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final day = await attendanceService.today();
      if (!mounted) return;
      setState(() {
        _day = day;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<AttendanceRecord> get _filtered {
    final records = _day?.records ?? const [];
    if (_filter == 'all') return records;
    return records.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _day?.summary;

    return AppShell(
      title: 'Attendance Management',
      subtitle: 'Track student attendance with facial recognition',
      selectedRoute: '/attendance',
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/students'),
          icon: const Icon(Icons.group_add_outlined, size: 18),
          label: const Text('Manage Students'),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Grid(
              columns: _wide(context) ? 4 : (_mid(context) ? 2 : 1),
              children: [
                _StatCard(
                    title: 'Total Students',
                    value: '${summary?.total ?? '—'}'),
                _StatCard(
                    title: 'Present',
                    value: '${summary?.present ?? '—'}',
                    accent: const Color(0xFF16A34A)),
                _StatCard(
                    title: 'Late',
                    value: '${summary?.late ?? '—'}',
                    accent: const Color(0xFFF59E0B)),
                _StatCard(
                    title: 'Attendance\nRate',
                    value: summary == null ? '—' : '${summary.rate} %',
                    accent: const Color(0xFF2D66F6)),
              ],
            ),
            const SizedBox(height: 16),
            _CameraCard(
              on: _cameraOn,
              token: _token,
              onToggle: () => setState(() => _cameraOn = !_cameraOn),
              onEvent: (m) {
                if (m['type'] == 'attendance') {
                  _load(silent: true);
                  final s = m['student'];
                  if (s is Map && m['alreadyMarked'] != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${s['name']} marked ${m['status']}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _FilterChipRow(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Reload',
                  onPressed: () => _load(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SizedBox(
                height: 160,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load attendance\n$_error',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      ElevatedButton(
                          onPressed: () => _load(),
                          child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else
              _AttendanceTable(rows: _filtered, wide: _wide(context)),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/* ---------------- camera ---------------- */

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.on,
    required this.token,
    required this.onToggle,
    required this.onEvent,
  });

  final bool on;
  final String? token;
  final VoidCallback onToggle;
  final void Function(Map<String, dynamic>) onEvent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Facial Recognition Camera',
      icon: Icons.photo_camera_outlined,
      iconColor: const Color(0xFF2D66F6),
      trailing: TextButton.icon(
        onPressed: token == null ? null : onToggle,
        icon: Icon(on ? Icons.stop_circle_outlined : Icons.play_circle_outline,
            size: 18),
        label: Text(on ? 'Stop' : 'Start Camera'),
      ),
      child: Container(
        height: MediaQuery.sizeOf(context).width >= 680 ? 500 : 360,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: on && token != null
            ? FaceView(
                url: '$apiBaseUrl/face/index.html?mode=scan&token=$token',
                onMessage: onEvent,
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        color: Colors.white.withOpacity(0.30), size: 42),
                    const SizedBox(height: 10),
                    Text(
                      token == null ? 'Sign in required' : 'Camera is off',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Press "Start Camera" to scan for students',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.40),
                            fontSize: 12)),
                  ],
                ),
              ),
      ),
    );
  }
}

/* ---------------- table ---------------- */

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({required this.rows, required this.wide});
  final List<AttendanceRecord> rows;
  final bool wide;

  String _time(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final ap = l.hour < 12 ? 'AM' : 'PM';
    return '$h:${l.minute.toString().padLeft(2, '0')} $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              blurRadius: 26,
              offset: const Offset(0, 16),
              color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        children: [
          _TableHeader(wide: wide),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No attendance recorded yet',
                  style: TextStyle(color: Colors.black.withOpacity(0.5))),
            )
          else
            ...rows.map((r) => Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: Colors.black.withOpacity(0.06))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 18,
                          child: Text(r.studentCode,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800))),
                      Expanded(
                          flex: 22,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              if (r.classTitle != null)
                                Text(r.classTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.black.withOpacity(0.5))),
                            ],
                          )),
                      Expanded(
                          flex: 18,
                          child: Text(_time(r.time),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.60)))),
                      if (wide)
                        Expanded(
                            flex: 18,
                            child: _MethodBadge(method: r.method)),
                      Expanded(
                          flex: 18,
                          child: _StatusBadge(status: r.status)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: 11,
        color: Colors.black.withOpacity(0.55),
        fontWeight: FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 18, child: Text('Student ID', style: style)),
          Expanded(flex: 22, child: Text('Name', style: style)),
          Expanded(flex: 18, child: Text('Time', style: style)),
          if (wide) Expanded(flex: 18, child: Text('Method', style: style)),
          Expanded(flex: 18, child: Text('Status', style: style)),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final isFacial = method.toLowerCase() == 'facial';
    final bg = isFacial ? const Color(0xFFEFE3FF) : const Color(0xFFDDEBFF);
    final fg = isFacial ? const Color(0xFF7C3AED) : const Color(0xFF2563EB);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isFacial ? Icons.camera_alt_outlined : Icons.badge_outlined,
                size: 14, color: fg),
            const SizedBox(width: 6),
            Text(method.toUpperCase(),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final bg = s == 'present'
        ? const Color(0xFFDDFBE7)
        : (s == 'late' ? const Color(0xFFFFE9B8) : const Color(0xFFEFF4FF));
    final fg = s == 'present'
        ? const Color(0xFF16A34A)
        : (s == 'late' ? const Color(0xFFF59E0B) : const Color(0xFF2D66F6));

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(s,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: fg)),
      ),
    );
  }
}

/* ---------------- filter chips ---------------- */

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pill(String v) {
      final selected = value == v;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2D66F6)
                : const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Text(v,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF334155))),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      children: [pill('all'), pill('present'), pill('late')],
    );
  }
}

/* ---------------- shared ---------------- */

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      const spacing = 14.0;
      final itemW = (c.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children:
            children.map((e) => SizedBox(width: itemW, child: e)).toList(),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, this.accent});
  final String title;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? const Color(0xFF0F172A);
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 14),
              color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w800,
                height: 1.15,
              )),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: a)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              blurRadius: 26,
              offset: const Offset(0, 16),
              color: Colors.black.withOpacity(0.08)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
