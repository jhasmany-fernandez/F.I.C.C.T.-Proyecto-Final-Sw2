import 'package:ficct_final_app/src/data/models/wifi_reading.dart';

class MeasurementRecord {
  const MeasurementRecord({
    required this.id,
    required this.floorPlanId,
    required this.x,
    required this.y,
    required this.createdAt,
    required this.readings,
  });

  final String id;
  final String floorPlanId;
  final double x;
  final double y;
  final DateTime createdAt;
  final List<WifiReading> readings;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'floorPlanId': floorPlanId,
      'x': x,
      'y': y,
      'createdAt': createdAt.toIso8601String(),
      'readings': readings.map((reading) => reading.toJson()).toList(),
    };
  }

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) {
    return MeasurementRecord(
      id: json['id'] as String,
      floorPlanId: json['floorPlanId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      readings: (json['readings'] as List<dynamic>)
          .map(
            (reading) => WifiReading.fromJson(reading as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
