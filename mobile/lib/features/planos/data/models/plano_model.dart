import '../../domain/entities/plano.dart';

/// Modelo de datos: serialización JSON ↔ entidad Plano.
/// HU PB-02 — Sprint 2
class PlanoModel extends Plano {
  const PlanoModel({
    required super.id,
    required super.proyectoId,
    required super.nombre,
    required super.formato,
    required super.anchoPx,
    required super.altoPx,
    required super.tamanoBytes,
    required super.urlFirmada,
    required super.calibrado,
    super.escalaMPorPx,
    super.distanciaRealM,
    super.calibracionX1,
    super.calibracionY1,
    super.calibracionX2,
    super.calibracionY2,
    super.warning,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PlanoModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

    return PlanoModel(
      id: json['id'] as int,
      proyectoId: json['proyecto_id'] as int,
      nombre: json['nombre'] as String,
      formato: FormatoPlano.fromString(json['formato'] as String),
      anchoPx: json['ancho_px'] as int,
      altoPx: json['alto_px'] as int,
      tamanoBytes: json['tamano_bytes'] as int,
      urlFirmada: json['url_firmada'] as String,
      calibrado: json['calibrado'] as bool,
      escalaMPorPx: toDouble(json['escala_m_por_px']),
      distanciaRealM: toDouble(json['distancia_real_m']),
      calibracionX1: toDouble(json['calibracion_x1']),
      calibracionY1: toDouble(json['calibracion_y1']),
      calibracionX2: toDouble(json['calibracion_x2']),
      calibracionY2: toDouble(json['calibracion_y2']),
      warning: json['warning'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
