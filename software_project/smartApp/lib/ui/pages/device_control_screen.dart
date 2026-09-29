import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/app_di.dart';
import '../../features/attendance/attendance_service.dart';
import '../../features/devices/device_model.dart';
import 'app_shell.dart';

class DeviceControlScreen extends StatefulWidget {
  const DeviceControlScreen({super.key});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  List<DeviceModel> _devices = const [];
  List<AttendanceRecord> _rfidActivity = const [];
  final Set<String> _pendingDevices = {};
  final Map<String, int> _draftValues = {};
  bool _initialLoading = true;
  bool _refreshing = false;
  String? _deviceError;
  String? _attendanceError;
  DateTime? _lastUpdated;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (!silent && _devices.isEmpty) _initialLoading = true;
    });

    final deviceRequest = deviceService.fetchDevices();
    final attendanceRequest = attendanceService.today();
    List<DeviceModel>? devices;
    AttendanceDay? attendance;
    Object? deviceFailure;
    Object? attendanceFailure;

    try {
      devices = await deviceRequest;
    } catch (error) {
      deviceFailure = error;
    }

    try {
      attendance = await attendanceRequest;
    } catch (error) {
      attendanceFailure = error;
    }

    if (!mounted) return;
    setState(() {
      if (devices != null) {
        _devices = devices;
        _deviceError = null;
        _lastUpdated = DateTime.now();
        for (final device in devices) {
          if (!_pendingDevices.contains(device.id) &&
              device.sliderValue != null) {
            _draftValues[device.id] = device.sliderValue!;
          }
        }
      } else {
        _deviceError = _message(deviceFailure);
      }

      if (attendance != null) {
        _rfidActivity = attendance.records
            .where((record) => record.method.toLowerCase() == 'rfid')
            .take(5)
            .toList();
        _attendanceError = null;
      } else {
        _attendanceError = _message(attendanceFailure);
      }

      _initialLoading = false;
      _refreshing = false;
    });
  }

  String _message(Object? error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'The device service is unavailable.' : text;
  }

  DeviceModel? _device(String type) {
    for (final device in _devices) {
      if (device.type == type) return device;
    }
    return null;
  }

  void _replaceDevice(DeviceModel updated) {
    final index = _devices.indexWhere((device) => device.id == updated.id);
    if (index < 0) return;
    _devices = [..._devices]..[index] = updated;
    if (updated.sliderValue != null) {
      _draftValues[updated.id] = updated.sliderValue!;
    }
  }

  Future<void> _setPower(DeviceModel device, bool isOn) async {
    if (_pendingDevices.contains(device.id) ||
        !device.online ||
        device.isOn == isOn) {
      return;
    }
    setState(() => _pendingDevices.add(device.id));

    try {
      final updated = await deviceService.updateDevice(
        id: device.id,
        isOn: isOn,
        sliderValue: device.sliderValue,
      );
      if (!mounted) return;
      setState(() {
        _replaceDevice(updated);
        _lastUpdated = DateTime.now();
      });
      _showResult('${device.title} turned ${isOn ? 'ON' : 'OFF'}.',
          success: true);
    } catch (error) {
      if (!mounted) return;
      _showResult('Could not update ${device.title}: ${_message(error)}');
    } finally {
      if (mounted) setState(() => _pendingDevices.remove(device.id));
    }
  }

  Future<void> _setValue(DeviceModel device, int value, String label) async {
    if (_pendingDevices.contains(device.id) || !device.online || !device.isOn) {
      return;
    }
    final previous = device.sliderValue;
    setState(() {
      _pendingDevices.add(device.id);
      _draftValues[device.id] = value;
    });

    try {
      final updated = await deviceService.updateDevice(
        id: device.id,
        isOn: device.isOn,
        sliderValue: value,
      );
      if (!mounted) return;
      setState(() {
        _replaceDevice(updated);
        _lastUpdated = DateTime.now();
      });
      _showResult('${device.title} $label updated.', success: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previous != null) _draftValues[device.id] = previous;
      });
      _showResult('Could not update ${device.title}: ${_message(error)}');
    } finally {
      if (mounted) setState(() => _pendingDevices.remove(device.id));
    }
  }

  void _showResult(String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor:
              success ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
      );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Device Control Center',
      subtitle: 'Monitor and control classroom IoT devices',
      selectedRoute: '/device-control',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) return const _LoadingState();

    if (_devices.isEmpty && _deviceError != null) {
      return _ErrorState(
        message: _deviceError!,
        onRetry: _refreshing ? null : _load,
      );
    }

    final fan = _device('fan');
    final bulb = _device('bulb');
    final rfid = _device('rfid');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Toolbar(
          lastUpdated: _lastUpdated,
          refreshing: _refreshing,
          onlineCount: _devices.where((device) => device.online).length,
          totalCount: _devices.length,
          formatTime: _formatTime,
          onRefresh: _load,
        ),
        if (_deviceError != null) ...[
          const SizedBox(height: 14),
          _Notice(message: 'Showing the last device states. $_deviceError'),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 16.0;
            final twoColumns = constraints.maxWidth >= 720;
            final width = twoColumns
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: width,
                  child: fan == null
                      ? const _MissingDeviceCard(
                          type: 'Fan', icon: Icons.mode_fan_off_rounded)
                      : _FanCard(
                          device: fan,
                          pending: _pendingDevices.contains(fan.id),
                          onPower: (value) => _setPower(fan, value),
                          onSpeed: (value) => _setValue(fan, value, 'speed'),
                        ),
                ),
                SizedBox(
                  width: width,
                  child: bulb == null
                      ? const _MissingDeviceCard(
                          type: 'Classroom Light',
                          icon: Icons.lightbulb_outline_rounded)
                      : _BulbCard(
                          device: bulb,
                          pending: _pendingDevices.contains(bulb.id),
                          draftBrightness:
                              _draftValues[bulb.id] ?? bulb.sliderValue ?? 0,
                          onPower: (value) => _setPower(bulb, value),
                          onBrightnessChanged: (value) => setState(
                              () => _draftValues[bulb.id] = value.round()),
                          onBrightnessSubmitted: (value) =>
                              _setValue(bulb, value.round(), 'brightness'),
                        ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (rfid == null)
          const _MissingDeviceCard(
              type: 'RFID Attendance Tracker', icon: Icons.contactless_rounded)
        else
          _RfidCard(
            device: rfid,
            activity: _rfidActivity,
            activityError: _attendanceError,
            refreshing: _refreshing,
            onRefresh: _load,
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.lastUpdated,
    required this.refreshing,
    required this.onlineCount,
    required this.totalCount,
    required this.formatTime,
    required this.onRefresh,
  });

  final DateTime? lastUpdated;
  final bool refreshing;
  final int onlineCount;
  final int totalCount;
  final String Function(DateTime) formatTime;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub_rounded, color: Color(0xFF2D66F6)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$onlineCount of $totalCount devices online',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastUpdated == null
                        ? 'Last updated: --'
                        : 'Last updated: ${formatTime(lastUpdated!)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(refreshing ? 'Refreshing' : 'Refresh devices'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FanCard extends StatelessWidget {
  const _FanCard({
    required this.device,
    required this.pending,
    required this.onPower,
    required this.onSpeed,
  });

  final DeviceModel device;
  final bool pending;
  final ValueChanged<bool> onPower;
  final ValueChanged<int> onSpeed;

  @override
  Widget build(BuildContext context) {
    final speed = (device.sliderValue ?? 1).clamp(1, 3);
    return _DevicePanel(
      icon: Icons.mode_fan_off_rounded,
      accent: const Color(0xFF2563EB),
      softAccent: const Color(0xFFEFF6FF),
      title: 'Fan',
      subtitle: 'Classroom air circulation',
      device: device,
      pending: pending,
      onPower: onPower,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ControlLabel(label: 'Fan speed'),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final option in const [
                (1, 'Low'),
                (2, 'Medium'),
                (3, 'High')
              ]) ...[
                Expanded(
                  child: _LevelButton(
                    label: option.$2,
                    selected: speed == option.$1,
                    enabled: device.online && device.isOn && !pending,
                    onTap: () => onSpeed(option.$1),
                  ),
                ),
                if (option.$1 != 3) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BulbCard extends StatelessWidget {
  const _BulbCard({
    required this.device,
    required this.pending,
    required this.draftBrightness,
    required this.onPower,
    required this.onBrightnessChanged,
    required this.onBrightnessSubmitted,
  });

  final DeviceModel device;
  final bool pending;
  final int draftBrightness;
  final ValueChanged<bool> onPower;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onBrightnessSubmitted;

  @override
  Widget build(BuildContext context) {
    final brightness = draftBrightness.clamp(0, 100);
    return _DevicePanel(
      icon: Icons.lightbulb_rounded,
      accent: const Color(0xFFEAB308),
      softAccent: const Color(0xFFFFFBE8),
      title: 'Classroom Light',
      subtitle: 'Main classroom illumination',
      device: device,
      pending: pending,
      onPower: onPower,
      child: Column(
        children: [
          Row(
            children: [
              const _ControlLabel(label: 'Brightness'),
              const Spacer(),
              Text(
                '$brightness%',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A)),
              ),
            ],
          ),
          Slider(
            value: brightness.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: const Color(0xFFEAB308),
            onChanged: device.online && device.isOn && !pending
                ? onBrightnessChanged
                : null,
            onChangeEnd: device.online && device.isOn && !pending
                ? onBrightnessSubmitted
                : null,
          ),
        ],
      ),
    );
  }
}

class _DevicePanel extends StatelessWidget {
  const _DevicePanel({
    required this.icon,
    required this.accent,
    required this.softAccent,
    required this.title,
    required this.subtitle,
    required this.device,
    required this.pending,
    required this.onPower,
    required this.child,
  });

  final IconData icon;
  final Color accent;
  final Color softAccent;
  final String title;
  final String subtitle;
  final DeviceModel device;
  final bool pending;
  final ValueChanged<bool> onPower;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: softAccent, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: accent, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _ConnectionBadge(online: device.online),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CURRENT STATUS',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.7,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(
                    device.isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: device.isOn
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B)),
                  ),
                ],
              ),
              const Spacer(),
              if (pending)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5)),
            ],
          ),
          const SizedBox(height: 16),
          _PowerControls(
            isOn: device.isOn,
            enabled: device.online && !pending,
            onChanged: onPower,
          ),
          const Divider(height: 30, color: Color(0xFFEFF2F7)),
          child,
        ],
      ),
    );
  }
}

class _PowerControls extends StatelessWidget {
  const _PowerControls(
      {required this.isOn, required this.enabled, required this.onChanged});

  final bool isOn;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PowerButton(
            label: 'Turn ON',
            icon: Icons.power_settings_new_rounded,
            selected: isOn,
            enabled: enabled && !isOn,
            activeColor: const Color(0xFF15803D),
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PowerButton(
            label: 'Turn OFF',
            icon: Icons.power_off_rounded,
            selected: !isOn,
            enabled: enabled && isOn,
            activeColor: const Color(0xFFB91C1C),
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? activeColor : const Color(0xFF475569),
        backgroundColor:
            selected ? activeColor.withValues(alpha: 0.08) : Colors.white,
        side: BorderSide(
            color: selected
                ? activeColor.withValues(alpha: 0.45)
                : const Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton(
      {required this.label,
      required this.selected,
      required this.enabled,
      required this.onTap});

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: !enabled
                ? const Color(0xFFCBD5E1)
                : selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _RfidCard extends StatelessWidget {
  const _RfidCard({
    required this.device,
    required this.activity,
    required this.activityError,
    required this.refreshing,
    required this.onRefresh,
  });

  final DeviceModel device;
  final List<AttendanceRecord> activity;
  final String? activityError;
  final bool refreshing;
  final VoidCallback onRefresh;

  String _time(DateTime? value) {
    if (value == null) return 'Time unavailable';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final status = !device.online
        ? 'Offline'
        : device.isOn
            ? 'Active'
            : 'Inactive';
    final statusColor = !device.online
        ? const Color(0xFFB91C1C)
        : device.isOn
            ? const Color(0xFF15803D)
            : const Color(0xFFB45309);
    final latest = activity.isEmpty ? null : activity.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.contactless_rounded,
                        color: Color(0xFF7C3AED), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RFID Attendance Tracker',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: statusColor),
                          const SizedBox(width: 6),
                          Text('Reader $status',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh reader'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final latestPanel = _LatestScan(record: latest, time: _time);
              final activityPanel = _RecentActivity(
                  records: activity, time: _time, error: activityError);
              if (!wide) {
                return Column(children: [
                  latestPanel,
                  const SizedBox(height: 14),
                  activityPanel
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: latestPanel),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: activityPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LatestScan extends StatelessWidget {
  const _LatestScan({required this.record, required this.time});

  final AttendanceRecord? record;
  final String Function(DateTime?) time;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: record == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.credit_card_off_rounded,
                    size: 28, color: Color(0xFF94A3B8)),
                SizedBox(height: 9),
                Text('No RFID scans recorded today',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LATEST RFID SCAN',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 13),
                Text(record!.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(record!.studentCode,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                Text('Scanned at ${time(record!.time)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w800)),
              ],
            ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity(
      {required this.records, required this.time, required this.error});

  final List<AttendanceRecord> records;
  final String Function(DateTime?) time;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent scan activity',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (error != null)
            Text('Attendance activity unavailable: $error',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600))
          else if (records.isEmpty)
            const Text('RFID attendance scans will appear here.',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600))
          else
            for (var index = 0; index < records.length; index++) ...[
              _ActivityRow(
                  record: records[index], time: time(records[index].time)),
              if (index != records.length - 1)
                const Divider(height: 18, color: Color(0xFFEFF2F7)),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.record, required this.time});

  final AttendanceRecord record;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
              color: Color(0xFFF5F3FF), shape: BoxShape.circle),
          child: const Icon(Icons.badge_outlined,
              color: Color(0xFF7C3AED), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              Text(record.studentCode,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Text(time,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 6),
          Text(online ? 'Online' : 'Offline',
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800),
      );
}

class _MissingDeviceCard extends StatelessWidget {
  const _MissingDeviceCard({required this.type, required this.icon});

  final String type;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text('$type is not configured',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('No matching device was returned by the API.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: _panelDecoration(),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Connecting to classroom devices...',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(28),
      decoration: _panelDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.router_outlined,
                size: 44, color: Color(0xFFB91C1C)),
            const SizedBox(height: 14),
            const Text('Could not load classroom devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA))),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 9),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x0F0F172A)),
      boxShadow: const [
        BoxShadow(
            color: Color(0x0D0F172A), blurRadius: 24, offset: Offset(0, 10))
      ],
    );
