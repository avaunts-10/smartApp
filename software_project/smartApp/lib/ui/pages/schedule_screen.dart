import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/devices/device_model.dart';
import '../../features/environment/environment_service.dart';
import '../../features/schedule/schedule_service.dart';
import 'app_shell.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  List<Booking> _bookings = const [];
  EnvironmentLatest? _environment;
  List<DeviceModel> _devices = const [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  late int _selectedDay;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final weekday = DateTime.now().weekday;
    _selectedDay = weekday <= 5 ? weekday : 1;
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 30),
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
      final results = await Future.wait([
        scheduleService.bookings(),
        environmentService.latest(),
        deviceService.fetchDevices(),
      ]);
      if (!mounted) return;
      setState(() {
        _bookings = results[0] as List<Booking>;
        _environment = results[1] as EnvironmentLatest;
        _devices = results[2] as List<DeviceModel>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Booking? get _active {
    for (final booking in _bookings) {
      if (booking.state == 'active') return booking;
    }
    return null;
  }

  Booking? get _next {
    if (_bookings.isEmpty) return null;
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    final candidates = _bookings.where((booking) => booking.enabled).toList()
      ..sort((a, b) {
        int distance(Booking booking) {
          var days = booking.weekday - now.weekday;
          if (days < 0 || (days == 0 && booking.startMinute <= currentMinute)) {
            days += 7;
          }
          return days * 1440 + booking.startMinute - currentMinute;
        }

        return distance(a).compareTo(distance(b));
      });
    return candidates.isEmpty ? null : candidates.first;
  }

  DeviceModel? _device(String id) {
    for (final device in _devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  Future<void> _edit([Booking? booking]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ClassDialog(initial: booking),
    );
    if (data == null) return;
    try {
      if (booking == null) {
        await scheduleService.create(data);
      } else {
        await scheduleService.update(booking.id, data);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(booking == null ? 'Class scheduled' : 'Class updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _delete(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class?'),
        content:
            Text('${booking.title} will be removed from the weekly schedule.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await scheduleService.delete(booking.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final result = await scheduleService.syncAutomation();
      await _load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result['message'] as String? ?? 'IoT preset applied')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _bookings.where((b) => b.weekday == _selectedDay).toList();
    return AppShell(
      title: 'Smart Class Schedule',
      subtitle: 'Timetable, attendance windows and automatic room setup',
      selectedRoute: '/schedule',
      actions: [
        if (MediaQuery.sizeOf(context).width < 680)
          IconButton(
            onPressed: () => _edit(),
            tooltip: 'Schedule Class',
            icon: const Icon(Icons.add_circle_outline),
          )
        else
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Schedule Class'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const SizedBox(
                height: 360, child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else ...[
            _OperationsHero(active: _active, next: _next),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final live = _LiveRoomCard(
                  environment: _environment,
                  fan: _device('fan'),
                  light: _device('bulb'),
                  syncing: _syncing,
                  onSync: _sync,
                );
                final summary = _AutomationSummary(bookings: _bookings);
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: live),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: summary),
                        ],
                      )
                    : Column(
                        children: [live, const SizedBox(height: 16), summary]);
              },
            ),
            const SizedBox(height: 22),
            const Text(
              'Weekly Operations',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a day to review classes and their room presets.',
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _days.length; index++)
                  ChoiceChip(
                    label: Text(_days[index]),
                    selected: _selectedDay == index + 1,
                    onSelected: (_) => setState(() => _selectedDay = index + 1),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (selected.isEmpty)
              _EmptyDay(day: _days[_selectedDay - 1], onAdd: () => _edit())
            else
              for (final booking in selected) ...[
                _ClassCard(
                  booking: booking,
                  onEdit: () => _edit(booking),
                  onDelete: () => _delete(booking),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ],
      ),
    );
  }
}

class _OperationsHero extends StatelessWidget {
  const _OperationsHero({required this.active, required this.next});

  final Booking? active;
  final Booking? next;

  @override
  Widget build(BuildContext context) {
    final booking = active ?? next;
    final isActive = active != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071A2E), Color(0xFF123D5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 390,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.sensors : Icons.event_available_outlined,
                      size: 17,
                      color: isActive
                          ? const Color(0xFF5EE8A5)
                          : const Color(0xFF8DCBFF),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isActive ? 'CLASS IN PROGRESS' : 'NEXT AUTOMATION',
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF5EE8A5)
                            : const Color(0xFF8DCBFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  booking?.title ?? 'No classes scheduled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  booking == null
                      ? 'Add a class to automate your classroom.'
                      : '${booking.teacher}  •  ${booking.room}  •  ${_day(booking.weekday)}',
                  style:
                      const TextStyle(color: Color(0xFFBCD0DF), fontSize: 13),
                ),
              ],
            ),
          ),
          if (booking != null)
            _HeroMetric(
              icon: Icons.schedule,
              label: 'Class time',
              value:
                  '${_time(booking.startMinute)} – ${_time(booking.endMinute)}',
            ),
          if (booking != null)
            _HeroMetric(
              icon: Icons.how_to_reg_outlined,
              label: 'Attendance',
              value: booking.attendanceEnabled
                  ? '${booking.attendanceGraceMinutes} min grace'
                  : 'Disabled',
            ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8DCBFF), size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF9CB2C2), fontSize: 10)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      );
}

class _LiveRoomCard extends StatelessWidget {
  const _LiveRoomCard({
    required this.environment,
    required this.fan,
    required this.light,
    required this.syncing,
    required this.onSync,
  });

  final EnvironmentLatest? environment;
  final DeviceModel? fan;
  final DeviceModel? light;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final temperature = environment?.byType('temperature');
    final air = environment?.byType('air_quality');
    return _Panel(
      title: 'Live Room',
      subtitle: 'Current sensors and automated devices',
      trailing: TextButton.icon(
        onPressed: syncing ? null : onSync,
        icon: syncing
            ? const SizedBox.square(
                dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync, size: 17),
        label: const Text('Sync IoT'),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _LiveMetric(
            icon: Icons.thermostat,
            label: 'Temperature',
            value: temperature == null
                ? 'No data'
                : '${temperature.value.toStringAsFixed(1)} ${temperature.unit}',
            warning: temperature?.isWarning ?? false,
          ),
          _LiveMetric(
            icon: Icons.air,
            label: 'Air quality',
            value: air == null
                ? 'No data'
                : '${air.value.toStringAsFixed(0)} ${air.unit}',
            warning: air?.isWarning ?? false,
          ),
          _LiveMetric(
            icon: Icons.mode_fan_off_outlined,
            label: 'Fan',
            value: fan == null
                ? 'Unavailable'
                : (fan!.isOn ? 'On · level ${fan!.sliderValue}' : 'Off'),
            warning: fan != null && !fan!.online,
          ),
          _LiveMetric(
            icon: Icons.lightbulb_outline,
            label: 'Lights',
            value: light == null
                ? 'Unavailable'
                : (light!.isOn ? 'On · ${light!.sliderValue}%' : 'Off'),
            warning: light != null && !light!.online,
          ),
        ],
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric(
      {required this.icon,
      required this.label,
      required this.value,
      required this.warning});
  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFF3DE) : const Color(0xFFF2F7FA),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 19,
                color: warning
                    ? const Color(0xFFC46A00)
                    : const Color(0xFF176B87)),
            const SizedBox(height: 9),
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
            const SizedBox(height: 2),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _AutomationSummary extends StatelessWidget {
  const _AutomationSummary({required this.bookings});
  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final automated =
        bookings.where((b) => b.enabled && b.automationEnabled).length;
    final attendance =
        bookings.where((b) => b.enabled && b.attendanceEnabled).length;
    return _Panel(
      title: 'This Week',
      subtitle: 'Automation coverage',
      child: Column(
        children: [
          _SummaryRow(
              icon: Icons.school_outlined,
              label: 'Scheduled classes',
              value: '${bookings.length}'),
          const Divider(height: 22),
          _SummaryRow(
              icon: Icons.bolt_outlined,
              label: 'IoT automated',
              value: '$automated'),
          const Divider(height: 22),
          _SummaryRow(
              icon: Icons.face_retouching_natural,
              label: 'Attendance enabled',
              value: '$attendance'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF176B87)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700))),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard(
      {required this.booking, required this.onEdit, required this.onDelete});
  final Booking booking;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = booking.state == 'active';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: active ? const Color(0xFF20A875) : const Color(0xFFDCE5EA),
            width: active ? 1.5 : 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final details = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(icon: Icons.meeting_room_outlined, text: booking.room),
              _Tag(
                icon: Icons.mode_fan_off_outlined,
                text: booking.automationEnabled
                    ? 'Fan ${booking.fanMode}${booking.fanMode == 'off' ? '' : ' · L${booking.fanSpeed}'}'
                    : 'Automation off',
              ),
              _Tag(
                icon: Icons.lightbulb_outline,
                text: booking.lightOn
                    ? 'Light ${booking.lightBrightness}%'
                    : 'Lights off',
              ),
              _Tag(
                icon: Icons.how_to_reg_outlined,
                text: booking.attendanceEnabled
                    ? 'Attendance +${booking.attendanceGraceMinutes} min'
                    : 'Attendance off',
              ),
            ],
          );
          final heading = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 52,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF20A875)
                      : const Color(0xFF2D66F6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${_time(booking.startMinute)} – ${_time(booking.endMinute)}  •  ${booking.teacher}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
              if (active)
                const _StateBadge(text: 'ACTIVE', color: Color(0xFF16875E)),
              if (!booking.enabled)
                const _StateBadge(text: 'DISABLED', color: Color(0xFF64748B)),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit')),
              IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete class',
                  icon: const Icon(Icons.delete_outline, size: 19)),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 13),
                details,
                const SizedBox(height: 5),
                actions
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: heading), actions]),
              const SizedBox(height: 13),
              details,
            ],
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(9)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF476575)),
            const SizedBox(width: 6),
            Text(text,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: .7)),
      );
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title,
      required this.subtitle,
      required this.child,
      this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFDCE5EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.blueGrey.shade600)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      );
}

class _ClassDialog extends StatefulWidget {
  const _ClassDialog({this.initial});
  final Booking? initial;

  @override
  State<_ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends State<_ClassDialog> {
  late final TextEditingController _title;
  late final TextEditingController _teacher;
  late final TextEditingController _room;
  late int _weekday;
  late int _start;
  late int _end;
  late bool _enabled;
  late bool _automation;
  late String _fanMode;
  late int _fanSpeed;
  late double _targetTemperature;
  late bool _lightOn;
  late double _brightness;
  late bool _attendance;
  late double _grace;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title);
    _teacher = TextEditingController(text: initial?.teacher);
    _room = TextEditingController(text: initial?.room ?? 'Room 301');
    _weekday = initial?.weekday ??
        (DateTime.now().weekday <= 5 ? DateTime.now().weekday : 1);
    _start = initial?.startMinute ?? 540;
    _end = initial?.endMinute ?? 600;
    _enabled = initial?.enabled ?? true;
    _automation = initial?.automationEnabled ?? true;
    _fanMode = initial?.fanMode ?? 'auto';
    _fanSpeed = initial?.fanSpeed ?? 2;
    _targetTemperature = initial?.targetTemperature ?? 26;
    _lightOn = initial?.lightOn ?? true;
    _brightness = (initial?.lightBrightness ?? 80).toDouble();
    _attendance = initial?.attendanceEnabled ?? true;
    _grace = (initial?.attendanceGraceMinutes ?? 10).toDouble();
  }

  @override
  void dispose() {
    _title.dispose();
    _teacher.dispose();
    _room.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty || _teacher.text.trim().isEmpty) {
      setState(() => _error = 'Class name and teacher are required');
      return;
    }
    if (_end <= _start) {
      setState(() => _error = 'End time must be after start time');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': _title.text.trim(),
      'teacher': _teacher.text.trim(),
      'room': _room.text.trim().isEmpty ? 'Room 301' : _room.text.trim(),
      'weekday': _weekday,
      'startMinute': _start,
      'endMinute': _end,
      'enabled': _enabled,
      'automationEnabled': _automation,
      'fanMode': _fanMode,
      'fanSpeed': _fanSpeed,
      'targetTemperature': _targetTemperature,
      'lightOn': _lightOn,
      'lightBrightness': _brightness.round(),
      'attendanceEnabled': _attendance,
      'attendanceGraceMinutes': _grace.round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = [for (var minute = 420; minute <= 1260; minute += 30) minute];
    return AlertDialog(
      title: Text(widget.initial == null
          ? 'Schedule a Class'
          : 'Edit Class Automation'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: _title,
                  decoration:
                      const InputDecoration(labelText: 'Class / subject')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _teacher,
                          decoration:
                              const InputDecoration(labelText: 'Teacher'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: _room,
                          decoration:
                              const InputDecoration(labelText: 'Room'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _weekday,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: [
                        for (var i = 0; i < 5; i++)
                          DropdownMenuItem(
                              value: i + 1, child: Text(_day(i + 1)))
                      ],
                      onChanged: (value) =>
                          setState(() => _weekday = value ?? 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _start,
                      decoration: const InputDecoration(labelText: 'Starts'),
                      items: [
                        for (final slot in slots)
                          DropdownMenuItem(
                              value: slot, child: Text(_time(slot)))
                      ],
                      onChanged: (value) =>
                          setState(() => _start = value ?? 540),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _end,
                      decoration: const InputDecoration(labelText: 'Ends'),
                      items: [
                        for (final slot in slots)
                          DropdownMenuItem(
                              value: slot, child: Text(_time(slot)))
                      ],
                      onChanged: (value) => setState(() => _end = value ?? 600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DialogSection(
                icon: Icons.bolt_outlined,
                title: 'IoT room setup',
                trailing: Switch(
                    value: _automation,
                    onChanged: (value) => setState(() => _automation = value)),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _fanMode,
                      decoration: const InputDecoration(labelText: 'Fan mode'),
                      items: const [
                        DropdownMenuItem(
                            value: 'auto', child: Text('Auto by temperature')),
                        DropdownMenuItem(
                            value: 'on', child: Text('Always on during class')),
                        DropdownMenuItem(value: 'off', child: Text('Keep off')),
                      ],
                      onChanged: _automation
                          ? (value) =>
                              setState(() => _fanMode = value ?? 'auto')
                          : null,
                    ),
                    if (_fanMode != 'off') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: Text('Fan level $_fanSpeed',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1')),
                              ButtonSegment(value: 2, label: Text('2')),
                              ButtonSegment(value: 3, label: Text('3')),
                            ],
                            selected: {_fanSpeed},
                            onSelectionChanged: _automation
                                ? (value) =>
                                    setState(() => _fanSpeed = value.first)
                                : null,
                          ),
                        ],
                      ),
                    ],
                    if (_fanMode == 'auto') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Start fan at ${_targetTemperature.round()}°C',
                              style: const TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _targetTemperature,
                              min: 20,
                              max: 30,
                              divisions: 10,
                              onChanged: _automation
                                  ? (value) =>
                                      setState(() => _targetTemperature = value)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Classroom lights',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      value: _lightOn,
                      onChanged: _automation
                          ? (value) => setState(() => _lightOn = value)
                          : null,
                    ),
                    if (_lightOn)
                      Row(
                        children: [
                          SizedBox(
                              width: 72,
                              child: Text('${_brightness.round()}% brightness',
                                  style: const TextStyle(fontSize: 11))),
                          Expanded(
                            child: Slider(
                              value: _brightness,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              onChanged: _automation
                                  ? (value) =>
                                      setState(() => _brightness = value)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DialogSection(
                icon: Icons.how_to_reg_outlined,
                title: 'Facial attendance window',
                trailing: Switch(
                    value: _attendance,
                    onChanged: (value) => setState(() => _attendance = value)),
                child: Row(
                  children: [
                    SizedBox(
                        width: 120,
                        child: Text('${_grace.round()} min present window',
                            style: const TextStyle(fontSize: 11))),
                    Expanded(
                      child: Slider(
                        value: _grace,
                        min: 0,
                        max: 30,
                        divisions: 6,
                        onChanged: _attendance
                            ? (value) => setState(() => _grace = value)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Class is active in the weekly timetable',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              if (_error != null)
                Text(_error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _save,
            child: Text(
                widget.initial == null ? 'Schedule Class' : 'Save Changes')),
      ],
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection(
      {required this.icon,
      required this.title,
      required this.trailing,
      required this.child});
  final IconData icon;
  final String title;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF4F8FA),
            borderRadius: BorderRadius.circular(13)),
        child: Column(
          children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              trailing
            ]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day, required this.onAdd});
  final String day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE5EA)),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_available_outlined,
                size: 32, color: Color(0xFF7B98A8)),
            const SizedBox(height: 8),
            Text('$day is available',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            TextButton(onPressed: onAdd, child: const Text('Schedule a class')),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

String _day(int weekday) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  return weekday >= 1 && weekday <= 5 ? days[weekday - 1] : 'Unknown';
}

String _time(int minute) {
  final hour = minute ~/ 60;
  final mins = minute % 60;
  final period = hour < 12 ? 'AM' : 'PM';
  final twelveHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelveHour:${mins.toString().padLeft(2, '0')} $period';
}
