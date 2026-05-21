import '../repositories/auth_repository.dart';
import '../entities/usuario.dart';

/// Caso de uso: verificar si existe una sesión activa persistida.
/// Sp-06 — PB-09 (CA-3: apertura de app sin nuevo login)
class GetUsuarioActivoUseCase {
  final AuthRepository _repository;

  const GetUsuarioActivoUseCase(this._repository);

  /// Retorna el [Usuario] si hay sesión activa, o `null` si no.
  Future<Usuario?> call() {
    return _repository.getUsuarioActivo();
  }
}
