import '../../domain/entities/proyecto.dart';

/// Modelo de datos para la respuesta JSON de la API REST (recurso proyecto).
/// Modalidad 100 % en línea — HU PB-01
class ProyectoModel {
  final int id;
  final String nombre;
  final int? clienteId;
  final String cliente;
  final String? descripcion;
  final String estado;
  final String createdAt;
  final String updatedAt;

  const ProyectoModel({
    required this.id,
    required this.nombre,
    this.clienteId,
    this.cliente = '',
    this.descripcion,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProyectoModel.fromJson(Map<String, dynamic> json) {
    final clienteMap = json['cliente'] as Map<String, dynamic>?;
    return ProyectoModel(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      clienteId: clienteMap?['id'] as int?,
      cliente: clienteMap?['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      estado: json['estado'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      if (clienteId != null) 'cliente_id': clienteId,
      'descripcion': descripcion,
      'estado': estado,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Proyecto toDomain() {
    return Proyecto(
      id: id,
      nombre: nombre,
      clienteId: clienteId,
      cliente: cliente,
      descripcion: descripcion,
      estado: EstadoProyecto.fromDbValue(estado),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  static ProyectoModel fromDomain(Proyecto proyecto) {
    return ProyectoModel(
      id: proyecto.id,
      nombre: proyecto.nombre,
      clienteId: proyecto.clienteId,
      cliente: proyecto.cliente,
      descripcion: proyecto.descripcion,
      estado: proyecto.estado.toDbValue(),
      createdAt: proyecto.createdAt.toIso8601String(),
      updatedAt: proyecto.updatedAt.toIso8601String(),
    );
  }
}
