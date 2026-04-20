class FloorPlan {
  const FloorPlan({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String imagePath;
  final int width;
  final int height;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'width': width,
      'height': height,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
