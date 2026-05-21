import '../repositories/auth_repository.dart';

/// Caso de uso: cerrar sesión activa.
/// Sp-03 — PB-09
class LogoutUseCase {
  final AuthRepository _repository;

  const LogoutUseCase(this._repository);

  Future<void> call() {
    return _repository.logout();
  }
}
