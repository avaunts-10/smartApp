import '../../core/network/api_client.dart';

class SensorReading {
  const SensorReading({
    required this.type,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    this.updatedAt,
  });

  final String type;
  final String label;
  final double value;
  final String unit;
  final String status;
  final DateTime? updatedAt;

  bool get isWarning => status.toLowerCase() == 'warning';

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final value = json['value'];
    final unit = json['unit'];
    if (type is! String || value is! num || unit is! String) {
      throw const FormatException('Invalid environmental sensor reading');
    }

    return SensorReading(
      type: type,
      label: json['label'] is String ? json['label'] as String : type,
      value: value.toDouble(),
      unit: unit,
      status: json['status'] is String ? json['status'] as String : 'normal',
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

class EnvironmentLatest {
  const EnvironmentLatest({required this.sensors, required this.updatedAt});

  final List<SensorReading> sensors;
  final DateTime? updatedAt;

  SensorReading? byType(String type) {
    for (final s in sensors) {
      if (s.type == type) return s;
    }
    return null;
  }
}

/// A single point on a sensor history chart. [t] is minutes on a 0..window axis
/// (0 = oldest, window = now).
class SeriesPoint {
  const SeriesPoint(this.t, this.value);
  final double t;
  final double value;
}

class EnvironmentHistory {
  const EnvironmentHistory({required this.minutes, required this.series});

  final int minutes;
  final Map<String, List<SeriesPoint>> series;
}

class EnvironmentService {
  EnvironmentService(this.api);
  final ApiClient api;

  Future<EnvironmentLatest> latest() async {
    final res = await api.getAuthed('/api/environment/latest');
    final list = (res['sensors'] as List?) ?? const [];
    return EnvironmentLatest(
      sensors: list
          .map((e) => SensorReading.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: res['updatedAt'] == null
          ? null
          : DateTime.tryParse(res['updatedAt'] as String),
    );
  }

  Future<EnvironmentHistory> history({int minutes = 20}) async {
    final res =
        await api.getAuthed('/api/environment/history?minutes=$minutes');
    final series = (res['series'] as Map?) ?? const {};
    final parsed = <String, List<SeriesPoint>>{};

    for (final entry in series.entries) {
      if (entry.key is! String || entry.value is! List) continue;
      final points = <SeriesPoint>[];
      for (final point in entry.value as List) {
        if (point is! Map) continue;
        final t = point['t'];
        final value = point['value'];
        if (t is num && value is num) {
          points.add(SeriesPoint(t.toDouble(), value.toDouble()));
        }
      }
      parsed[entry.key as String] = points;
    }

    return EnvironmentHistory(
      minutes:
          res['minutes'] is num ? (res['minutes'] as num).toInt() : minutes,
      series: parsed,
    );
  }
}
