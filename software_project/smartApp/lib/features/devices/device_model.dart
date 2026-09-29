class DeviceCapabilities {
  const DeviceCapabilities({
    required this.control,
    required this.min,
    required this.max,
    required this.unit,
  });

  final String control;
  final int? min;
  final int? max;
  final String? unit;

  factory DeviceCapabilities.fromJson(Map<String, dynamic>? json) {
    return DeviceCapabilities(
      control:
          json?['control'] is String ? json!['control'] as String : 'monitor',
      min: (json?['min'] as num?)?.toInt(),
      max: (json?['max'] as num?)?.toInt(),
      unit: json?['unit'] as String?,
    );
  }
}

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.title,
    required this.type,
    required this.isOn,
    required this.online,
    required this.capabilities,
    this.sliderValue,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String type;
  final bool isOn;
  final bool online;
  final int? sliderValue;
  final DateTime? updatedAt;
  final DeviceCapabilities capabilities;

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) {
      throw const FormatException('Invalid device response');
    }

    return DeviceModel(
      id: id,
      title: title,
      type: json['type'] is String ? json['type'] as String : 'unknown',
      isOn: json['isOn'] == true,
      online: json['online'] == true,
      sliderValue: (json['sliderValue'] as num?)?.toInt(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      capabilities: DeviceCapabilities.fromJson(
        json['capabilities'] is Map<String, dynamic>
            ? json['capabilities'] as Map<String, dynamic>
            : null,
      ),
    );
  }
}
