import '../entities/usuario.dart';

/// Contrato del repositorio de autenticación.
/// La capa data provee la implementación concreta.
abstract class AuthRepository {
  /// Valida credenciales y devuelve el [Usuario] autenticado.
  /// Lanza [CredencialesInvalidasException] si email o contraseña no coinciden.
  /// Lanza [CuentaDesactivadaException] si la cuenta está desactivada (403).
  Future<Usuario> login(String email, String password);

  /// Elimina la sesión activa del almacenamiento seguro y revoca el refresh token.
  Future<void> logout();

  /// Retorna el [Usuario] si existe sesión persistida, o `null` si no hay sesión.
  Future<Usuario?> getUsuarioActivo();
}

/// Excepción lanzada cuando las credenciales no son válidas.
class CredencialesInvalidasException implements Exception {
  const CredencialesInvalidasException();

  @override
  String toString() => 'Credenciales inválidas';
}

/// Excepción lanzada cuando la cuenta está desactivada por el administrador.
class CuentaDesactivadaException implements Exception {
  const CuentaDesactivadaException();

  @override
  String toString() => 'Cuenta desactivada';
}

/// Excepción lanzada por fallos de acceso a la base de datos o almacenamiento.
class AuthStorageException implements Exception {
  final String mensaje;
  const AuthStorageException(this.mensaje);

  @override
  String toString() => 'Error de almacenamiento: $mensaje';
}
