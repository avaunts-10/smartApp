import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../core/di/app_di.dart';
import '../../features/environment/environment_service.dart';
import 'app_shell.dart';

const _sensorOrder = [
  'temperature',
  'humidity',
  'light',
  'air_quality',
  'noise',
];

const _sensorVisuals = <String, _SensorVisual>{
  'temperature': _SensorVisual(
    icon: Icons.thermostat_rounded,
    color: Color(0xFFF97316),
    softColor: Color(0xFFFFF1E8),
  ),
  'humidity': _SensorVisual(
    icon: Icons.water_drop_rounded,
    color: Color(0xFF2563EB),
    softColor: Color(0xFFEFF6FF),
  ),
  'light': _SensorVisual(
    icon: Icons.light_mode_rounded,
    color: Color(0xFFEAB308),
    softColor: Color(0xFFFFFBE8),
  ),
  'air_quality': _SensorVisual(
    icon: Icons.air_rounded,
    color: Color(0xFF16A34A),
    softColor: Color(0xFFECFDF5),
  ),
  'noise': _SensorVisual(
    icon: Icons.graphic_eq_rounded,
    color: Color(0xFF7C3AED),
    softColor: Color(0xFFF5F3FF),
  ),
};

class EnvironmentalScreen extends StatelessWidget {
  const EnvironmentalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      title: 'Environmental Monitoring',
      subtitle: 'Real-time IoT classroom conditions',
      selectedRoute: '/environmental',
      body: _EnvironmentalBody(),
    );
  }
}

class _EnvironmentalBody extends StatefulWidget {
  const _EnvironmentalBody();

  @override
  State<_EnvironmentalBody> createState() => _EnvironmentalBodyState();
}

class _EnvironmentalBodyState extends State<_EnvironmentalBody> {
  IO.Socket? _socket;
  bool _socketConnected = false;

  bool _initialLoading = true;
  bool _refreshing = false;
  String? _latestError;
  String? _historyError;
  List<SensorReading> _sensors = const [];
  EnvironmentHistory _history = const EnvironmentHistory(
    minutes: 20,
    series: {},
  );
  DateTime? _updatedAt;
  String _selectedChart = 'temperature';
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _refresh();
    _connectSocket();
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      if (!silent && _sensors.isEmpty) _initialLoading = true;
    });

    final latestRequest = environmentService.latest();
    final historyRequest = environmentService.history(minutes: 20);
    EnvironmentLatest? latest;
    EnvironmentHistory? history;
    Object? latestFailure;
    Object? historyFailure;

    try {
      latest = await latestRequest;
    } catch (error) {
      latestFailure = error;
    }

    try {
      history = await historyRequest;
    } catch (error) {
      historyFailure = error;
    }

    if (!mounted) return;
    setState(() {
      if (latest != null) {
        _sensors = latest.sensors;
        _updatedAt = latest.updatedAt;
        _latestError = null;
      } else {
        _latestError = _errorMessage(latestFailure);
      }

      if (history != null) {
        _history = history;
        _historyError = null;
      } else {
        _historyError = _errorMessage(historyFailure);
      }

      _initialLoading = false;
      _refreshing = false;
    });
  }

  String _errorMessage(Object? error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? 'The sensor service is currently unavailable.'
        : message;
  }

  _StatusInfo _statusFor(SensorReading sensor) {
    final value = sensor.value;
    switch (sensor.type) {
      case 'temperature':
        if (value < 18) return _StatusInfo.low;
        if (value > 26) return _StatusInfo.high;
      case 'humidity':
        if (value < 35) return _StatusInfo.low;
        if (value > 70) return _StatusInfo.high;
      case 'light':
        if (value < 200) return _StatusInfo.low;
        if (value > 700) return _StatusInfo.high;
      case 'air_quality':
        if (value > 450) return _StatusInfo.high;
      case 'noise':
        if (value < 30) return _StatusInfo.low;
        if (value > 60) return _StatusInfo.high;
    }
    return sensor.isWarning ? _StatusInfo.high : _StatusInfo.normal;
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day/$month/${local.year}  $hour:$minute:$second';
  }

  bool get _isLive {
    return _socketConnected && _updatedAt != null && _latestError == null;
  }

  void _connectSocket() {
    final socket = IO.io(
      'http://localhost:4000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      debugPrint('Socket.IO connected: ${socket.id}');

      if (mounted) {
        setState(() {
          _socketConnected = true;
        });
      }
    });

    socket.onDisconnect((_) {
      debugPrint('Socket.IO disconnected');

      if (mounted) {
        setState(() {
          _socketConnected = false;
        });
      }
    });

    socket.onConnectError((error) {
      debugPrint('Socket.IO connection error: $error');

      if (mounted) {
        setState(() {
          _socketConnected = false;
        });
      }
    });

    socket.on('sensorData', (data) {
      debugPrint('Live sensor data received: $data');

      if (data is! Map) return;

      try {
        final reading = SensorReading.fromJson(
          Map<String, dynamic>.from(data),
        );

        if (!mounted) return;

        setState(() {
          final updated = [..._sensors];
          final index =
              updated.indexWhere((sensor) => sensor.type == reading.type);

          if (index >= 0) {
            updated[index] = reading;
          } else {
            updated.add(reading);
          }

          _sensors = updated;
          _updatedAt = reading.updatedAt ?? DateTime.now();
          _latestError = null;
        });
      } catch (error) {
        debugPrint('Invalid live sensor data: $error');
      }
    });

    socket.connect();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const _LoadingState();

    if (_sensors.isEmpty && _latestError != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Sensor data is unavailable',
        message: _latestError!,
        buttonLabel: 'Try again',
        onPressed: _refreshing ? null : _refresh,
      );
    }

    if (_sensors.isEmpty) {
      return _MessageState(
        icon: Icons.sensors_off_rounded,
        title: 'Waiting for sensor readings',
        message:
            'The API is connected, but no classroom readings have been received yet.',
        buttonLabel: 'Refresh',
        onPressed: _refreshing ? null : _refresh,
      );
    }

    final sensorsByType = {for (final sensor in _sensors) sensor.type: sensor};
    final cards = [
      for (final type in _sensorOrder)
        if (sensorsByType[type] case final sensor?)
          _SensorCard(
            sensor: sensor,
            status: _statusFor(sensor),
            fallbackUpdatedAt: _updatedAt,
          ),
    ];
    final availableCharts = [
      for (final type in _sensorOrder)
        if ((_history.series[type] ?? const []).isNotEmpty) type,
    ];
    final selectedChart = availableCharts.contains(_selectedChart)
        ? _selectedChart
        : (availableCharts.isEmpty ? _selectedChart : availableCharts.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageToolbar(
          isLive: _isLive,
          isRefreshing: _refreshing,
          updatedAt: _updatedAt,
          formatDateTime: _formatDateTime,
          onRefresh: _refresh,
        ),
        if (_latestError != null) ...[
          const SizedBox(height: 14),
          _InlineNotice(
            icon: Icons.wifi_off_rounded,
            message: 'Showing the last received readings. $_latestError',
          ),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _HistoryPanel(
          history: _history,
          sensorsByType: sensorsByType,
          availableTypes: availableCharts,
          selectedType: selectedChart,
          error: _historyError,
          onSelected: (type) => setState(() => _selectedChart = type),
          onRetry: _refreshing ? null : _refresh,
        ),
      ],
    );
  }
}

class _PageToolbar extends StatelessWidget {
  const _PageToolbar({
    required this.isLive,
    required this.isRefreshing,
    required this.updatedAt,
    required this.formatDateTime,
    required this.onRefresh,
  });

  final bool isLive;
  final bool isRefreshing;
  final DateTime? updatedAt;
  final String Function(DateTime) formatDateTime;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final liveColor =
        isLive ? const Color(0xFF15803D) : const Color(0xFFB45309);
    final liveBackground =
        isLive ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    const Icon(Icons.sensors_rounded, color: Color(0xFF2D66F6)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Classroom sensor network',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    updatedAt == null
                        ? 'Last updated: waiting for data'
                        : 'Last updated: ${formatDateTime(updatedAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: liveBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: liveColor),
                    const SizedBox(width: 7),
                    Text(
                      isLive ? 'Live monitoring' : 'Connection delayed',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: liveColor),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: isRefreshing ? null : onRefresh,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isRefreshing ? 'Refreshing' : 'Refresh'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.sensor,
    required this.status,
    required this.fallbackUpdatedAt,
  });

  final SensorReading sensor;
  final _StatusInfo status;
  final DateTime? fallbackUpdatedAt;

  String _time(DateTime? value) {
    if (value == null) return 'Time unavailable';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return 'Updated $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final visual = _sensorVisuals[sensor.type] ?? _SensorVisual.fallback;
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: visual.softColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: visual.color, size: 24),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: status.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            sensor.label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  sensor.value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  sensor.unit,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: visual.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 24, color: Color(0xFFEFF2F7)),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 15, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                _time(sensor.updatedAt ?? fallbackUpdatedAt),
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.history,
    required this.sensorsByType,
    required this.availableTypes,
    required this.selectedType,
    required this.error,
    required this.onSelected,
    required this.onRetry,
  });

  final EnvironmentHistory history;
  final Map<String, SensorReading> sensorsByType;
  final List<String> availableTypes;
  final String selectedType;
  final String? error;
  final ValueChanged<String> onSelected;
  final VoidCallback? onRetry;

  (double, double) _bounds(List<SeriesPoint> points) {
    var min = points.first.value;
    var max = points.first.value;
    for (final point in points.skip(1)) {
      if (point.value < min) min = point.value;
      if (point.value > max) max = point.value;
    }
    final padding = ((max - min) * 0.2).clamp(1.0, 1000.0);
    return ((min - padding).floorToDouble(), (max + padding).ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final sensor = sensorsByType[selectedType];
    final visual = _sensorVisuals[selectedType] ?? _SensorVisual.fallback;
    final points = history.series[selectedType] ?? const <SeriesPoint>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sensor history',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Readings from the last ${history.minutes} minutes',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (availableTypes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in availableTypes)
                      ChoiceChip(
                        label: Text(sensorsByType[type]?.label ??
                            type.replaceAll('_', ' ')),
                        selected: type == selectedType,
                        onSelected: (_) => onSelected(type),
                        selectedColor:
                            (_sensorVisuals[type] ?? _SensorVisual.fallback)
                                .softColor,
                        side: BorderSide(
                          color: type == selectedType
                              ? (_sensorVisuals[type] ?? _SensorVisual.fallback)
                                  .color
                              : const Color(0xFFE2E8F0),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: type == selectedType
                              ? (_sensorVisuals[type] ?? _SensorVisual.fallback)
                                  .color
                              : const Color(0xFF64748B),
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (points.isNotEmpty)
            _SensorLineChart(
              points: points,
              minutes: history.minutes,
              color: visual.color,
              unit: sensor?.unit ?? '',
              bounds: _bounds(points),
            )
          else
            _ChartEmptyState(error: error, onRetry: onRetry),
          if (points.isNotEmpty && error != null) ...[
            const SizedBox(height: 12),
            const _InlineNotice(
              icon: Icons.history_toggle_off_rounded,
              message:
                  'The chart could not update. Showing the most recent history available.',
            ),
          ],
        ],
      ),
    );
  }
}

class _SensorLineChart extends StatelessWidget {
  const _SensorLineChart({
    required this.points,
    required this.minutes,
    required this.color,
    required this.unit,
    required this.bounds,
  });

  final List<SeriesPoint> points;
  final int minutes;
  final Color color;
  final String unit;
  final (double, double) bounds;

  @override
  Widget build(BuildContext context) {
    final interval = minutes / 4;
    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: minutes.toDouble(),
          minY: bounds.$1,
          maxY: bounds.$2,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: (bounds.$2 - bounds.$1) / 4,
            verticalInterval: interval,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFEFF2F7), strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                const FlLine(color: Color(0xFFF4F6F9), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final remaining = (minutes - value).round();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      remaining <= 0 ? 'now' : '${remaining}m',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} $unit',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final point in points) FlSpot(point.t, point.value)],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.24),
                    color.withValues(alpha: 0.02)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: _panelDecoration(),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Connecting to classroom sensors...',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(28),
      decoration: _panelDecoration(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: const Color(0xFFE11D48)),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    height: 1.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart_rounded,
                size: 34, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              error == null
                  ? 'Historical readings are not available yet.'
                  : 'Historical readings could not be loaded.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFB45309)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w700),
            ),
          ),
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
            color: Color(0x0D0F172A), blurRadius: 24, offset: Offset(0, 10)),
      ],
    );

class _SensorVisual {
  const _SensorVisual(
      {required this.icon, required this.color, required this.softColor});

  final IconData icon;
  final Color color;
  final Color softColor;

  static const fallback = _SensorVisual(
    icon: Icons.sensors_rounded,
    color: Color(0xFF2D66F6),
    softColor: Color(0xFFE8F0FF),
  );
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;

  static const normal =
      _StatusInfo('Normal', Color(0xFF15803D), Color(0xFFECFDF5));
  static const high = _StatusInfo('High', Color(0xFFB45309), Color(0xFFFFF7ED));
  static const low = _StatusInfo('Low', Color(0xFF2563EB), Color(0xFFEFF6FF));
}
