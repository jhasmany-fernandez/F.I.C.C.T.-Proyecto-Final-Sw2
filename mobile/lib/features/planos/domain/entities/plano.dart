import 'package:equatable/equatable.dart';

/// Formato original del archivo subido (no necesariamente el formato guardado).
/// HU PB-02 — Sprint 2
enum FormatoPlano {
  png,
  jpg,
  pdf;

  String get etiqueta {
    switch (this) {
      case FormatoPlano.png:
        return 'PNG';
      case FormatoPlano.jpg:
        return 'JPG';
      case FormatoPlano.pdf:
        return 'PDF';
    }
  }

  static FormatoPlano fromString(String valor) {
    switch (valor.toLowerCase()) {
      case 'png':
        return FormatoPlano.png;
      case 'jpg':
      case 'jpeg':
        return FormatoPlano.jpg;
      case 'pdf':
        return FormatoPlano.pdf;
      default:
        throw ArgumentError('Formato de plano no soportado: $valor');
    }
  }
}

/// Entidad de dominio que representa un plano arquitectónico de un proyecto.
/// HU PB-02 (importar) y PB-11 (calibrar escala) — Sprint 2.
class Plano extends Equatable {
  final int id;
  final int proyectoId;
  final String nombre;
  final FormatoPlano formato;
  final int anchoPx;
  final int altoPx;
  final int tamanoBytes;
  final String urlFirmada;
  final bool calibrado;
  final double? escalaMPorPx;
  final double? distanciaRealM;
  final double? calibracionX1;
  final double? calibracionY1;
  final double? calibracionX2;
  final double? calibracionY2;
  final String? warning;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Plano({
    required this.id,
    required this.proyectoId,
    required this.nombre,
    required this.formato,
    required this.anchoPx,
    required this.altoPx,
    required this.tamanoBytes,
    required this.urlFirmada,
    required this.calibrado,
    this.escalaMPorPx,
    this.distanciaRealM,
    this.calibracionX1,
    this.calibracionY1,
    this.calibracionX2,
    this.calibracionY2,
    this.warning,
    required this.createdAt,
    required this.updatedAt,
  });

  Plano copyWith({
    String? urlFirmada,
    bool? calibrado,
    double? escalaMPorPx,
    double? distanciaRealM,
    double? calibracionX1,
    double? calibracionY1,
    double? calibracionX2,
    double? calibracionY2,
    String? warning,
    DateTime? updatedAt,
  }) {
    return Plano(
      id: id,
      proyectoId: proyectoId,
      nombre: nombre,
      formato: formato,
      anchoPx: anchoPx,
      altoPx: altoPx,
      tamanoBytes: tamanoBytes,
      urlFirmada: urlFirmada ?? this.urlFirmada,
      calibrado: calibrado ?? this.calibrado,
      escalaMPorPx: escalaMPorPx ?? this.escalaMPorPx,
      distanciaRealM: distanciaRealM ?? this.distanciaRealM,
      calibracionX1: calibracionX1 ?? this.calibracionX1,
      calibracionY1: calibracionY1 ?? this.calibracionY1,
      calibracionX2: calibracionX2 ?? this.calibracionX2,
      calibracionY2: calibracionY2 ?? this.calibracionY2,
      warning: warning ?? this.warning,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        proyectoId,
        nombre,
        formato,
        anchoPx,
        altoPx,
        tamanoBytes,
        urlFirmada,
        calibrado,
        escalaMPorPx,
        distanciaRealM,
        calibracionX1,
        calibracionY1,
        calibracionX2,
        calibracionY2,
        warning,
        createdAt,
        updatedAt,
      ];
}
