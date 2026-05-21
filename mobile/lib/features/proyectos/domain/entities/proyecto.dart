import 'package:equatable/equatable.dart';

/// Estados posibles de un proyecto de survey.
/// CA-3: ARCHIVADO oculta el proyecto de la lista principal.
/// HU PB-01 — Sp-09
enum EstadoProyecto {
  nuevo,
  enProgreso,
  completado,
  archivado;

  String toDbValue() {
    switch (this) {
      case EstadoProyecto.nuevo:
        return 'NUEVO';
      case EstadoProyecto.enProgreso:
        return 'EN_PROGRESO';
      case EstadoProyecto.completado:
        return 'COMPLETADO';
      case EstadoProyecto.archivado:
        return 'ARCHIVADO';
    }
  }

  static EstadoProyecto fromDbValue(String valor) {
    switch (valor) {
      case 'EN_PROGRESO':
        return EstadoProyecto.enProgreso;
      case 'COMPLETADO':
        return EstadoProyecto.completado;
      case 'ARCHIVADO':
        return EstadoProyecto.archivado;
      case 'NUEVO':
      default:
        return EstadoProyecto.nuevo;
    }
  }

  String get etiqueta {
    switch (this) {
      case EstadoProyecto.nuevo:
        return 'Nuevo';
      case EstadoProyecto.enProgreso:
        return 'En progreso';
      case EstadoProyecto.completado:
        return 'Completado';
      case EstadoProyecto.archivado:
        return 'Archivado';
    }
  }
}

/// Entidad de dominio que representa un proyecto de survey WiFi.
/// No expone detalles de persistencia.
/// HU PB-01 — Sp-09
class Proyecto extends Equatable {
  final int id;
  final String nombre;
  final int? clienteId;
  final String cliente;
  final String? descripcion;
  final EstadoProyecto estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Proyecto({
    required this.id,
    required this.nombre,
    this.clienteId,
    this.cliente = '',
    this.descripcion,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  Proyecto copyWith({
    String? nombre,
    int? clienteId,
    String? cliente,
    String? descripcion,
    EstadoProyecto? estado,
    DateTime? updatedAt,
  }) {
    return Proyecto(
      id: id,
      nombre: nombre ?? this.nombre,
      clienteId: clienteId ?? this.clienteId,
      cliente: cliente ?? this.cliente,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nombre,
        clienteId,
        cliente,
        descripcion,
        estado,
        createdAt,
        updatedAt
      ];
}
