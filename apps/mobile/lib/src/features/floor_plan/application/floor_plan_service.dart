import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ficct_final_app/src/data/models/floor_plan.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class FloorPlanService {
  FloorPlanService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<FloorPlan?> pickFloorPlan() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return null;
    }

    final sourceFile = File(image.path);
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final floorPlansDirectory = Directory(
      '${documentsDirectory.path}/floor_plans',
    );

    if (!await floorPlansDirectory.exists()) {
      await floorPlansDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = _safeFileName(image.name, timestamp);
    final copiedFile = await sourceFile.copy(
      '${floorPlansDirectory.path}/$fileName',
    );

    final dimensions = await _readImageDimensions(copiedFile);

    return FloorPlan(
      id: 'floor-plan-$timestamp',
      name: image.name,
      imagePath: copiedFile.path,
      width: dimensions.width,
      height: dimensions.height,
      createdAt: DateTime.now(),
    );
  }

  Future<_ImageDimensions> _readImageDimensions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final completer = Completer<_ImageDimensions>();

    ui.decodeImageFromList(bytes, (image) {
      completer.complete(
        _ImageDimensions(width: image.width, height: image.height),
      );
      image.dispose();
    });

    return completer.future;
  }

  String _safeFileName(String originalName, int timestamp) {
    final sanitized = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${timestamp}_$sanitized';
  }
}

class _ImageDimensions {
  const _ImageDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
