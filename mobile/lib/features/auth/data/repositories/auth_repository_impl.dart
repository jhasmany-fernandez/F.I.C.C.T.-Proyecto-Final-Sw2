import 'package:dio/dio.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/session_datasource.dart';

/// Implementación concreta del contrato [AuthRepository].
/// Orquesta [AuthRemoteDatasource] (API REST) y [SessionDatasource] (secure storage).
/// Modalidad 100 % en línea — PB-09 / Sprint 1 (Sp1-15, Sp1-17)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final SessionDatasource _sessionDatasource;

  const AuthRepositoryImpl({
    required AuthRemoteDatasource remoteDatasource,
    required SessionDatasource sessionDatasource,
  })  : _remoteDatasource = remoteDatasource,
        _sessionDatasource = sessionDatasource;

  @override
  Future<Usuario> login(String email, String password) async {
    try {
      final response = await _remoteDatasource.login(email, password);
      final usuario = response.usuario.toDomain();
      await _sessionDatasource.guardarSesion(
        response.accessToken,
        response.refreshToken,
        usuario,
      );
      return usuario;
    } on CredencialesInvalidasException {
      rethrow;
    } on CuentaDesactivadaException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      throw AuthStorageException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _sessionDatasource.obtenerRefreshToken();
      if (refreshToken != null) {
        // Revocar en el backend de forma best-effort; no bloquea si falla
        await _remoteDatasource.logout(refreshToken);
      }
    } catch (_) {
      // Error de red durante logout: no bloquear la limpieza local
    } finally {
      await _sessionDatasource.limpiarSesion();
    }
  }

  @override
  Future<Usuario?> getUsuarioActivo() async {
    try {
      // Verificar que el token exista antes de asumir sesión activa.
      // _handleSessionExpired() borra los tokens pero no el usuario_json,
      // así que sin esta comprobación la app entraría en bucle 401 → /login → /proyectos.
      final token = await _sessionDatasource.obtenerToken();
      if (token == null) return null;
      return await _sessionDatasource.obtenerUsuario();
    } catch (_) {
      // Si falla la lectura de sesión, no interrumpir la app; retornar null.
      return null;
    }
  }
}
