import 'package:equatable/equatable.dart';
import '../../domain/entities/usuario.dart';

/// Estados del flujo de autenticación.
/// Sp-04 — PB-09 / Sprint 1 (Sp1-20)
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial: aún no se verificó si hay sesión activa.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Verificando sesión o procesando login/logout.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Usuario autenticado correctamente.
final class AuthAuthenticated extends AuthState {
  final Usuario usuario;

  const AuthAuthenticated(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

/// Sin sesión activa (después de logout o sin sesión previa).
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Sin conexión al intentar autenticarse.
/// Se muestra el banner de "Sin conexión" con opción de reintentar.
final class AuthSinConexion extends AuthState {
  const AuthSinConexion();
}

/// Error en el proceso de autenticación.
/// El [mensaje] se muestra directamente en la UI (CA-2: no revelar campo específico).
final class AuthError extends AuthState {
  final String mensaje;

  const AuthError(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}
