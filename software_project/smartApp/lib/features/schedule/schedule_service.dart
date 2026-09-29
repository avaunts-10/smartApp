import '../../core/network/api_client.dart';

class Booking {
  const Booking({
    required this.id,
    required this.title,
    required this.teacher,
    required this.room,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.enabled,
    required this.automationEnabled,
    required this.fanMode,
    required this.fanSpeed,
    required this.targetTemperature,
    required this.lightOn,
    required this.lightBrightness,
    required this.attendanceEnabled,
    required this.attendanceGraceMinutes,
    required this.state,
  });

  final int id;
  final String title;
  final String teacher;
  final String room;
  final int weekday;
  final int startMinute;
  final int endMinute;
  final bool enabled;
  final bool automationEnabled;
  final String fanMode;
  final int fanSpeed;
  final double targetTemperature;
  final bool lightOn;
  final int lightBrightness;
  final bool attendanceEnabled;
  final int attendanceGraceMinutes;
  final String state;

  int get startHour => startMinute ~/ 60;
  int get endHour => (endMinute / 60).ceil();
  int get durationMinutes => endMinute - startMinute;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        teacher: json['teacher'] as String,
        room: (json['room'] ?? 'Room 301') as String,
        weekday: (json['weekday'] as num).toInt(),
        startMinute: (json['startMinute'] as num).toInt(),
        endMinute: (json['endMinute'] as num).toInt(),
        enabled: json['enabled'] != false,
        automationEnabled: json['automationEnabled'] != false,
        fanMode: (json['fanMode'] ?? 'auto') as String,
        fanSpeed: (json['fanSpeed'] as num?)?.toInt() ?? 2,
        targetTemperature:
            (json['targetTemperature'] as num?)?.toDouble() ?? 26,
        lightOn: json['lightOn'] != false,
        lightBrightness: (json['lightBrightness'] as num?)?.toInt() ?? 80,
        attendanceEnabled: json['attendanceEnabled'] != false,
        attendanceGraceMinutes:
            (json['attendanceGraceMinutes'] as num?)?.toInt() ?? 10,
        state: (json['state'] ?? 'scheduled') as String,
      );

  Map<String, dynamic> toRequest() => {
        'title': title,
        'teacher': teacher,
        'room': room,
        'weekday': weekday,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'enabled': enabled,
        'automationEnabled': automationEnabled,
        'fanMode': fanMode,
        'fanSpeed': fanSpeed,
        'targetTemperature': targetTemperature,
        'lightOn': lightOn,
        'lightBrightness': lightBrightness,
        'attendanceEnabled': attendanceEnabled,
        'attendanceGraceMinutes': attendanceGraceMinutes,
      };
}

class ScheduleService {
  ScheduleService(this.api);
  final ApiClient api;

  Future<List<Booking>> bookings() async {
    final response = await api.getAuthed('/api/schedule');
    return ((response['bookings'] as List?) ?? const [])
        .map((item) => Booking.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> create(Map<String, dynamic> data) async {
    final response = await api.postAuthed('/api/schedule', data);
    return Booking.fromJson(response['booking'] as Map<String, dynamic>);
  }

  Future<Booking> update(int id, Map<String, dynamic> data) async {
    final response = await api.patchAuthed('/api/schedule/$id', data);
    return Booking.fromJson(response['booking'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> syncAutomation() =>
      api.postAuthed('/api/schedule/automation/sync', const {});

  Future<void> delete(int id) => api.deleteAuthed('/api/schedule/$id');
}
