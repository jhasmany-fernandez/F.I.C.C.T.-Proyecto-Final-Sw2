import '../../domain/entities/usuario.dart';

/// Modelo de datos para la respuesta JSON del backend (recurso usuario).
/// No contiene password_hash: la autenticación es responsabilidad del backend.
/// Modalidad 100 % en línea — PB-09
class UsuarioModel {
  final int id;
  final String nombre;
  final String email;

  const UsuarioModel({
    required this.id,
    required this.nombre,
    required this.email,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
    };
  }

  /// Convierte al modelo de dominio.
  Usuario toDomain() {
    return Usuario(id: id, nombre: nombre, email: email);
  }

  static UsuarioModel fromDomain(Usuario usuario) {
    return UsuarioModel(
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
    );
  }
}
