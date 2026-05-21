import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso: autenticar usuario con email y contraseña.
/// Sp-03 — PB-09
class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  /// Retorna el [Usuario] autenticado o lanza [CredencialesInvalidasException].
  Future<Usuario> call(String email, String password) {
    return _repository.login(email, password);
  }
}
