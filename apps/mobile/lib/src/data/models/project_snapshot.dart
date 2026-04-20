import 'package:ficct_final_app/src/data/models/floor_plan.dart';
import 'package:ficct_final_app/src/data/models/measurement_record.dart';

class ProjectSnapshot {
  const ProjectSnapshot({required this.floorPlan, required this.measurements});

  final FloorPlan? floorPlan;
  final List<MeasurementRecord> measurements;

  factory ProjectSnapshot.empty() {
    return const ProjectSnapshot(floorPlan: null, measurements: []);
  }

  Map<String, Object?> toJson() {
    return {
      'floorPlan': floorPlan?.toJson(),
      'measurements': measurements
          .map((measurement) => measurement.toJson())
          .toList(),
    };
  }

  factory ProjectSnapshot.fromJson(Map<String, dynamic> json) {
    final floorPlanJson = json['floorPlan'] as Map<String, dynamic>?;
    final measurementsJson = json['measurements'] as List<dynamic>? ?? [];

    return ProjectSnapshot(
      floorPlan: floorPlanJson == null
          ? null
          : FloorPlan.fromJson(floorPlanJson),
      measurements: measurementsJson
          .map(
            (measurement) =>
                MeasurementRecord.fromJson(measurement as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
