import 'package:equatable/equatable.dart';

/// Entidad de dominio para el usuario autenticado.
/// No contiene password_hash — los detalles de seguridad pertenecen a la capa data.
class Usuario extends Equatable {
  final int id;
  final String nombre;
  final String email;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
  });

  @override
  List<Object?> get props => [id, nombre, email];
}
