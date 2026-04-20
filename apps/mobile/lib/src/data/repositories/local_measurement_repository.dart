import 'dart:convert';
import 'dart:io';

import 'package:ficct_final_app/src/data/models/floor_plan.dart';
import 'package:ficct_final_app/src/data/models/measurement_record.dart';
import 'package:ficct_final_app/src/data/models/project_snapshot.dart';
import 'package:path_provider/path_provider.dart';

class LocalMeasurementRepository {
  static const _snapshotFileName = 'wireless_heatmapper_snapshot.json';

  Future<ProjectSnapshot> loadSnapshot() async {
    final file = await _snapshotFile();

    if (!await file.exists()) {
      return ProjectSnapshot.empty();
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return ProjectSnapshot.empty();
    }

    return ProjectSnapshot.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
  }

  Future<ProjectSnapshot> saveFloorPlan(FloorPlan floorPlan) async {
    final snapshot = ProjectSnapshot.empty();
    final updated = ProjectSnapshot(
      floorPlan: floorPlan,
      measurements: snapshot.measurements,
    );

    await _writeSnapshot(updated);
    return updated;
  }

  Future<ProjectSnapshot> replaceSnapshot(ProjectSnapshot snapshot) async {
    await _writeSnapshot(snapshot);
    return snapshot;
  }

  Future<ProjectSnapshot> addMeasurement(MeasurementRecord measurement) async {
    final current = await loadSnapshot();
    final updated = ProjectSnapshot(
      floorPlan: current.floorPlan,
      measurements: [...current.measurements, measurement],
    );
    await _writeSnapshot(updated);
    return updated;
  }

  Future<File> _snapshotFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_snapshotFileName');
  }

  Future<void> _writeSnapshot(ProjectSnapshot snapshot) async {
    final file = await _snapshotFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }
}
